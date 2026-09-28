import { createClient } from 'jsr:@supabase/supabase-js@2';

const MAX_GAGAL_EMAIL = 5;
const MAX_GAGAL_IP = 30;
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

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    // Service role: melewati RLS (tabel dikunci untuk anon/auth).
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );
  const sejak = new Date(
    Date.now() - JENDELA_MENIT * 60 * 1000,
  ).toISOString();

  const idEmail = `em:${email}`;
  const idIp = `ip:${ipDari(req)}`;

  if (body.action === 'record') {
    if (body.success == true) {
      const { error } = await supabase
        .from('login_attempts')
        .delete()
        .in('identifier', [idEmail, idIp, email]);
      if (error) return json({ error: error.message }, 500);
      return json({ allowed: true });
    }
    const { error } = await supabase.from('login_attempts').insert([
      { identifier: idEmail, success: false },
      { identifier: idIp, success: false },
    ]);
    if (error) return json({ error: error.message }, 500);
    return json({ allowed: true, recorded: true });
  }

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
