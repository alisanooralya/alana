-- Ketat policies: profiles hanya bisa dibaca pemiliknya sendiri.
--
-- Sebelumnya policy select memakai `using (true)`, jadi setiap user yang
-- sudah login bisa melakukan dump seluruh tabel profiles lewat PostgREST:
-- username, display_name, avatar_url, dan UUID seluruh akun. Satu-satunya
-- kebutuhan select di klien adalah pengecekan ketersediaan username, dan itu
-- diganti dengan fungsi boolean di bawah supaya tidak ada data yang bocor.
--
-- CATATAN KEAMANAN: fungsi username_taken memang oracle yang bisa
-- mengecek keberadaan username. Itu memang konsekuensi dari fitur "cek
-- ketersediaan username" dan jauh lebih baik daripada membocorkan seluruh
-- tabel. Bila ini dianggap perlu, batasi lewat edge function.
--
-- File ini SENGAJA tidak menyentuh storage.objects. Jalankan
-- supabase/sql/storage_avatar_limits.sql sebagai langkah TERPISAH.
-- Catatan deadlock ada di bawah.

-- Deadlock 40P01 yang pernah terjadi:
--   Process A waits for AccessExclusiveLock on storage.objects
--   Process B waits for AccessShareLock on profiles
-- Penyebabnya transaksi ini terlalu panjang: sambil memegang lock profiles
-- (AccessExclusiveLock dari CREATE/DROP POLICY) ia meminta lock eksklusif di
-- storage.objects, sementara request PostgREST atau Storage API memegang
-- AccessShareLock di storage.objects lalu mau membaca profiles. Karena dua
-- tabel itu di-lock dengan urutan berbeda, keduanya saling tunggu.
--
-- Perbaikannya: jangan pernah memegang lock profiles dan storage.objects
-- dalam satu transaksi. Bagian storage sudah dipisah ke file sendiri, dan
-- file itu memakai lock_timeout supaya gagal cepat (55P03) alih-alih
-- deadlock, lalu tinggal diulang.
--
-- lock_timeout di sini hanya berlaku untuk sesi SQL Editor ini, tidak
-- disimpan sebagai default database.

begin;

-- Fail fast (3 detik) alih-alih menunggu/deadlock. 55P03 = lock_not_available
-- dan aman diulang karena semua pernyataan di file ini idempotent.
set local lock_timeout = '3s';

-- Policy lama dibuang dan diganti. Tabel profiles tidak punya traffic
-- Storage API, jadi lock di sini relatif singkat.
--
-- Dua nama ikut di-drop supaya file ini idempotent. CREATE POLICY tidak
-- idempotent: kalau policy dengan nama sama sudah ada, statement itu gagal
-- dengan "policy ... already exists". Nama pertama adalah policy lama,
-- nama kedua adalah hasil dari file ini bila dijalankan ulang.
drop policy if exists "profil bisa dibaca user login" on public.profiles;
drop policy if exists "profil bisa dibaca pemilik sendiri" on public.profiles;

create policy "profil bisa dibaca pemilik sendiri" on public.profiles
  for select to authenticated using (auth.uid() = id);

-- Pengecekan ketersediaan username tanpa membuka tabel profiles.
-- Hanya mengembalikan true/false; tidak pernah mengembalikan baris.
create or replace function public.username_taken(
  p_username text,
  p_kecuali uuid default null
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where username = lower(btrim(p_username))
      and (p_kecuali is null or id <> p_kecuali)
  );
$$;

-- Diboleh untuk anon karena pengecekan username juga dipakai di layar
-- pendaftaran, sebelum user punya sesi.
revoke all on function public.username_taken(text, uuid) from public;
grant execute on function public.username_taken(text, uuid) to anon, authenticated;

commit;
