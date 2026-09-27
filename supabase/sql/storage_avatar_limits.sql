-- Batasi upload avatar: hanya gambar, maksimal 5 MB, ke folder sendiri.
--
-- Tanpa ini klien (bukan aplikasi) bisa mengisi folder user dengan berkas
-- sebesar 50 MB sehingga avatar gagal dimuat.
--
-- JALANKAN FILE INI SENDIRI, setelah profiles_rls_tighten.sql sudah selesai.
-- Jangan gabungkan dengan file lain dalam satu transaksi: storage.objects
-- selalu ada traffic dari Storage API, jadi AccessExclusiveLock di sini
-- rawan 40P01 deadlock bila ditahan bersama lock tabel lain.
--
-- Kalau muncul error 55P03 (lock_not_available), itu lock_timeout di bawah
-- yang bekerja: bukan deadlock, dan tidak ada perubahan yang ter-apply.
-- Tinggal jalankan ulang file ini beberapa detik kemudian.
--
-- lock_timeout hanya berlaku untuk sesi SQL Editor ini dan tidak disimpan
-- sebagai default database.

begin;

set local lock_timeout = '3s';

-- Parser integer yang aman.
--
-- Ada masalah di versi lama:
--   coalesce(((storage.metadata(name))->>'size')::bigint, 0) < 5242880
-- coalesce TIDAK melindungi dari error cast. Cast dievaluasi lebih dulu,
-- jadi begitu nilai size bukan angka, statement mati dengan
-- "invalid input syntax for type bigint" -- bukan sekadar menolak upload.
-- Dengan case ini, cast hanya dijalankan kalau teksnya benar-benar digit.
create or replace function public.angka_aman(p_teks text)
returns bigint
language sql
immutable
strict
set search_path = ''
as $$
  select case
    when p_teks ~ '^[0-9]{1,18}$' then p_teks::bigint
    else null
  end;
$$;

revoke all on function public.angka_aman(text) from public;
grant execute on function public.angka_aman(text) to anon, authenticated;

drop policy if exists "upload avatar ke folder sendiri" on storage.objects;

create policy "upload avatar ke folder sendiri" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.metadata(name))->>'mimetype' like 'image/%'
    and public.angka_aman((storage.metadata(name))->>'size') < 5242880
  );

-- Batasi juga saat update/overwrite file yang sama.
drop policy if exists "update avatar sendiri" on storage.objects;

create policy "update avatar sendiri" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.metadata(name))->>'mimetype' like 'image/%'
    and public.angka_aman((storage.metadata(name))->>'size') < 5242880
  );

commit;
