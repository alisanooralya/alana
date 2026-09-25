select cron.schedule(
  'check-new-chapters-job',
  '0 */1 * * *',  -- tiap 1 jam, sesuaikan
  $$
  -- Authorization memakai SECRET key baru (sb_secret_...), BUKAN anon.
  -- (Project lama: service_role JWT lama tetap bisa.)
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/check-new-chapters',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <SERVICE_ROLE_KEY>',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);