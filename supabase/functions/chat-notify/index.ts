// ====== Edge Function: chat-notify ======
// بديل كامل لـ Cloud Function اسمها onNewChatMessage (كانت في
// functions/index.js) اللي محتاجة خطة Blaze عشان تتنشر. كانت Firestore
// Trigger بتتفعل تلقائيًا لما رسالة جديدة تتكتب في
// orders/{orderId}/messages/{messageId}.
//
// Supabase مفيهاش Firestore triggers، فبدل كده الموبايل (trip_chat_screen.dart)
// بينادي الدالة دي مباشرة بعد ما يكتب الرسالة في Firestore - نفس أسلوب
// sos-notify و create-order بالظبط (نداء مباشر بدل الاعتماد على webhook).
//
// الأمان: زي create-order - Authorization محجوز لـ Supabase anon key،
// والتوكن الحقيقي بتاع Firebase في هيدر X-Firebase-Id-Token. الدالة
// بتتحقق إن اللي بعت الرسالة هو فعلاً صاحب senderId المُمرر (مش أي حد
// تاني يقدر يبعت إشعار باسم غيره)، وبعدين بتقرا الأوردر ورسالة الشات
// نفسها من Firestore بصلاحية Service Account عشان تحدد المستلم الصحيح.

import {
  FirestoreClient,
  getFcmTokenForUser,
  sendFcmPush,
  verifyFirebaseIdToken,
} from "../_shared/firebase-admin.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-firebase-id-token, apikey",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
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

    const body = await req.json();
    const { orderId, messageId } = body ?? {};
    if (!orderId || !messageId) {
      return jsonResponse({ error: "orderId و messageId مطلوبين" }, 400);
    }

    const db = new FirestoreClient();

    // ====== نقرا الرسالة نفسها من Firestore (مش من الـ body) عشان
    // نتأكد إن اللي بعت الطلب هو فعلاً صاحب الرسالة ======
    const message = await db.get(`orders/${orderId}/messages/${messageId}`);
    if (!message) {
      return jsonResponse({ error: "الرسالة مش موجودة" }, 404);
    }
    const senderId = message.senderId as string | undefined;
    if (!senderId || senderId !== user.uid) {
      return jsonResponse({ error: "مش مسموح تبعت إشعار عن رسالة مش بتاعتك" }, 403);
    }
    const senderName = (message.senderName as string) || "";
    const text = (message.text as string) || "";

    const order = await db.get(`orders/${orderId}`);
    if (!order) {
      return jsonResponse({ ok: true, skipped: "order_not_found" });
    }
    const customerId = order.customerId as string | undefined;
    const driverId = order.driverId as string | undefined;

    let recipientId: string | null = null;
    if (senderId === customerId) recipientId = driverId ?? null;
    else if (senderId === driverId) recipientId = customerId ?? null;

    if (!recipientId) {
      return jsonResponse({ ok: true, skipped: "no_recipient" });
    }

    const token = await getFcmTokenForUser(db, recipientId);
    if (!token) {
      return jsonResponse({ ok: true, skipped: "no_fcm_token" });
    }

    const sent = await sendFcmPush({
      token,
      title: senderName || "رسالة جديدة",
      body: text,
      data: {
        type: "chat",
        orderId: String(orderId),
        senderName: String(senderName),
      },
      androidChannelId: "tayar_chat_channel",
    });

    return jsonResponse({ ok: true, sent });
  } catch (err) {
    console.error("chat-notify فشلت:", err);
    return jsonResponse({ error: "حصل خطأ غير متوقع" }, 500);
  }
});
