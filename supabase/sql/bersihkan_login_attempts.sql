-- Pembersihan otomatis tabel login_attempts.
-- Jalankan manual di Dashboard Supabase → SQL Editor → New query.
--
-- Tabel ini menyimpan alamat IP dan email/username yang dicoba login. Tanpa
-- pembersihan, tabel tumbuh tanpa batas padahal tidak ada yang membacanya
-- setelah jendela rate limit (15 menit) lewat. Kebijakan privasi
-- menjanjikan catatan ini dihapus setelah 30 hari, jadi cron ini yang
-- menjadikannya benar.
--
-- Aman dijalankan berulang: delete bersifat idempotent dan jadwal memakai
-- unschedule lebih dulu supaya tidak membuat job dobel.

begin;

create extension if not exists pg_cron;

-- Hapus job lama kalau ada, supaya file ini bisa dijalankan ulang.
do $$
declare
  id_job bigint;
begin
  select jobid into id_job from cron.job where jobname = 'bersihkan-login-attempts';
  if id_job is not null then
    perform cron.unschedule(id_job);
  end if;
end;
$$;

-- Pakai delete, bukan truncate: truncate mengunci tabel dan butuh hak yang
-- lebih tinggi. Sengaja tidak ditambah index baru untuk created_at, karena
-- setiap login gagal melakukan insert ke tabel ini dan akan terasa di sisi
-- tulis. Setelah cron ini aktif volumenya kecil, scan penuh tidak terasa.
create or replace function public.bersihkan_login_attempts()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  jumlah bigint;
begin
  delete from public.login_attempts
   where created_at < now() - interval '30 days';
  get diagnostics jumlah = row_count;
  return jumlah;
end;
$$;

revoke all on function public.bersihkan_login_attempts()
  from public;

-- Netral terhadap client: tidak dipanggil lewat Data API, hanya lewat cron.
grant execute on function public.bersihkan_login_attempts()
  to postgres, service_role;

select cron.schedule(
  'bersihkan-login-attempts',
  '17 4 * * *',
  $$ select public.bersihkan_login_attempts(); $$
);

commit;