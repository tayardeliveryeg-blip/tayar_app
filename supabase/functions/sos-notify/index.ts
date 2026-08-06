// ====== Edge Function: sos-notify ======
// بتشتغل تلقائي عن طريق Supabase Database Webhook لما يتضاف صف جديد في
// جدول public.sos_alerts (اللي بيتزرع من SosService._notifySupabase في
// تطبيق Flutter بمجرد ما راكب أو كابتن يدوس زرار الطوارئ).
//
// المسؤولية: تاخد بيانات التنبيه من الـ webhook payload وتبعت Push
// Notification فوري لكل الأدمن المشتركين عن طريق OneSignal - بديل لـ
// Cloud Functions اللي محتاجة خطة Blaze في Firebase.
//
// محتاجة الـ secrets دي متسجلة في إعدادات المشروع (Project Settings ->
// Edge Functions -> Secrets)، مش مكتوبة هنا في الكود:
//   ONESIGNAL_APP_ID
//   ONESIGNAL_REST_API_KEY
//   SOS_WEBHOOK_SECRET  (سر بسيط بنولده احنا، بيتحقق منه عشان محدش
//                        يقدر ينادي الدالة دي مباشرة من برة Supabase)

Deno.serve(async (req: Request) => {
  try {
    // تحقق بسيط إن الطلب جاي من الـ webhook بتاعنا فعلاً، مش من حد
    // لاقي رابط الدالة بالصدفة
    const expectedSecret = Deno.env.get("SOS_WEBHOOK_SECRET");
    const providedSecret = req.headers.get("x-webhook-secret");
    if (expectedSecret && providedSecret !== expectedSecret) {
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = await req.json();
    const record = payload?.record;
    if (!record) {
      return new Response("No record in payload", { status: 400 });
    }

    const roleLabel = record.user_role === "driver" ? "كابتن" : "راكب";
    const name = record.user_name || "مستخدم";
    const phone = record.user_phone ? ` - ${record.user_phone}` : "";
    const message = `${roleLabel}: ${name}${phone}`;

    const appId = Deno.env.get("ONESIGNAL_APP_ID");
    const apiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
    if (!appId || !apiKey) {
      return new Response("OneSignal secrets not configured", {
        status: 500,
      });
    }

    const oneSignalResponse = await fetch(
      "https://onesignal.com/api/v1/notifications",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${apiKey}`,
        },
        body: JSON.stringify({
          app_id: appId,
          included_segments: ["Subscribed Users"],
          headings: { en: "🚨 تنبيه طوارئ SOS", ar: "🚨 تنبيه طوارئ SOS" },
          contents: { en: message, ar: message },
          data: {
            type: "sos_alert",
            firestoreAlertId: record.firestore_alert_id,
          },
        }),
      },
    );

    const oneSignalResult = await oneSignalResponse.json();
    return new Response(JSON.stringify({ ok: true, oneSignalResult }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ ok: false, error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
