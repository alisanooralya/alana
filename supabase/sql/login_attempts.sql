-- Tabel pencatatan percobaan login (untuk rate limiting).
-- Jalankan manual di Dashboard Supabase → SQL Editor → New query.
--
-- Hanya Edge Function (service_role) yang boleh baca/tulis tabel ini:
-- RLS aktif TANPA policy untuk anon/authenticated, jadi akses langsung
-- via Data API selalu ditolak. Jangan tambah policy publik.

create extension if not exists "pgcrypto";

create table if not exists public.login_attempts (
  id uuid primary key default gen_random_uuid(),
  identifier text not null,
  success boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists login_attempts_identifier_created_idx
  on public.login_attempts (identifier, created_at desc);

alter table public.login_attempts enable row level security;
