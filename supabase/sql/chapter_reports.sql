create table public.chapter_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  manga_id text not null,
  manga_title text not null,
  chapter_id text not null,
  chapter_title text,
  reason text not null,        -- 'gambar_rusak' | 'gambar_tidak_lengkap' | 'salah_urutan' | 'lainnya'
  note text,
  status text not null default 'pending',  -- 'pending' | 'reviewed' | 'resolved'
  created_at timestamptz default now()
);

alter table public.chapter_reports enable row level security;

create policy "kirim laporan sendiri" on public.chapter_reports
  for insert to authenticated with check (auth.uid() = user_id);

create policy "lihat laporan sendiri" on public.chapter_reports
  for select to authenticated using (auth.uid() = user_id);

-- Tidak ada policy update/delete untuk user biasa -- laporan tidak bisa diubah/dihapus dari klien.
-- Kamu review lewat Table Editor dan ubah status manual, atau bikin RPC khusus nanti kalau perlu.

create index on public.chapter_reports (status, created_at desc);

create unique index chapter_reports_dedupe
  on public.chapter_reports (user_id, chapter_id)
  where status = 'pending';