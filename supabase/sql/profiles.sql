create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text,
  avatar_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "profil bisa dibaca user login" on public.profiles
  for select to authenticated using (true);
create policy "update profil sendiri" on public.profiles
  for update to authenticated using (auth.uid() = id);
create policy "insert profil sendiri" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

-- Otomatis buat profil saat user baru mendaftar (email maupun Google)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  uname text;
begin
  uname := lower(coalesce(
    new.raw_user_meta_data->>'username',
    'user_' || substr(md5(random()::text), 1, 8)
  ));
  insert into public.profiles (id, username, display_name, avatar_url)
  values (
    new.id, uname,
    coalesce(new.raw_user_meta_data->>'display_name',
             new.raw_user_meta_data->>'full_name'),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Bucket foto profil
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true);

create policy "avatar publik bisa dibaca" on storage.objects
  for select using (bucket_id = 'avatars');
create policy "upload avatar ke folder sendiri" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "update avatar sendiri" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "hapus avatar sendiri" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
