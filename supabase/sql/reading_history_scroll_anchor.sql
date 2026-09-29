-- Posisi baca sebagai anchor (indeks + tepi depan), bukan piksel absolut.
--
-- alasan: tinggi item reader pernah berubah-ubah — placeholder 0,6 kali lebar
-- lalu rasio asli yang bisa berbeda 16 kali antarhalaman. Offset piksel yang
-- disimpan jadi tidak punya indeks yang bisa dipercaya, dan tidak bisa
-- dikonversi ke indeks karena tinggi saat disimpan sudah tidak berlaku.
-- `scroll_index` + `scroll_leading` bebas ukuran layar: keduanya dinormalisasi
-- terhadap tinggi viewport.
--
-- Kolom `scroll_position` sengaja dibiarkan ada. Versi aplikasi lama masih
-- membacanya, dan dihapus sekarang akan merusak posisinya di perangkat itu.
--
-- Jalankan manual di SQL Editor Supabase.

alter table public.reading_history
  add column scroll_index integer default 0,
  add column scroll_leading double precision default 0;

-- Isi kolom baru untuk baris lama. Baris lama hanya punya piksel, yang tidak
-- bisa dikonversi, jadi ditulis 0: efeknya reader membuka chapter dari awal,
-- bukan melompat ke tempat yang salah. `lastChapterId` sudah dijaga
-- pemeriksaan `lastChapterId == chapterId` sebelum restore, jadi tidak ada
-- yang terpakai untuk chapter yang salah.
update public.reading_history
   set scroll_index = 0,
       scroll_leading = 0
 where scroll_index is null or scroll_leading is null;

-- Fungsi sinkronisasi juga harus membawa kolom baru. Tanpa bagian ini, push
-- dari aplikasi akan diam-diam membuang posisi: kolom ada di tabel tapi tidak
-- pernah diisi karena insert/update di dalam fungsi tidak menyebutkannya.
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
         chapter_title, scroll_index, scroll_leading, scroll_position,
         updated_at, deleted_at)
      values (
        p_user_id,
        r->>'manga_id',
        coalesce(nullif(r->>'manga_title', ''), 'Tanpa judul'),
        r->>'cover_url',
        coalesce(nullif(r->>'chapter_id', ''), ''),
        r->>'chapter_title',
        coalesce((nullif(r->>'scroll_index', ''))::integer, 0),
        coalesce((nullif(r->>'scroll_leading', ''))::double precision, 0),
        coalesce((nullif(r->>'scroll_position', ''))::double precision, 0),
        ts,
        null
      )
      on conflict (user_id, manga_id) do update
        set manga_title = excluded.manga_title,
            cover_url = excluded.cover_url,
            chapter_id = excluded.chapter_id,
            chapter_title = excluded.chapter_title,
            scroll_index = excluded.scroll_index,
            scroll_leading = excluded.scroll_leading,
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
