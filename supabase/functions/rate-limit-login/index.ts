import { createClient } from 'jsr:@supabase/supabase-js@2';

const MAX_GAGAL_EMAIL = 5;
const MAX_GAGAL_IP = 30;
const JENDELA_MENIT = 15;

// Pembatas khusus aksi 'record' (K-2). Tanpa ini, endpoint record yang terbuka
// untuk publik bisa dipakai untuk mengunci email korban dengan email palsu dari
// satu IP, berulang tanpa batas. 60 call / 15 menit per IP:
//  - cukup longgar untuk satu IP dengan banyak pengguna (mis. NAT kantor),
//  - cukup ketat supaya satu penyerang hanya bisa mengunci email dalam jumlah
//    terbatas, bukan ribuan.
// Batas per email sengaja TIDAK ditambahkan di sini: attacker yang sudah
// melewati batas per email bisa amplifier dengan memutar IP, sedangkan batas
// per email juga bisa dipakai untuk mengunci korban dengan 5 call saja.
const MAX_RECORD_PER_IP = 60;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(data: unknown, status = 200, retryAfter?: number) {
  const headers: Record<string, string> = {
    ...corsHeaders,
    'Content-Type': 'application/json',
  };
  if (retryAfter !== undefined) {
    headers['Retry-After'] = String(retryAfter);
  }
  return new Response(JSON.stringify(data), { status, headers });
}

// Newer Supabase projects mengekspos secret lewat SUPABASE_SECRET_KEYS (JSON
// dengan key "default") dan tidak selalu menyertakan SUPABASE_SERVICE_ROLE_KEY.
// Jangan diubah: helper ini sudah dipakai delete-account dan login-with-username.
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

function ipDari(req: Request): string {
  const teruskan = (req.headers.get('x-forwarded-for') ?? '')
    .split(',')[0]
    .trim();
  const ip =
    req.headers.get('cf-connecting-ip')?.trim() ||
    req.headers.get('x-real-ip')?.trim() ||
    teruskan;
  return ip && ip.length > 0 ? ip : 'unknown';
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Gunakan POST.' }, 405);
  }

  let body: { action?: string; email?: string; success?: boolean };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Body harus JSON.' }, 400);
  }

  const email = (body.email ?? '').trim().toLowerCase();
  if (!email) {
    return json({ error: 'Field email wajib diisi.' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  // Service role: melewati RLS (tabel dikunci untuk anon/auth).
  const serviceKey = kunciDariJson(
    'SUPABASE_SECRET_KEYS',
    'SUPABASE_SERVICE_ROLE_KEY',
  );
  if (!supabaseUrl || !serviceKey) {
    // Jangan lanjut dengan kunci kosong: createClient tanpa kunci membuat
    // semua query error, cek() jadi fail-open, dan rate limiting mati diam-diam.
    return json(
      { error: 'Konfigurasi server belum lengkap.' },
      500,
    );
  }
  const supabase = createClient(supabaseUrl, serviceKey);
  const sejak = new Date(
    Date.now() - JENDELA_MENIT * 60 * 1000,
  ).toISOString();

  const ip = ipDari(req);
  const idEmail = `em:${email}`;
  const idIp = `ip:${ip}`;
  // Penghitung terpisah untuk pemanggilan aksi record (K-2).
  const idRecord = `rc:ip:${ip}`;

  const cek = async (
    identifier: string,
    maks: number,
  ): Promise<{ penuh: boolean; tunggu: number }> => {
    const { count, error } = await supabase
      .from('login_attempts')
      .select('id', { count: 'exact', head: true })
      .eq('identifier', identifier)
      .eq('success', false)
      .gte('created_at', sejak);
    if (error) return { penuh: false, tunggu: 0 };
    const gagal = count ?? 0;
    if (gagal < maks) return { penuh: false, tunggu: 0 };

    const { data } = await supabase
      .from('login_attempts')
      .select('created_at')
      .eq('identifier', identifier)
      .eq('success', false)
      .gte('created_at', sejak)
      .order('created_at', { ascending: true })
      .limit(1)
      .maybeSingle();
    let tunggu = JENDELA_MENIT * 60;
    if (data?.created_at) {
      const buka = new Date(data.created_at as string).getTime() +
        JENDELA_MENIT * 60 * 1000;
      tunggu = Math.max(1, Math.ceil((buka - Date.now()) / 1000));
    }
    return { penuh: true, tunggu };
  };

  if (body.action === 'record') {
    if (body.success == true) {
      // idRecord sengaja TIDAK ikut dihapus: kalau ikut, penyerang bisa
      // mereset anggaran record-nya sendiri dengan satu panggilan sukses
      // palsu. Baris idRecord sudah kedaluwarsa sendiri lewat created_at.
      const { error } = await supabase
        .from('login_attempts')
        .delete()
        .in('identifier', [idEmail, idIp, email]);
      if (error) return json({ error: error.message }, 500);
      return json({ allowed: true });
    }

    // K-2: bukti server-side berupa limiter khusus aksi record, per IP.
    // Tanpa langkah ini, siapa pun yang bisa memanggil endpoint publik ini
    // bisa mengunci email korban dengan email palsu, berulang tanpa batas.
    const batasRecord = await cek(idRecord, MAX_RECORD_PER_IP);
    if (batasRecord.penuh) {
      return json(
        {
          allowed: true,
          recorded: false,
          retry_after_seconds: batasRecord.tunggu,
          pesan: 'Terlalu banyak permintaan pencatatan. Coba lagi nanti.',
        },
        429,
        batasRecord.tunggu,
      );
    }

    const { error } = await supabase.from('login_attempts').insert([
      { identifier: idEmail, success: false },
      { identifier: idIp, success: false },
      { identifier: idRecord, success: false },
    ]);
    if (error) return json({ error: error.message }, 500);
    return json({ allowed: true, recorded: true });
  }

  const [perEmail, perIp] = await Promise.all([
    cek(idEmail, MAX_GAGAL_EMAIL),
    cek(idIp, MAX_GAGAL_IP),
  ]);

  if (perEmail.penuh || perIp.penuh) {
    return json(
      {
        allowed: false,
        retry_after_seconds: Math.max(perEmail.tunggu, perIp.tunggu),
        pesan: 'Terlalu banyak percobaan gagal. Coba lagi nanti.',
      },
      429,
      Math.max(perEmail.tunggu, perIp.tunggu),
    );
  }
  return json({ allowed: true });
});
