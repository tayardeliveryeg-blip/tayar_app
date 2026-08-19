// ====== Edge Function: scheduled-ride-reminder ======
// الخطوة 5/5 من فيتشر "الرحلات المجدولة": بتبعت تذكير Push للراكب قبل
// ميعاد رحلته المحجوزة مقدمًا بـ 15 دقيقة تقريبًا.
//
// مختلفة عن باقي الدوال (create-order، chat-notify، general-notify) في
// حاجة مهمة: مش بتتنادى من التطبيق (Flutter) ولا من لوحة الأدمن - بل
// المفروض تتنادى بشكل دوري (كل 5 دقايق مثلًا) عن طريق pg_cron جوه
// Supabase نفسه، عشان تدور بانتظام على أي رحلة مجدولة قرب ميعادها.
// راجع ملف supabase/sql/scheduled_ride_reminder_cron.sql وقسم "4) تذكير
// الرحلة المجدولة" في SETUP_TODO.md لخطوات تفعيل الجدولة دي.
//
// المنطق:
//   1) تجيب كل الطلبات (orders) اللي orderType == 'scheduled' و
//      scheduledFor واقعة في الشباك الزمني [الآن, الآن + REMINDER_WINDOW_MIN]
//      (شباك 20 دقيقة، بافر أوسع من الـ 15 دقيقة الفعلية عشان نغطي أي
//      تأخير بسيط في تشغيل الـ cron).
//   2) بتستبعد اللي status بتاعها مش searching/accepted (يعني اتلغت أو
//      خلصت بالفعل)، وبتستبعد اللي reminderSent == true بالفعل (عشان
//      محدش ياخد نفس التذكير مرتين).
//   3) من الباقي، بتبعت push للراكب بس (customerId) للي فاضلهم <= 15
//      دقيقة فعليًا على ميعادهم، وتسجل reminderSent: true على الطلب.
//
// الأمان: المفروض الدالة دي متتنادش غير من الـ cron job بتاعنا، فبنتحقق
// من سر بسيط (زي أسلوب SOS_WEBHOOK_SECRET في sos-notify) بدل التحقق من
// Firebase ID Token (مفيش مستخدم حقيقي بينادي الدالة دي).
//   CRON_SECRET  (سر بنولده احنا، بيتسجل في Supabase secrets وفي إعداد
//                 pg_cron/pg_net في نفس الوقت)

import {
  FirestoreClient,
  getFcmTokenForUser,
  sendFcmPush,
} from "../_shared/firebase-admin.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

// ====== الشباك اللي بندور فيه في الاستعلام (بافر أوسع من التذكير
// الفعلي عشان نغطي فرق توقيت تشغيل الـ cron) ======
const QUERY_WINDOW_MIN = 20;
// ====== قبل الميعاد بكام دقيقة فعليًا نبعت التذكير ======
const REMINDER_LEAD_MIN = 15;

function formatArabicTime(date: Date): string {
  return date.toLocaleTimeString("ar-EG", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Africa/Cairo",
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const expectedSecret = Deno.env.get("CRON_SECRET");
    const providedSecret = req.headers.get("x-cron-secret");
    if (expectedSecret && providedSecret !== expectedSecret) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const db = new FirestoreClient();
    const now = new Date();
    const windowEnd = new Date(now.getTime() + QUERY_WINDOW_MIN * 60_000);

    // ====== equality (orderType) + range (scheduledFor مرتين) - أبسط
    // تركيبة ممكن تحتاج composite index واحد بس، بدل ما نضيف status
    // كـ 'in' filter كمان جوه نفس الاستعلام ======
    const candidates = await db.query("orders", [
      { field: "orderType", op: "EQUAL", value: "scheduled" },
      { field: "scheduledFor", op: "GREATER_THAN_OR_EQUAL", value: now },
      { field: "scheduledFor", op: "LESS_THAN_OR_EQUAL", value: windowEnd },
    ]);

    let remindersSent = 0;
    let skipped = 0;

    for (const order of candidates) {
      const data = order.data;
      const status = data.status as string | undefined;
      const alreadyReminded = data.reminderSent === true;
      // ====== fromFirestoreValue بترجع timestampValue كـ Date عادي
      // جاهز - مفيش .toDate() هنا زي عميل Flutter (cloud_firestore) ======
      const scheduledForRaw = data.scheduledFor as Date | string | undefined;

      if (
        alreadyReminded ||
        (status !== "searching" && status !== "accepted") ||
        !scheduledForRaw
      ) {
        skipped++;
        continue;
      }

      const scheduledFor = scheduledForRaw instanceof Date
        ? scheduledForRaw
        : new Date(scheduledForRaw);

      const minutesUntil = (scheduledFor.getTime() - now.getTime()) / 60_000;
      // ====== لسه بدري عليها (أكتر من 15 دقيقة) - هنحاول تاني في
      // الدورة الجاية للـ cron ======
      if (minutesUntil > REMINDER_LEAD_MIN) {
        skipped++;
        continue;
      }
      // ====== فاتها ميعادها من غير ما نبعت (مثلًا الدالة كانت واقفة) -
      // مش هنبعت تذكير متأخر، بس نعلّمها عشان منحاولش تاني كل مرة ======
      if (minutesUntil < -5) {
        await db.update(`orders/${order.id}`, { reminderSent: true }).catch(
          () => {},
        );
        skipped++;
        continue;
      }

      const customerId = data.customerId as string | undefined;
      if (!customerId) {
        skipped++;
        continue;
      }

      const token = await getFcmTokenForUser(db, customerId);
      if (token) {
        const timeLabel = formatArabicTime(scheduledFor);
        const destination = (data.destinationAddress as string) || "";
        const sent = await sendFcmPush({
          token,
          title: "رحلتك المجدولة قربت 🕐",
          body: destination
            ? `رحلتك لـ ${destination} هتبدأ الساعة ${timeLabel}`
            : `رحلتك المجدولة هتبدأ الساعة ${timeLabel}`,
          data: { type: "scheduled_ride_reminder", orderId: order.id },
        });
        if (sent) remindersSent++;
      }

      // ====== نسجل reminderSent سواء لقينا توكن أو لأ، عشان منحاولش
      // نبعت تاني لنفس الطلب في الدورة الجاية ======
      await db.update(`orders/${order.id}`, { reminderSent: true }).catch(
        () => {},
      );
    }

    return jsonResponse({
      ok: true,
      checked: candidates.length,
      remindersSent,
      skipped,
    });
  } catch (err) {
    console.error("scheduled-ride-reminder فشلت:", err);
    return jsonResponse({ error: "حصل خطأ غير متوقع" }, 500);
  }
});
