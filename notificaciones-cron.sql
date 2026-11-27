-- ============================================================
-- Intercambio Navideño · Recordatorios automáticos (una vez al día)
-- Córrelo en Supabase → SQL Editor DESPUÉS de crear la función "push".
-- Manda los avisos por fecha (14, 10, 7, 3, 1 y 0 días antes) y
-- desbloquea las pistas del Santa. Se ejecuta diario a las 10:00 am
-- (hora del centro de México = 16:00 UTC).
-- ============================================================
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Si ya existía, lo quitamos para no duplicarlo
select cron.unschedule(jobid) from cron.job where jobname = 'intercambio-recordatorios';

select cron.schedule(
  'intercambio-recordatorios',
  '0 16 * * *',
  $$
  select net.http_post(
    url := 'https://wmazcnmvyuvhggbxcpgc.supabase.co/functions/v1/push',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{"tipo": "cron", "secreto": "LvBBRK7PkCcLwWXUxpfh0CXoM2DYCeqp"}'::jsonb
  );
  $$
);

-- Para revisar que quedó programado:
-- select jobname, schedule, active from cron.job;
-- Para ver si corrió bien (después del primer día):
-- select status, return_message, start_time from cron.job_run_details order by start_time desc limit 5;
