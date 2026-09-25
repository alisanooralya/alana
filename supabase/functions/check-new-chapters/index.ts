import { createClient } from 'jsr:@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'npm:jose@4';

// Cek chapter baru untuk semua manga yang di-bookmark, lalu kirim
// notifikasi + push FCM ke pemiliknya.
//
// Dipanggil server-to-server oleh pg_cron. Verifikasi: header
// Authorization harus berisi service role key project ini
// (dibandingkan dengan env SUPABASE_SERVICE_ROLE_KEY).
//
// Endpoint API manhwa SAMA dengan service Flutter:
// - MangaApiService.getChapterList -> GET {API}/v1/chapter/{mangaId}/list
//   (di Flutter: base https://api.shngm.io + header Origin/Referer).
// - Chapter terbaru = elemen dengan chapter_number terbesar
//   (fallback: elemen pertama bila number tak terbaca).
//
// Rate ke API sumber dibatasi: jeda 400ms antar manga + maks 100 manga/run.
// Push FCM paralel terbatas 20 token sekaligus (allSettled); token yang
// mati (UNREGISTERED) dihapus agar tidak menumpuk.
//
// TES MANUAL (curl) — ganti <REF> dan key yang sesuai:
// 1. HARUS 200 (service role):
//    curl -X POST https://<REF>.supabase.co/functions/v1/check-new-chapters \
//      -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
//      -H "Content-Type: application/json" -d '{}'
// 2. HARUS 401 (anon key):
//    curl -X POST https://<REF>.supabase.co/functions/v1/check-new-chapters \
//      -H "Authorization: Bearer <ANON_KEY>" \
//      -H "Content-Type: application/json" -d '{}'
// 3. HARUS 401 (tanpa header):
//    curl -X POST https://<REF>.supabase.co/functions/v1/check-new-chapters \
//      -H "Content-Type: application/json" -d '{}'
// 4. HARUS 401 (key ngawur):
//    curl -X POST https://<REF>.supabase.co/functions/v1/check-new-chapters \
//      -H "Authorization: Bearer salah" \
//      -H "Content-Type: application/json" -d '{}'
const MAX_MANGA_PER_RUN = 100;
const JEDA_MS_ANTAR_MANGA = 1200;
const BATCH_TOKEN = 20;
// Retry backoff bila ditolak (WAF/rate-limit): 2s lalu 8s.
const TUNDA_ULANG_MS = [2000, 8000];

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

const tidur = (ms: number) => new Promise((r) => setTimeout(r, ms));

// ---- OAuth2 access token FCM (cache di memori selama valid) ----
let tokenCache: { token: string; exp: number } | null = null;

async function tokenAksesFcm(saJson: string): Promise<string> {
  if (tokenCache && Date.now() < tokenCache.exp) return tokenCache.token;
  const sa = JSON.parse(saJson) as {
    client_email: string;
    private_key: string;
    project_id: string;
  };
  const kini = Math.floor(Date.now() / 1000);
  const jwt = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt(kini)
    .setExpirationTime(kini + 3600)
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .sign(await importPKCS8(sa.private_key, 'RS256'));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data = (await res.json()) as {
    access_token?: string;
    expires_in?: number;
  };
  if (!res.ok || !data.access_token) {
    throw new Error('Gagal menukar OAuth token FCM.');
  }
  tokenCache = {
    token: data.access_token,
    exp: Date.now() + ((data.expires_in ?? 3600) - 300) * 1000,
  };
  return tokenCache.token;
}

// ---- Bentuk chapter dari API (toleran beberapa shape) ----
type ChapterBaru = { id: string; nomor: number; judul: string };

function chapterTeratas(payload: unknown): ChapterBaru | null {
  let mentah: unknown[] = [];
  if (Array.isArray(payload)) {
    mentah = payload;
  } else if (payload && typeof payload === 'object') {
    const p = payload as Record<string, unknown>;
    for (const kunci of ['chapter_list', 'data']) {
      if (Array.isArray(p[kunci])) {
        mentah = p[kunci] as unknown[];
        break;
      }
    }
  }
  let terbaik: ChapterBaru | null = null;
  let pertama: ChapterBaru | null = null;
  for (const item of mentah) {
    if (!item || typeof item !== 'object') continue;
    const m = item as Record<string, unknown>;
    const id = String(
      m['chapter_id'] ?? m['id'] ?? '',
    );
    if (!id) continue;
    const mentahNomor = m['chapter_number'] ?? m['name'] ?? m['number'];
    const nomor = parseFloat(String(mentahNomor ?? 'NaN'));
    const judul = String(m['chapter_title'] ?? m['title'] ?? '');
    const entri = {
      id,
      nomor: Number.isFinite(nomor) ? nomor : -1,
      judul,
    };
    pertama ??= entri;
    if (terbaik === null || entri.nomor > terbaik.nomor) terbaik = entri;
  }
  if (terbaik && terbaik.nomor >= 0) return terbaik;
  return pertama;
}

function acakPanjang(n: number): string {
  const huruf = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const acak = new Uint8Array(n);
  crypto.getRandomValues(acak);
  return Array.from(acak, (b) => huruf[b % huruf.length]).join('');
}

