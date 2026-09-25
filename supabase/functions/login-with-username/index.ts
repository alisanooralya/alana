import { createClient } from 'jsr:@supabase/supabase-js@2';

// Login dengan username (tanpa sesi). Dipanggil TANPA login,
// jadi fungsi ini di-deploy dengan verify_jwt = false.
//
// Alur: normalisasi username → rate limit (IP+username, tabel
// login_attempts) → cari profil → ambil email via admin →
// signInWithPassword server-side → kembalikan HANYA token.
//
// SEMUA kegagalan (format salah, username tidak ada, password salah,
// akun Google-only) mengembalikan 401 + pesan yang SAMA agar tidak
// bisa dipakai menebak username/email. Tidak ada log berisi PII.
const GAGAL_PESAN = 'Username atau password salah';
const MAX_GAGAL = 5;
const JENDELA_MENIT = 1;
const USERNAME_RE = /^[a-z0-9_]{3,20}$/;

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

// Key API baru tinggal di env JSON terpisah; fallback ke var lama
// agar tetap jalan di project lama (lihat check-new-chapters).
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

const gagal = () => json({ error: GAGAL_PESAN }, 401);

function ipDari(req: Request): string {
  return (
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-real-ip') ??
    (req.headers.get('x-forwarded-for') ?? '').split(',')[0].trim() ??
    'unknown'
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return gagal();
  }

  let body: { username?: unknown; password?: unknown };
  try {
    body = await req.json();
  } catch {
    return gagal();
  }

  const username = String(body.username ?? '').trim().toLowerCase();
  const password = typeof body.password === 'string' ? body.password : '';
  if (!USERNAME_RE.test(username) || !password) {
    return gagal();
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = kunciDariJson(
    'SUPABASE_PUBLISHABLE_KEYS',
    'SUPABASE_ANON_KEY',
  );
  const serviceKey = kunciDariJson(
    'SUPABASE_SECRET_KEYS',
    'SUPABASE_SERVICE_ROLE_KEY',
  );
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return gagal();
  }

  const kunci = `ul:${ipDari(req)}:${username}`;
  const sejak = new Date(
    Date.now() - JENDELA_MENIT * 60 * 1000,
  ).toISOString();

  const admin = createClient(supabaseUrl, serviceKey);

  // Rate limit: hitung gagal dalam jendela (kunci IP+username).
  try {
    const { count } = await admin
      .from('login_attempts')
      .select('id', { count: 'exact', head: true })
      .eq('identifier', kunci)
      .eq('success', false)
      .gte('created_at', sejak);
    if ((count ?? 0) >= MAX_GAGAL) {
      return gagal();
    }
  } catch {
    return gagal();
  }

  const catatGagal = async () => {
    try {
      await admin.from('login_attempts').insert({
        identifier: kunci,
        success: false,
      });
    } catch {
      // Abaikan: kegagalan pencatatan tidak boleh membuka oracle.
    }
  };

  // Cari profil → email via admin.
  let email = '';
  try {
    const { data: profil } = await admin
      .from('profiles')
      .select('id')
      .eq('username', username)
      .maybeSingle();
    const uid = profil?.id as string | undefined;
    if (!uid) {
      await catatGagal();
      return gagal();
    }
    const { data: { user } } = await admin.auth.admin.getUserById(uid);
    email = user?.email ?? '';
    if (!email) {
      await catatGagal();
      return gagal();
    }
  } catch {
    await catatGagal();
    return gagal();
  }

  // Login server-side sebagai klien anon.
  try {
    const anon = createClient(supabaseUrl, anonKey);
    const { data, error } = await anon.auth.signInWithPassword({
      email,
      password,
    });
    if (error || !data.session) {
      await catatGagal();
      return gagal();
    }
    // Sukses: reset hitungan kunci ini, kembalikan HANYA token.
    try {
      await admin.from('login_attempts').delete().eq('identifier', kunci);
    } catch {
      // Abaikan.
    }
    return json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
    });
  } catch {
    await catatGagal();
    return gagal();
  }
});
