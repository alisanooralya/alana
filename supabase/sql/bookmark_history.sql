-- Idempotent: aman dijalankan berulang di SQL Editor. Tanpa ini berkas
-- berhenti di statement pertama saat dijalankan ulang dan policy, trigger,
-- serta index tidak pernah ikut terpasang.

create table if not exists public.bookmarks (
  user_id uuid not null references auth.users(id) on delete cascade,
  manga_id text not null,
  title text not null,
  cover_url text,
  created_at timestamptz default now(),
  primary key (user_id, manga_id)
);

create table if not exists public.reading_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  manga_id text not null,
  manga_title text not null,
  cover_url text,
  chapter_id text not null,
  chapter_title text,
  scroll_position double precision default 0,
  updated_at timestamptz default now(),
  primary key (user_id, manga_id)
);

alter table public.bookmarks enable row level security;
alter table public.reading_history enable row level security;

drop policy if exists "bookmark milik sendiri" on public.bookmarks;
create policy "bookmark milik sendiri" on public.bookmarks
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "riwayat milik sendiri" on public.reading_history;
create policy "riwayat milik sendiri" on public.reading_history
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists reading_history_user_updated_at_idx on public.reading_history (user_id, updated_at desc);
create index if not exists bookmarks_user_created_at_idx on public.bookmarks (user_id, created_at desc);