async function ambilChapterTerbaru(mangaId: string): Promise<ChapterBaru> {
  // page_size kecil (30) cukup: daftar terurut terbaru dulu, dan
  // chapterTeratas mengambil number terbesar sebagai pengaman.
  const url =
    `https://api.shngm.io/v1/chapter/${encodeURIComponent(mangaId)}/list` +
    `?page_size=30`;
  // Header meniru browser desktop: API memblokir UA non-browser
  // (Deno/* kena 403) dan butuh Origin/Referer layaknya klien Flutter.
  const headers = {
    'Accept': 'application/json',
    'DNT': '1',
    'Origin': 'https://app.shinigami.asia',
    'Referer': 'https://app.shinigami.asia/',
    'Sec-GPC': '1',
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'X-Requested-With': acakPanjang(10),
  };
  let terakhir = 0;
  for (let coba = 0; coba <= TUNDA_ULANG_MS.length; coba++) {
    const res = await fetch(url, { headers });
    if (res.ok) {
      const hasil = chapterTeratas(await res.json());
      if (!hasil) throw new Error('Daftar chapter kosong');
      return hasil;
    }
    terakhir = res.status;
    // Hanya 403/429 yang dicoba ulang dengan backoff.
    if (
      (res.status === 403 || res.status === 429) &&
      coba < TUNDA_ULANG_MS.length
    ) {
      await tidur(TUNDA_ULANG_MS[coba]);
      continue;
    }
    throw new Error(`API manhwa ${res.status}`);
  }
  throw new Error(`API manhwa ${terakhir}`);
}

function fcmGagalUnregistered(badan: unknown): boolean {
  try {
    return JSON.stringify(badan).includes('UNREGISTERED');
  } catch {
    return false;
  }
}

// Key API baru (publishable/secret) tinggal di env JSON terpisah
// (SUPABASE_SECRET_KEYS / SUPABASE_PUBLISHABLE_KEYS); fallback ke
// var lama (SERVICE_ROLE/ANON) agar tetap jalan di project lama.
function kunciDariJson(namaJson: string, namaLama: string): string {
  try {
    const semua = Deno.env.get(namaJson);
    if (semua) {
      const parsed = JSON.parse(semua) as Record<string, unknown>;
      const v = parsed['default'];
      if (typeof v === 'string' && v) return v;
    }
  } catch {
    // Abaikan, pakai fallback.
  }
  return Deno.env.get(namaLama) ?? '';
}

