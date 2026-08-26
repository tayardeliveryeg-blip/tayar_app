// ====== Edge Function: link-driver ======
// بديل آمن لعملية ربط طيار "مُضاف يدويًا" من لوحة التحكم (زرار
// "+ Add driver" - بيعمل Firestore doc بـ ID عشوائي وisPreInvited:true)
// بحساب الطيار الحقيقي (drivers/{uid}) بعد أول تسجيل دخول له، عن طريق
// مطابقة رقم الموبايل.
//
// السبب في نقل ده من الموبايل للسيرفر (2026-08-20): بعد إلغاء التحقق
// بالـ OTP بالكامل (commit 77e35ce، بسبب متطلبات Blaze)، قاعدة
// isPreInvitedMatch() في firestore.rules بقت مستحيلة التحقق من جهة
// العميل - بتعتمد على request.auth.token.phone_number اللي مبيتحطش
// تاني خالص لأي مستخدم داخل بجوجل/أبل. فكانت عملية الربط (set على
// المستند الجديد + delete على القديم) بترفض دايمًا من الـ rules وتفشل
// صامتة. هنا بنعمل نفس العملية بصلاحيات Service Account (بتتخطى
// firestore.rules تمامًا، زي create-order بالظبط) بعد التحقق من هوية
// الطيار بمقارنة الـ Firebase ID Token - يعني بس الطيار نفسه (uid
// موثّق من التوكن) يقدر يطلب ربط نفسه، مش أي حد لأي حد.
//
// بتتنادى من lib/services/driver_invite_link_helper.dart (نفس منطق
// linkPreInvitedDriverIfNeeded القديم، بس بقى بيبعت للسيرفر بدل ما
// يعمل batch مباشر).

import {
  FirestoreClient,
  verifyFirebaseIdToken,
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

/** نفس منطق normalizeEgyptPhone في driver_invite_link_helper.dart بالظبط -
 * لازم يفضلوا متطابقين حرفيًا وإلا المطابقة هتبوظ. */
function normalizeEgyptPhone(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const digitsOnly = raw.replace(/[^0-9]/g, "");
  if (!digitsOnly) return null;
  return digitsOnly.length > 10 ? digitsOnly.slice(-10) : digitsOnly;
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

    const body = await req.json().catch(() => ({}));
    const phoneNumber = body?.phoneNumber as string | undefined;
    const normalized = normalizeEgyptPhone(phoneNumber);
    if (!normalized || normalized.length < 9) {
      return jsonResponse({ linked: false });
    }

    const db = new FirestoreClient();

    const matches = await db.query(
      "drivers",
      [
        { field: "phoneNormalized", op: "EQUAL", value: normalized },
        { field: "isPreInvited", op: "EQUAL", value: true },
      ],
      { limit: 1 },
    );

    if (matches.length === 0) {
      return jsonResponse({ linked: false });
    }

    const oldDoc = matches[0];

    // ====== نادرًا ما يحصل (لو الأدمن كتب نفس الـ UID غلط)، بس لو حصل
    // منعملش batch؛ نظف الفلاج بس ======
    if (oldDoc.id === user.uid) {
      await db.update(`drivers/${user.uid}`, {
        isPreInvited: false,
        linkedFromPreInvite: true,
      });
      return jsonResponse({ linked: true, driverData: oldDoc.data });
    }

    const mergedData: Record<string, unknown> = { ...oldDoc.data };
    delete mergedData.isPreInvited;
    mergedData.linkedFromPreInvite = true;
    mergedData.linkedAt = new Date();

    await db.batchWrite([
      { type: "merge", path: `drivers/${user.uid}`, data: mergedData },
      { type: "delete", path: `drivers/${oldDoc.id}` },
    ]);

    return jsonResponse({ linked: true, driverData: mergedData });
  } catch (err) {
    console.error("link-driver فشلت:", err);
    // ====== لو حصل أي خطأ غير متوقع منوقفش تسجيل الطيار عشان كده -
    // نفس فلسفة try/catch القديمة في الموبايل: نرجع linked:false
    // بهدوء والتسجيل بيكمل عادي كأنه طيار جديد ======
    return jsonResponse({ linked: false }, 200);
  }
});
