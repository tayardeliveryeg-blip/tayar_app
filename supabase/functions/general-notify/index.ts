// ====== Edge Function: general-notify ======
// بديل كامل لدالتين كانوا في functions/index.js ومحتاجين خطة Blaze:
//   - onWalletCredit: بتتفعل لما الأدمن يشحن محفظة راكب، وبتكتب مستند
//     في collection('notifications')
//   - onNewGeneralNotification: بتتفعل تلقائيًا لما مستند جديد يتكتب في
//     نفس الـ collection دي، وبتبعت الـ Push الحقيقي (FCM)
//
// بما إن أول واحدة كانت المصدر الوحيد فعليًا اللي بيكتب في
// collection('notifications') في الكود الحالي، والتانية كانت مجرد "خطوة
// وسيطة" بتحول الكتابة لـ push، دمجناهم في دالة واحدة بتعمل الاتنين مع
// بعض: تكتب مستند الإشعار (عشان يفضل يظهر في شاشة الإشعارات زي ما هو)
// وتبعت الـ push في نفس الوقت. الدالة دي عامة وقابلة لإعادة الاستخدام -
// أي فيتشر مستقبلي محتاج يبعت "إشعار عام" (طلب اتقبل، الطيار وصل...
// إلخ) ينفعله ينادي عليها بنفس الشكل.
//
// الأمان: الدالة دي بتتنادى من مصدر موثوق بس (لوحة الأدمن دلوقتي)، مش من
// أي مستخدم عادي - عشان محدش يقدر يبعت إشعارات وهمية لمستخدمين تانيين.
// بتتحقق إن التوكن (X-Firebase-Id-Token) بتاع أدمن حقيقي (موجود في
// admin/{uid} في Firestore، بنفس منطق isAdmin() في firestore.rules).

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
    const admin = await verifyFirebaseIdToken(idToken).catch(() => null);
    if (!admin) {
      return jsonResponse({ error: "جلسة الدخول غير صالحة" }, 401);
    }

    const db = new FirestoreClient();

    // ====== التأكد إن اللي بينادي فعلاً أدمن - نفس منطق isAdmin() في
    // firestore.rules (موجود في admin/{uid}) ======
    const adminDoc = await db.get(`admin/${admin.uid}`);
    if (!adminDoc) {
      return jsonResponse({ error: "غير مصرّح - أدمن فقط" }, 403);
    }

    const body = await req.json();
    const { userId, title, body: notifBody, type } = body ?? {};
    if (!userId || !title || !notifBody) {
      return jsonResponse({ error: "userId و title و body مطلوبين" }, 400);
    }

    // ====== 1) كتابة مستند الإشعار - عشان يظهر في شاشة الإشعارات بتاعة
    // المستخدم زي ما كان بيحصل قبل كده ======
    await db.create("notifications", {
      userId,
      title,
      body: notifBody,
      type: type || "system",
      createdAt: new Date(),
      isRead: false,
    });

    // ====== 2) بعت الـ Push الحقيقي فورًا ======
    const token = await getFcmTokenForUser(db, userId);
    let sent = false;
    if (token) {
      sent = await sendFcmPush({
        token,
        title,
        body: notifBody,
        data: { type: type || "system" },
      });
    }

    return jsonResponse({ ok: true, sent });
  } catch (err) {
    console.error("general-notify فشلت:", err);
    return jsonResponse({ error: "حصل خطأ غير متوقع" }, 500);
  }
});
