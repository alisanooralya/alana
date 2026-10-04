create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text,
  avatar_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profil bisa dibaca user login" on public.profiles;

create policy "profil bisa dibaca user login" on public.profiles
  for select to authenticated using (true);
drop policy if exists "update profil sendiri" on public.profiles;

create policy "update profil sendiri" on public.profiles
  for update to authenticated using (auth.uid() = id);
drop policy if exists "insert profil sendiri" on public.profiles;

create policy "insert profil sendiri" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

-- Trigger pembuatan profil.
--
-- raw_user_meta_data dikontrol penuh oleh klien: signUp bisa mengirim
-- options.data.username apa saja. Sebelumnya nilai itu dipakai apa adanya,
-- sehingga username di luar pola check constraint
-- (^[a-z0-9_]{3,20}$) membuat trigger melempar. Karena trigger ini
-- `after insert on auth.users`, seluruh transaksi signup ikut rollback:
-- akun tidak pernah dibuat dan pesannya sampai ke user sebagai
-- "Terjadi kesalahan. Coba lagi." tanpa penjelasan apa pun.
--
-- Sekarang username dinormalisasi dulu sebelum insert:
--   1. lowercase
--   2. buang semua karakter di luar [a-z0-9_]
--   3. potong ke 20 karakter
--   4. kalau hasil akhir kosong atau < 3 karakter, pakai username acak
--
-- Konsekuensi yang disengaja: username yang tadinya ditolak client-side kini
-- tetap diterima server dengan bentuk yang sudah dibersihkan. Username yang
-- duplicate masih ditolak constraint unique, dan itu memang perilaku yang benar.
create or replace function public.normalisasi_username(p_teks text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(
    left(
      regexp_replace(lower(coalesce(p_teks, '')), '[^a-z0-9_]', '', 'g'),
      20
    ),
    ''
  );
$$;

revoke all on function public.normalisasi_username(text) from public;

create or replace function public.username_acak()
returns text
language sql
volatile
set search_path = public
as $$
  select 'user_' || substr(md5(random()::text), 1, 8)
    where not exists (
      select 1 from public.profiles p where p.username = 'user_' || substr(md5(random()::text), 1, 8)
    );
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  uname text;
begin
  -- Coba username dari metadata lebih dulu; kalau tidak valid/tertaken,
  -- jatuh ke nama acak. Using EXISTS (bukan count) supaya username acak
  -- benar-benar dihitung ulang saat ada tabrakan, bukan selalu sama.
  uname := public.normalisasi_username(new.raw_user_meta_data->>'username');

  if uname is null or length(uname) < 3 then
    uname := null;
  elsif exists (select 1 from public.profiles p where p.username = uname) then
    -- Diambil user: jangan dibersihkan (mungkin hanya typo spasi) dan jangan
    -- diubah jadi tidak valid; jatuhkan ke nama acak.
    uname := null;
  end if;

  if uname is null then
    uname := public.username_acak();
  end if;

  insert into public.profiles (id, username, display_name, avatar_url)
  values (
    new.id, uname,
    left(coalesce(
      nullif(btrim(new.raw_user_meta_data->>'display_name'), ''),
      nullif(btrim(new.raw_user_meta_data->>'full_name'), '')
    ), 50),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Bucket foto profil.
--
-- Sengaja public: profile_reader memakai getPublicUrl, jadi avatar harus bisa
-- diambil tanpa sesi. Konsekuensinya siapa pun yang tahu URL-nya bisa
-- mengunduh gambar itu - itu memang yang diharapkan untuk avatar publik.
-- Jangan diubah ke private tanpa mengganti pemanggilnya di
-- profile_repository.dart, karena getPublicUrl akan langsung gagal.
--
-- do update (bukan do nothing) supaya berkas ini benar-benar menegakkan
-- public = true. Semula memakai do nothing, sehingga bucket yang pernah
-- dibuat private tidak pernah dikembalikan jadi public.
insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do update set public = excluded.public;

-- Semua pernyataan di berkas ini dibuat idempotent karena README menyuruh
-- operator menjalankannya manual di SQL Editor. Sebelumnya create table tanpa
-- if not exists membuat berkas berhenti di statement pertama saat dijalankan
-- ulang, sehingga trigger, policy, dan bucket tidak pernah ikut terpasang:
-- proyek tanpa trigger tidak punya baris profil sama sekali.
drop policy if exists "avatar publik bisa dibaca" on storage.objects;
create policy "avatar publik bisa dibaca" on storage.objects
  for select using (bucket_id = 'avatars');
drop policy if exists "upload avatar ke folder sendiri" on storage.objects;
create policy "upload avatar ke folder sendiri" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "update avatar sendiri" on storage.objects;
create policy "update avatar sendiri" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "hapus avatar sendiri" on storage.objects;
create policy "hapus avatar sendiri" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
