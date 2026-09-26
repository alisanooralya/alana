-- Upsert sinkronisasi dengan penjaga LWW di sisi server.
--
-- Sebelumnya dorong bookmark/riwayat memakai PostgREST upsert biasa
-- (resolution=merge-duplicates), yang menyelesaikan konflik berdasarkan urutan
-- kedatangan. Akibatnya push dari perangkat yang sedang offline dengan data
-- lebih lama menimpa baris yang lebih baru di server, dan aturan
-- last-write-wins yang dihitung di merge.dart praktis tidak berlaku di server.
--
-- Fungsi di bawah menolak update ketika stempel waktu baris yang masuk tidak
-- lebih baru dari baris yang sudah ada. Parameter waktu tetap dikirim sebagai
-- ISO-8601 WITH offset (UTC) supaya jam perangkat tidak menggeser perbandingan.

begin;

create or replace function public.upsert_sync_rows(
  p_user_id uuid,
  p_tabel text,
  p_rows jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r jsonb;
  ts timestamptz;
begin
  if p_user_id <> auth.uid() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if p_rows is null or jsonb_array_length(p_rows) = 0 then
    return;
  end if;

  for r in select * from jsonb_array_elements(p_rows) loop
    ts := coalesce(
      nullif(r->>'created_at', '')::timestamptz,
      nullif(r->>'updated_at', '')::timestamptz,
      now()
    );

    if p_tabel = 'bookmarks' then
      insert into public.bookmarks as b
        (user_id, manga_id, title, cover_url, created_at, deleted_at)
      values (
        p_user_id,
        r->>'manga_id',
        coalesce(nullif(r->>'title', ''), 'Tanpa judul'),
        r->>'cover_url',
        ts,
        null
      )
      on conflict (user_id, manga_id) do update
        set title = excluded.title,
            cover_url = excluded.cover_url,
            created_at = excluded.created_at,
            deleted_at = null
        -- Penjaga LWW: baris yang lebih lama tidak boleh menimpa.
        where excluded.created_at > b.created_at;

    elsif p_tabel = 'reading_history' then
      insert into public.reading_history as h
        (user_id, manga_id, manga_title, cover_url, chapter_id,
         chapter_title, scroll_position, updated_at, deleted_at)
      values (
        p_user_id,
        r->>'manga_id',
        coalesce(nullif(r->>'manga_title', ''), 'Tanpa judul'),
        r->>'cover_url',
        coalesce(nullif(r->>'chapter_id', ''), ''),
        r->>'chapter_title',
        coalesce((nullif(r->>'scroll_position', ''))::double precision, 0),
        ts,
        null
      )
      on conflict (user_id, manga_id) do update
        set manga_title = excluded.manga_title,
            cover_url = excluded.cover_url,
            chapter_id = excluded.chapter_id,
            chapter_title = excluded.chapter_title,
            scroll_position = excluded.scroll_position,
            updated_at = excluded.updated_at,
            deleted_at = null
        -- Penjaga LWW: baris yang lebih lama tidak boleh menimpa.
        where excluded.updated_at > h.updated_at;

    else
      raise exception 'tabel tidak dikenal: %', p_tabel using errcode = '22023';
    end if;
  end loop;
end;
$$;

revoke all on function public.upsert_sync_rows(uuid, text, jsonb) from public;

grant execute on function public.upsert_sync_rows(uuid, text, jsonb)
  to authenticated;

commit;
