// ====== Edge Function: complete-trip ======
// بتحسب وتسوّي عمولة الطيار السيرفر لحظة إنهاء الرحلة، بدل ما الحساب ده
// يتنفّذ من جهاز الطيار نفسه (زي ما كان بيحصل قبل كده في
// completeTripAndDeductCommission بتاعة wallet_service.dart في الفلاتر).
//
// ليه الانتقال ده؟ firestore.rules كانت مضطرة تسيب حقل
// drivers/{driverId}.walletBalance مفتوح قدام الطيار نفسه، عشان الجهاز
// كان محتاج يكتبه مباشرة بعد كل رحلة. المشكلة إن ده كان بيسمح لأي طيار
// (بمعرفة تقنية بسيطة - REST call مباشر مش من خلال التطبيق) يغيّر رصيد
// محفظته لأي رقم يحبه من غير ما يمر على أي رحلة أو عمولة أصلًا.
//
// دلوقتي: الطيار بينادي الدالة دي بس (مش بيكتب walletBalance مباشرة)،
// والدالة بتتأكد هي من كل حاجة على السيرفر (الطيار فعلًا صاحب الرحلة دي،
// الرحلة فعلًا شغالة، نسبة العمولة من settings/config الحقيقية - مش رقم
// مبعوت من الجهاز) قبل ما تحسب وتكتب الرصيد الجديد. firestore.rules
// بقت تمنع الطيار يعدّل walletBalance بنفسه خالص - الحقل ده بقى مقصور
// على الأدمن وعلى الـ service account بتاع الدالة دي بس.
//
// نفس منطق completeTripAndDeductCommission الأصلي بالظبط (نفس معادلة
// العمولة، نفس شكل سجل الحركة) - الفرق الوحيد إنه بقى شغال جوه Firestore
// transaction حقيقية على السيرفر (راجع withRetriedTransaction في
// _shared/firebase-admin.ts) بدل transaction الفلاتر المحلية.

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

/// ====== نفس القيمة الثابتة بالظبط المستخدمة في kWalletPaymentMethodValue
/// (wallet_service.dart) - لازم تفضل مطابقة لها حرفيًا ======
const WALLET_PAYMENT_METHOD_VALUE = "محفظة إلكترونية";

const DEFAULT_COMMISSION_RATE = 0.10;

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
    const driver = await verifyFirebaseIdToken(idToken).catch(() => null);
    if (!driver) {
      return jsonResponse({ error: "جلسة الدخول غير صالحة" }, 401);
    }

    const body = await req.json().catch(() => null);
    const orderId = body?.orderId as string | undefined;
    if (!orderId) {
      return jsonResponse({ error: "orderId مطلوب" }, 400);
    }

    const db = new FirestoreClient();

    const result = await withRetriedTransaction(db, async (transaction) => {
      const [order, driverDoc, settings] = await db.getManyInTransaction(
        [`orders/${orderId}`, `drivers/${driver.uid}`, `settings/config`],
        transaction,
      );

      if (!order) {
        throw new HttpError(404, "الرحلة دي مش موجودة");
      }
      // ====== لازم يكون نفس الطيار المعيّن على الرحلة - محدش يقدر ينهي
      // رحلة طيار تاني وياخد عمولتها ======
      if (order.driverId !== driver.uid) {
        throw new HttpError(403, "الرحلة دي مش بتاعتك");
      }
      // ====== idempotent: لو الرحلة اتقفلت بالفعل (زي لو الطيار ضغط
      // "إنهاء" مرتين، أو الطلب الأول نجح على السيرفر بس الرد اتأخر
      // ووصل للجهاز متأخر) منعملش أي حاجة تانية - مفيش تسوية تانية
      // هتتضاف، بس نرجّع نجاح عادي ======
      if (order.status === "completed") {
        return { alreadyCompleted: true };
      }
      if (order.status !== "in_progress") {
        throw new HttpError(
          409,
          "الرحلة دي مش في حالة تسمح بإنهائها دلوقتي",
        );
      }

      const fare = Number(order.acceptedFare ?? 0);
      const isWalletPayment = order.paymentMethod ===
        WALLET_PAYMENT_METHOD_VALUE;

      const currentBalance = Number(driverDoc?.walletBalance ?? 0);
      const commissionPercent = settings?.commissionPercent as
        | number
        | undefined;
      const commissionRate = typeof commissionPercent === "number"
        ? commissionPercent / 100
        : DEFAULT_COMMISSION_RATE;

      const commission = fare * commissionRate;
      const walletDelta = isWalletPayment ? (fare - commission) : -commission;
      const newBalance = currentBalance + walletDelta;

      const ledgerId = randomFirestoreId();

      await db.commitTransaction(transaction, [
        {
          type: "update",
          path: `orders/${orderId}`,
          data: { status: "completed", completedAt: new Date() },
        },
        {
          type: "update",
          path: `drivers/${driver.uid}`,
          data: { walletBalance: newBalance },
        },
        {
          type: "create",
          collectionPath: `drivers/${driver.uid}/walletTransactions`,
          documentId: ledgerId,
          data: {
            type: isWalletPayment ? "trip_earning" : "commission",
            status: "completed",
            amount: walletDelta,
            orderId,
            fare,
            balanceAfter: newBalance,
            createdAt: new Date(),
          },
        },
      ]);

      return { alreadyCompleted: false, newBalance };
    });

    return jsonResponse({ ok: true, ...result });
  } catch (err) {
    if (err instanceof HttpError) {
      return jsonResponse({ error: err.message }, err.status);
    }
    console.error("complete-trip فشلت:", err);
    return jsonResponse({ error: "حصل خطأ غير متوقع، حاول تاني" }, 500);
  }
});

/// ====== استثناء بسيط بيحمل status code مناسب - عشان نقدر نميّز أخطاء
/// "متوقعة" (403/404/409 برسالة عربية واضحة للطيار) عن أخطاء غير متوقعة
/// (500 عامة، من غير تفاصيل داخلية) ======
class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}