const kunciRahasia = () =>
  kunciDariJson('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY');

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Gunakan POST.' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = kunciRahasia();
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? '';
  const mentah = req.headers.get('Authorization') ?? '';

  // Hapus prefix "Bearer " (case-insensitive) lalu trim kedua sisi
  // agar kebal spasi/newline nyasar dari curl/env.
  // HANYA service role yang diterima: perbandingan string biasa,
  // BUKAN validasi JWT (anon key pun JWT valid dan harus ditolak).
  const token = mentah.replace(/^Bearer\s+/i, '').trim();
  const kunci = serviceKey.trim();
  const anon = anonKey.trim();
  const cocok = token.length > 0 && kunci.length > 0 && token === kunci;
  // Sabuk ganda: tolak eksplisit bila token sama dengan anon key,
  // seandainya env service role bermasalah.
  const anonLolos = anon.length > 0 && token === anon;
  if (!supabaseUrl || !kunci || !saJson || !cocok || anonLolos) {
    return json({ error: 'Unauthorized.' }, 401);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  let dicek = 0;
  let diupdate = 0;
  let notifBaru = 0;
  let pushTerkirim = 0;
  let pushGagal = 0;

  // 1. Daftar manga unik yang di-bookmark.
  const { data: bm, error: errBm } = await admin
    .from('bookmarks')
    .select('manga_id, user_id, title, cover_url');
  if (errBm) {
    console.error('check-new-chapters: gagal baca bookmarks', errBm.message);
    return json({ error: 'Gagal membaca bookmarks.' }, 500);
  }
  const perManga = new Map<string, typeof bm>();
  for (const b of bm ?? []) {
    const id = String((b as Record<string, unknown>)['manga_id'] ?? '');
    if (!id) continue;
    if (!perManga.has(id)) perManga.set(id, []);
    perManga.get(id)!.push(b);
  }
  const daftarManga = [...perManga.keys()].slice(0, MAX_MANGA_PER_RUN);
  console.log(`check-new-chapters: ${daftarManga.length} manga dicek`);

  const proyek = (JSON.parse(saJson) as { project_id?: string }).project_id ?? '';
  let aksesToken = '';
  try {
    aksesToken = await tokenAksesFcm(saJson);
  } catch (e) {
    console.error('check-new-chapters: gagal token FCM', String(e));
    return json({ error: 'Gagal otorisasi FCM.' }, 500);
  }

  for (const mangaId of daftarManga) {
    dicek++;
    try {
      const { data: cache } = await admin
        .from('manga_chapter_cache')
        .select('latest_chapter_id')
        .eq('manga_id', mangaId)
        .maybeSingle();
      const cacheId = (cache as Record<string, unknown> | null)
        ?.['latest_chapter_id'] as string | undefined;

      const terbaru = await ambilChapterTerbaru(mangaId);
      if (cacheId && cacheId === terbaru.id) {
        await admin.from('manga_chapter_cache').update({
          checked_at: new Date().toISOString(),
        }).eq('manga_id', mangaId);
        continue;
      }

      // Chapter baru (atau cache belum ada).
      diupdate++;
      const contoh = perManga.get(mangaId)![0] as Record<string, unknown>;
      const judulManga = String(
        contoh['title'] ?? mangaId,
      );
      const cover = String(contoh['cover_url'] ?? '');
      await admin.from('manga_chapter_cache').upsert({
        manga_id: mangaId,
        manga_title: judulManga,
        cover_url: cover || null,
        latest_chapter_id: terbaru.id,
        latest_chapter_title: terbaru.judul || null,
        checked_at: new Date().toISOString(),
      }, { onConflict: 'manga_id' });
      console.log(
        `check-new-chapters: BARU ${mangaId} -> ${terbaru.id} (${terbaru.judul})`,
      );

      const userIds = [
        ...new Set(
          perManga.get(mangaId)!.map(
            (b) => String((b as Record<string, unknown>)['user_id'] ?? ''),
          ).filter((u) => u),
        ),
      ];

      // Lewati user yang sudah punya notif unread untuk chapter ini.
      const { data: sudahAda } = await admin
        .from('notifications')
        .select('user_id')
        .eq('manga_id', mangaId)
        .eq('chapter_id', terbaru.id)
        .eq('is_read', false)
        .in('user_id', userIds.length > 0 ? userIds : ['00000000-0000-0000-0000-000000000000']);
      const punya = new Set(
        (sudahAda ?? []).map(
          (r) => String((r as Record<string, unknown>)['user_id'] ?? ''),
        ),
      );
      const target = userIds.filter((u) => !punya.has(u));
      if (target.length === 0) continue;

      const judulNotif = `Chapter baru: ${judulManga}`;
      const isiNotif = terbaru.judul
        ? `${terbaru.judul} sudah tersedia.`
        : 'Chapter terbaru sudah tersedia.';
      const linkBab = `alana://manga/${encodeURIComponent(mangaId)}/chapter/${encodeURIComponent(String(terbaru.id))}`;
      const { error: errNotif } = await admin.from('notifications').insert(
        target.map((uid) => ({
          user_id: uid,
          type: 'chapter_update',
          title: judulNotif,
          body: isiNotif,
          manga_id: mangaId,
          chapter_id: terbaru.id,
        })),
      );
      if (errNotif) {
        console.error(
          `check-new-chapters: gagal insert notif ${mangaId}`,
          errNotif.message,
        );
        continue;
      }
      notifBaru += target.length;

      // Token perangkat target.
      const { data: tokens } = await admin
        .from('device_tokens')
        .select('fcm_token')
        .in('user_id', target);
      const daftarToken = [
        ...new Set(
          (tokens ?? []).map(
            (t) => String((t as Record<string, unknown>)['fcm_token'] ?? ''),
          ).filter((t) => t),
        ),
      ];

      // Kirim paralel terbatas 20; token mati dihapus.
      for (let i = 0; i < daftarToken.length; i += 20) {
        const batch = daftarToken.slice(i, i + 20);
        const hasil = await Promise.allSettled(batch.map(async (token) => {
          const res = await fetch(
            `https://fcm.googleapis.com/v1/projects/${proyek}/messages:send`,
            {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${aksesToken}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                message: {
                  token,
                  notification: { title: judulNotif, body: isiNotif },
                  data: {
                    type: 'chapter_update',
                    link: linkBab,
                    manga_id: mangaId,
                    chapter_id: terbaru.id,
                  },
                  android: {
                    priority: 'high',
                    notification: { channel_id: 'bab_baru' },
                  },
                },
              }),
            },
          );
          const badan = await res.json().catch(() => ({}));
          if (!res.ok && fcmGagalUnregistered(badan)) {
            await admin.from('device_tokens').delete().eq(
              'fcm_token',
              token,
            );
            return 'mati';
          }
          if (!res.ok) throw new Error(`FCM ${res.status}`);
          return 'ok';
        }));
        for (const h of hasil) {
          if (h.status === 'fulfilled' && h.value === 'ok') pushTerkirim++;
          else pushGagal++;
        }
      }
    } catch (e) {
      console.error(`check-new-chapters: gagal proses ${mangaId}`, String(e));
    }
    await tidur(JEDA_MS_ANTAR_MANGA);
  }

  console.log(
    `check-new-chapters: selesai dicek=${dicek} update=${diupdate} ` +
    `notif=${notifBaru} push_ok=${pushTerkirim} push_gagal=${pushGagal}`,
  );
  return json({
    checked: dicek,
    updated: diupdate,
    notifikasi: notifBaru,
    push_terkirim: pushTerkirim,
    push_gagal: pushGagal,
  });
});
