import { createClient } from 'jsr:@supabase/supabase-js@2';

// Batas: 5x gagal dalam 15 menit per identifier (email huruf kecil).
const MAX_GAGAL = 5;
const JENDELA_MENIT = 15;

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

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    // Service role: melewati RLS (tabel dikunci untuk anon/auth).
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );
  const sejak = new Date(
    Date.now() - JENDELA_MENIT * 60 * 1000,
  ).toISOString();

  if (body.action === 'record') {
    // Dipanggil SETELAH percobaan login: catat hasil.
    // Sukses → hapus riwayat identifier (reset hitungan).
    if (body.success == true) {
      const { error } = await supabase
        .from('login_attempts')
        .delete()
        .eq('identifier', email);
      if (error) return json({ error: error.message }, 500);
      return json({ allowed: true, remaining: MAX_GAGAL });
    }
    const { error } = await supabase.from('login_attempts').insert({
      identifier: email,
      success: false,
    });
    if (error) return json({ error: error.message }, 500);
    return json({ allowed: true, recorded: true });
  }

  // Default: action 'check' — dipanggil SEBELUM percobaan login.
  const { count, error } = await supabase
    .from('login_attempts')
    .select('id', { count: 'exact', head: true })
    .eq('identifier', email)
    .eq('success', false)
    .gte('created_at', sejak);
  if (error) return json({ error: error.message }, 500);

  const gagal = count ?? 0;
  if (gagal >= MAX_GAGAL) {
    // Cari kapan jendela bergulir (kegagalan tertua dalam jendela).
    const { data } = await supabase
      .from('login_attempts')
      .select('created_at')
      .eq('identifier', email)
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
    return json(
      {
        allowed: false,
        remaining: 0,
        retry_after_seconds: tunggu,
        pesan: 'Terlalu banyak percobaan gagal. Coba lagi nanti.',
      },
      429,
      tunggu,
    );
  }
  return json({ allowed: true, remaining: MAX_GAGAL - gagal });
});
