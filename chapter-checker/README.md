# Chapter Checker

Service Node.js terpisah untuk mengecek chapter baru dari `api.shngm.io`, menyimpan cache ke Supabase, membuat notifikasi, dan mengirim push FCM. Service ini menggantikan pemanggilan Supabase Edge Function `check-new-chapters` karena IP Edge Function diblokir Cloudflare.

## Kebutuhan

- Node.js 20 atau lebih baru.
- Project Supabase yang sama dengan aplikasi Alana.
- Service account Firebase dengan izin Firebase Cloud Messaging.
- Server VPS yang project's Node.js/JavaScript runtime bisa jalankan.

## Instalasi

```bash
cd chapter-checker
npm install
cp .env.example .env
```

Isi `.env`:

- `SUPABASE_URL`: URL project Supabase.
- `SUPABASE_SECRET_KEY`: secret/service key Supabase. Jangan memakai anon/publishable key.
- `FIREBASE_SERVICE_ACCOUNT`: path relatif ke file JSON service account, atau isi JSON service account dalam satu baris.
- `CRON_SCHEDULE`: jadwal cron, default `0 */4 * * *`.
- `CRON_TIMEZONE`: timezone jadwal, default `UTC`.
- `API_DELAY_MS`: jeda antar request manga, default `1500`.
- `MAX_MANGA_PER_RUN`: batas manga per sekali jalan, default `100`.

Simpan file service account di luar repository, misalnya `./service-account.json`. File `.env` dan `service-account*.json` sudah masuk `.gitignore`.

## Menjalankan manual

Jalankan sekali tanpa menunggu jadwal cron:

```bash
npm run check:once
```

Atau:

```bash
node index.js --once
```

## pm2

```bash
npm install -g pm2
pm2 start ecosystem.config.js
pm2 startup
pm2 save
```

Jalankan perintah yang ditampilkan oleh `pm2 startup` agar service aktif kembali setelah reboot.

Log:

```bash
pm2 logs chapter-checker
```

Restart:

```bash
pm2 restart chapter-checker
```

Status:

```bash
pm2 status
```

Stop:

```bash
pm2 stop chapter-checker
```

## Menonaktifkan cron Supabase lama

Jalankan `disable-supabase-cron.sql` di Supabase SQL Editor, atau gunakan perintah berikut:

```sql
select cron.unschedule('check-new-chapters-job');
```

Verifikasi:

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'check-new-chapters-job';
```

Edge Function `check-new-chapters` boleh dibiarkan ter-deploy tetapi tidak lagi dipanggil. Setelah service Node.js stabil dan terbukti mengirim notifikasi, Edge Function boleh dihapus dari repository dan workflow deploy.

## Format payload FCM

Data push yang dikirim ke aplikasi:

```json
{
  "type": "chapter_update",
  "link": "alana://manga/<manga_id>/chapter/<chapter_id>",
  "manga_id": "<manga_id>",
  "chapter_id": "<chapter_id>"
}
```

## Catatan rate limit

`API_DELAY_MS` memberikan jeda antar request manga agar traffic terlihat normal dan tidak memicu pemblokiran Cloudflare. Jangan menurunkan nilainya tanpa alasan.
