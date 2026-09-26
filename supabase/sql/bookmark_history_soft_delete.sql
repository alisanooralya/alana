-- Soft delete untuk bookmarks + reading_history.
--
-- Sebelumnya hapus memakai DELETE keras. Akibatnya server tidak bisa
-- membedakan "belum pernah ada" dari "dihapus di perangkat lain", sehingga
-- perangkat yang masih menyimpan salinan lama akan mengunggah ulang item itu
-- dan resurrect bookmark/riwayat yang sudah dihapus user.
--
-- Sekarang hapus ditandai lewat `deleted_at`. Baris tetap ada sebagai
-- tombstone dan bisa disinkronkan ke semua perangkat.

begin;

alter table public.bookmarks
  add column if not exists deleted_at timestamptz;

alter table public.reading_history
  add column if not exists deleted_at timestamptz;

create index if not exists bookmarks_user_deleted_idx
  on public.bookmarks (user_id, deleted_at);

create index if not exists reading_history_user_deleted_idx
  on public.reading_history (user_id, deleted_at);

-- Soft delete satu batch. SECURITY DEFINER diperlukan agar RLS tidak
-- memblokir update, jadi verifikasi pemilik WAJIB dilakukan di sini.
-- Waktu hapus memakai now() (jam server) supaya tidak bergantung jam perangkat.
create or replace function public.soft_delete_sync_rows(
  p_user_id uuid,
  p_tabel text,
  p_manga_ids text[]
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id <> auth.uid() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if p_manga_ids is null or cardinality(p_manga_ids) = 0 then
    return;
  end if;

  if p_tabel = 'bookmarks' then
    update public.bookmarks
       set deleted_at = now(),
           created_at = now()
     where user_id = p_user_id
       and manga_id = any(p_manga_ids);
  elsif p_tabel = 'reading_history' then
    update public.reading_history
       set deleted_at = now(),
           updated_at = now()
     where user_id = p_user_id
       and manga_id = any(p_manga_ids);
  else
    raise exception 'tabel tidak dikenal: %', p_tabel using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.soft_delete_sync_rows(uuid, text, text[])
  from public;

grant execute on function public.soft_delete_sync_rows(uuid, text, text[])
  to authenticated;

commit;
