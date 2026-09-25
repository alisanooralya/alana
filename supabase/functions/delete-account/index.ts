import { createClient } from 'jsr:@supabase/supabase-js@2';

// Menghapus akun milik pemanggil secara permanen:
// 1. File di bucket `avatars` folder {user_id}/
// 2. User auth (data profiles/bookmarks/reading_history ikut via cascade)
// Wajib header Authorization (JWT user). Tidak menerima user_id dari body.
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

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Gunakan POST.' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'Wajib ada header Authorization.' }, 401);
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
    return json({ error: 'Konfigurasi server belum lengkap.' }, 500);
  }

  // Klien atas nama pemanggil untuk validasi token.
  const supabaseUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userError } =
    await supabaseUser.auth.getUser();
  if (userError || !user) {
    return json({ error: 'Sesi tidak valid. Masuk ulang.' }, 401);
  }

  // Klien admin (service role) hanya dipakai di sini, tidak dari klien.
  const supabaseAdmin = createClient(supabaseUrl, serviceKey);

  // Hapus file avatar milik user (folder mungkin tidak ada → abaikan).
  try {
    const { data: files, error: listError } = await supabaseAdmin
      .storage
      .from('avatars')
      .list(user.id);
    if (!listError && files && files.length > 0) {
      const paths = files.map((f) => `${user.id}/${f.name}`);
      const { error: removeError } = await supabaseAdmin
        .storage
        .from('avatars')
        .remove(paths);
      if (removeError) {
        return json(
          { error: `Gagal menghapus avatar: ${removeError.message}` },
          500,
        );
      }
    }
  } catch (e) {
    const pesan = e instanceof Error ? e.message : 'Tidak diketahui';
    return json({ error: `Gagal membersihkan storage: ${pesan}` }, 500);
  }

  const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(
    user.id,
  );
  if (deleteError) {
    return json({ error: deleteError.message }, 500);
  }

  return json({ success: true });
});
