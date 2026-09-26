-- Idempotent: aman dijalankan berulang di SQL Editor. Tanpa ini berkas
-- berhenti di statement pertama saat dijalankan ulang dan policy, trigger,
-- serta index tidak pernah ikut terpasang.

create table if not exists public.chapter_reports (
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

drop policy if exists "kirim laporan sendiri" on public.chapter_reports;
create policy "kirim laporan sendiri" on public.chapter_reports
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "lihat laporan sendiri" on public.chapter_reports;
create policy "lihat laporan sendiri" on public.chapter_reports
  for select to authenticated using (auth.uid() = user_id);

-- Tidak ada policy update/delete untuk user biasa -- laporan tidak bisa diubah/dihapus dari klien.
-- Kamu review lewat Table Editor dan ubah status manual, atau bikin RPC khusus nanti kalau perlu.

create index if not exists chapter_reports_status_created_at_idx on public.chapter_reports (status, created_at desc);

drop index if exists chapter_reports_dedupe;
create unique index chapter_reports_dedupe
  on public.chapter_reports (user_id, chapter_id)
  where status = 'pending';