create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,              -- 'reading_reminder' | 'chapter_update' | 'system'
  title text not null,
  body text,
  manga_id text,
  chapter_id text,
  is_read boolean default false,
  created_at timestamptz default now()
);

alter table public.notifications enable row level security;

create policy "notifikasi milik sendiri" on public.notifications
  for select to authenticated using (auth.uid() = user_id);
create policy "update baca notifikasi sendiri" on public.notifications
  for update to authenticated using (auth.uid() = user_id);

create index on public.notifications (user_id, created_at desc);
