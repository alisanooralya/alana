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

begin;

drop policy if exists "profil bisa dibaca user login" on public.profiles;

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

-- Batasi upload avatar: hanya gambar, maksimal 5 MB, ke folder sendiri.
-- Tanpa ini klien (bukan aplikasi) bisa mengisi folder user dengan berkas
-- sebesar 50 MB sehingga avatar gagal dimuat.
drop policy if exists "upload avatar ke folder sendiri" on storage.objects;

create policy "upload avatar ke folder sendiri" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.metadata(name))->>'mimetype' like 'image/%'
    and coalesce(((storage.metadata(name))->>'size')::bigint, 0) < 5242880
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
    and coalesce(((storage.metadata(name))->>'size')::bigint, 0) < 5242880
  );

commit;
