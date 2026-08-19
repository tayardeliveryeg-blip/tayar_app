-- ====== جدولة تنفيذ scheduled-ride-reminder كل 5 دقايق ======
-- شغّل السكريبت ده مرة واحدة من Supabase Dashboard -> SQL Editor.
-- محتاج الإكستنشنز pg_cron و pg_net (متوفرين افتراضيًا في كل مشاريع
-- Supabase، بس لازم تفعيلهم من تبويب Database -> Extensions أول مرة).

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- ====== غيّر القيمتين دول قبل التشغيل: ======
--   1) project-ref بتاعك (موجود في رابط لوحة التحكم:
--      https://supabase.com/dashboard/project/<project-ref>)
--   2) نفس قيمة CRON_SECRET اللي هتسجلها في Edge Functions -> Secrets
--      (ولّد سلسلة عشوائية طويلة، وسجّلها في المكانين بنفس القيمة بالظبط)

select cron.schedule(
  'scheduled-ride-reminder-every-5-min',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/scheduled-ride-reminder',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', '<same-value-as-CRON_SECRET-secret>'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- ====== للتأكد إن الجدولة اتسجلت صح: ======
-- select * from cron.job;

-- ====== لو احتجت تشيلها لاحقًا: ======
-- select cron.unschedule('scheduled-ride-reminder-every-5-min');
