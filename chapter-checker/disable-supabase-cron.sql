-- Jalankan di Supabase SQL Editor setelah checker Node.js aktif.
select cron.unschedule('check-new-chapters-job');

-- Verifikasi job lama sudah tidak ada:
select jobid, jobname, schedule, active
from cron.job
where jobname = 'check-new-chapters-job';
