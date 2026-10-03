// ====== Edge Function: settle-cancellation-fee ======
// بتخصم رسوم إلغاء رحلة من محفظة الراكب سيرفر-سايد. قبل كده الجهاز نفسه
// كان بيكتب walletBalance (settleCancellationFee في wallet_service.dart)،
// فأي كلاينت معدّل كان يقدر يلغي ويتخطى الرسوم. دلوقتي الراكب بينادي
// الدالة دي بس، والسيرفر هو اللي بيتأكد من كل حاجة:
//   - الراكب فعلًا صاحب الطلب (من الـ ID token الموثوق، مش من الجهاز)
//   - الطلب اتلغى من الراكب نفسه، مدفوع بالمحفظة، ورسومه موجبة
//   - الرسوم ماتخصمتش قبل كده (idempotent)
// الرصيد مسموح يبقى بالسالب (نفس سلوك الكلاينت القديم).
import {
  FirestoreClient,
  randomFirestoreId,
  verifyFirebaseIdToken,
  withRetriedTransaction,
} from "../_shared/firebase-admin.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, x-firebase-id-token, apikey",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

const WALLET_PAYMENT_METHOD_VALUE = "محفظة إلكترونية";

class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const idToken = req.headers.get("X-Firebase-Id-Token") ?? "";
    if (!idToken) {
      return jsonResponse({ error: "لازم تسجل الدخول الأول" }, 401);
    }
    const user = await verifyFirebaseIdToken(idToken).catch(() => null);
    if (!user) {
      return jsonResponse({ error: "جلسة الدخول غير صالحة" }, 401);
    }

    const body = await req.json().catch(() => null);
    const orderId = body?.orderId as string | undefined;
    if (!orderId) {
      return jsonResponse({ error: "orderId مطلوب" }, 400);
    }

    const db = new FirestoreClient();

    const result = await withRetriedTransaction(db, async (transaction) => {
      const [order, userDoc] = await db.getManyInTransaction(
        [`orders/${orderId}`, `users/${user.uid}`],
        transaction,
      );

      if (!order) throw new HttpError(404, "الطلب ده مش موجود");
      if (order.customerId !== user.uid) {
        throw new HttpError(403, "الطلب ده مش بتاعك");
      }

      const fee = Number(order.cancellationFee ?? 0);
      if (
        order.paymentMethod !== WALLET_PAYMENT_METHOD_VALUE ||
        order.status !== "cancelled" ||
        order.cancelledBy !== "customer" ||
        !(fee > 0)
      ) {
        // ====== مفيش رسوم تتخصم من المحفظة للطلب ده - مش خطأ ======
        return { settled: false };
      }
      if (order.cancellationFeeDeducted === true) {
        return { settled: false, alreadySettled: true };
      }

      const currentBalance = Number(userDoc?.walletBalance ?? 0);
      const newBalance = currentBalance - fee;

      await db.commitTransaction(transaction, [
        {
          type: "update",
          path: `orders/${orderId}`,
          data: { cancellationFeeDeducted: true },
        },
        {
          type: "update",
          path: `users/${user.uid}`,
          data: {
            walletBalance: newBalance,
            walletLastCancellationFeeOrderId: orderId,
          },
        },
        {
          type: "create",
          collectionPath: `users/${user.uid}/walletTransactions`,
          documentId: randomFirestoreId(),
          data: {
            type: "cancellation_fee",
            amount: -fee,
            orderId,
            balanceAfter: newBalance,
            createdAt: new Date(),
          },
        },
      ]);

      return { settled: true, newBalance };
    });

    return jsonResponse({ ok: true, ...result });
  } catch (err) {
    if (err instanceof HttpError) {
      return jsonResponse({ error: err.message }, err.status);
    }
    console.error("settle-cancellation-fee فشلت:", err);
    return jsonResponse({ error: "حصل خطأ غير متوقع، حاول تاني" }, 500);
  }
});
