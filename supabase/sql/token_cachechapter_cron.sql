-- Token FCM per perangkat
create table public.device_tokens (
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (device_id <> ''),
  fcm_token text not null check (fcm_token <> ''),
  updated_at timestamptz default now(),
  primary key (user_id, device_id)
);
alter table public.device_tokens enable row level security;
create policy "kelola token sendiri" on public.device_tokens
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index device_tokens_fcm_token_idx
  on public.device_tokens (fcm_token);
create index device_tokens_user_updated_at_idx
  on public.device_tokens (user_id, updated_at desc);

-- Cache chapter terbaru yang diketahui, untuk dibandingkan
create table public.manga_chapter_cache (
  manga_id text primary key,
  manga_title text not null,
  cover_url text,
  latest_chapter_id text,
  latest_chapter_title text,
  checked_at timestamptz default now()
);
-- Tabel ini hanya diakses oleh Edge Function via service role, RLS tidak perlu policy publik
alter table public.manga_chapter_cache enable row level security;

-- Aktifkan extension yang dibutuhkan cron memanggil HTTP
create extension if not exists pg_cron;
create extension if not exists pg_net;