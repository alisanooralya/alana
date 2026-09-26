const fs = require('node:fs');
const path = require('node:path');
const cron = require('node-cron');
const { createClient } = require('@supabase/supabase-js');
const { cert, getApps, initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

require('dotenv').config();

const API_BASE_URL = (process.env.API_BASE_URL || 'https://api.shngm.io').replace(/\/$/, '');
const API_DELAY_MS = Math.max(0, Number(process.env.API_DELAY_MS || 1500));
const CRON_SCHEDULE = process.env.CRON_SCHEDULE || '0 */4 * * *';
const CRON_TIMEZONE = process.env.CRON_TIMEZONE || 'UTC';
const MAX_MANGA_PER_RUN = Math.max(1, Number(process.env.MAX_MANGA_PER_RUN || 100));
const CHAPTER_CHANNEL_ID = 'bab_baru';

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Environment variable ${name} wajib diisi.`);
  return value;
}

function loadServiceAccount() {
  const value = requiredEnv('FIREBASE_SERVICE_ACCOUNT');
  if (value.startsWith('{')) return JSON.parse(value);
  return JSON.parse(fs.readFileSync(path.resolve(value), 'utf8'));
}

const supabase = createClient(
  requiredEnv('SUPABASE_URL'),
  requiredEnv('SUPABASE_SECRET_KEY'),
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  },
);

const firebaseApp = getApps()[0] || initializeApp({
  credential: cert(loadServiceAccount()),
});
const messaging = getMessaging(firebaseApp);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function deepLink(mangaId, chapterId) {
  return `alana://manga/${encodeURIComponent(mangaId)}/chapter/${encodeURIComponent(chapterId)}`;
}

async function latestChapter(mangaId) {
  const url = `${API_BASE_URL}/v1/manga/detail/${encodeURIComponent(mangaId)}`;
  const response = await fetch(url, {
    headers: { Accept: 'application/json' },
  });
  if (!response.ok) {
    const body = (await response.text().catch(() => ''))
      .replace(/\s+/g, ' ')
      .slice(0, 300);
    throw new Error(`API manhwa ${response.status}${body ? `: ${body}` : ''}`);
  }

  const payload = await response.json();
  const detail = payload?.data && typeof payload.data === 'object' ? payload.data : payload;
  const chapterId = String(detail?.latest_chapter_id ?? '');
  if (!chapterId) throw new Error('Detail manga tidak memiliki chapter terbaru.');

  const rawNumber = Number.parseFloat(String(detail?.latest_chapter_number ?? 'NaN'));
  return {
    id: chapterId,
    number: Number.isFinite(rawNumber) ? rawNumber : -1,
    title: String(detail?.latest_chapter_title ?? ''),
  };
}

function unreadTargets(userIds, mangaId, chapterId) {
  return supabase
    .from('notifications')
    .select('user_id')
    .eq('manga_id', mangaId)
    .eq('chapter_id', chapterId)
    .eq('is_read', false)
    .in('user_id', userIds)
    .then(({ data, error }) => {
      if (error) throw error;
      return new Set((data || []).map((row) => row.user_id));
    });
}

function unregisteredToken(error) {
  const code = String(error?.code || '');
  return code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/invalid-argument';
}

async function sendPush(tokens, stats, payload) {
  const uniqueTokens = [...new Set(tokens.filter(Boolean))];
  for (let index = 0; index < uniqueTokens.length; index += 500) {
    const batch = uniqueTokens.slice(index, index + 500);
    try {
      const response = await messaging.sendEachForMulticast({
        tokens: batch,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        android: {
          priority: 'high',
          notification: { channelId: CHAPTER_CHANNEL_ID },
        },
      });

      for (let resultIndex = 0; resultIndex < response.responses.length; resultIndex += 1) {
        const result = response.responses[resultIndex];
        if (result.success) {
          stats.pushOk += 1;
          continue;
        }
        stats.pushFail += 1;
        if (unregisteredToken(result.error)) {
          const token = batch[resultIndex];
          const { error } = await supabase
            .from('device_tokens')
            .delete()
            .eq('fcm_token', token);
          if (error) {
            console.error(`Gagal hapus token FCM: ${error.message}`);
          } else {
            stats.tokenRemoved += 1;
          }
        }
      }
    } catch (error) {
      stats.pushFail += batch.length;
      console.error(`Gagal kirim batch FCM: ${error.message}`);
    }
  }
}

async function processManga(manga, stats) {
  const chapter = await latestChapter(manga.mangaId);
  const { data: cache, error: cacheReadError } = await supabase
    .from('manga_chapter_cache')
    .select('latest_chapter_id')
    .eq('manga_id', manga.mangaId)
    .maybeSingle();
  if (cacheReadError) throw cacheReadError;

  if (cache?.latest_chapter_id === chapter.id) {
    const { error } = await supabase
      .from('manga_chapter_cache')
      .update({ checked_at: new Date().toISOString() })
      .eq('manga_id', manga.mangaId);
    if (error) throw error;
    return;
  }

  const { error: cacheWriteError } = await supabase
    .from('manga_chapter_cache')
    .upsert({
      manga_id: manga.mangaId,
      manga_title: manga.title,
      cover_url: manga.coverUrl || null,
      latest_chapter_id: chapter.id,
      latest_chapter_title: chapter.title || null,
      checked_at: new Date().toISOString(),
    }, { onConflict: 'manga_id' });
  if (cacheWriteError) throw cacheWriteError;

  stats.updated += 1;
  const userIds = [...manga.userIds];
  const alreadyNotified = await unreadTargets(userIds, manga.mangaId, chapter.id);
  const targets = userIds.filter((userId) => !alreadyNotified.has(userId));
  if (targets.length === 0) return;

  const title = `Chapter baru: ${manga.title}`;
  const body = chapter.title
    ? `${chapter.title} sudah tersedia.`
    : 'Chapter terbaru sudah tersedia.';
  const { error: notificationError } = await supabase
    .from('notifications')
    .insert(targets.map((userId) => ({
      user_id: userId,
      type: 'chapter_update',
      title,
      body,
      manga_id: manga.mangaId,
      chapter_id: chapter.id,
    })));
  if (notificationError) throw notificationError;
  stats.notifications += targets.length;

  const { data: tokenRows, error: tokenError } = await supabase
    .from('device_tokens')
    .select('fcm_token')
    .in('user_id', targets);
  if (tokenError) throw tokenError;

  await sendPush(
    (tokenRows || []).map((row) => row.fcm_token),
    stats,
    {
      title,
      body,
      data: {
        type: 'chapter_update',
        link: deepLink(manga.mangaId, chapter.id),
        manga_id: manga.mangaId,
        chapter_id: chapter.id,
      },
    },
  );
}

let sedangBerjalan = false;

async function checkAll(reason) {
  if (sedangBerjalan) {
    console.log('[chapter-checker] Lewati: pemeriksaan sebelumnya masih berjalan.');
    return null;
  }
  sedangBerjalan = true;
  const startedAt = Date.now();
  const stats = { checked: 0, updated: 0, notifications: 0, pushOk: 0, pushFail: 0, tokenRemoved: 0 };

  try {
    console.log(`[chapter-checker] Mulai pemeriksaan (${reason}).`);
    const { data: rows, error } = await supabase
      .from('bookmarks')
      .select('manga_id, user_id, title, cover_url');
    if (error) throw error;

    const groups = new Map();
    for (const row of rows || []) {
      const mangaId = String(row.manga_id || '');
      const userId = String(row.user_id || '');
      if (!mangaId || !userId) continue;
      const current = groups.get(mangaId) || {
        mangaId,
        title: String(row.title || mangaId),
        coverUrl: String(row.cover_url || ''),
        userIds: new Set(),
      };
      current.userIds.add(userId);
      groups.set(mangaId, current);
    }

    const mangaList = [...groups.values()]
      .map((manga) => ({ ...manga, userIds: [...manga.userIds] }))
      .slice(0, MAX_MANGA_PER_RUN);
    stats.checked = mangaList.length;
    console.log(`[chapter-checker] Manga unik yang akan dicek: ${mangaList.length}.`);

    for (let index = 0; index < mangaList.length; index += 1) {
      const manga = mangaList[index];
      try {
        await processManga(manga, stats);
      } catch (error) {
        console.error(`[chapter-checker] Gagal proses ${manga.mangaId}: ${error.message}`);
      }
      if (index < mangaList.length - 1 && API_DELAY_MS > 0) {
        await sleep(API_DELAY_MS);
      }
    }

    const seconds = ((Date.now() - startedAt) / 1000).toFixed(1);
    console.log(
      `[chapter-checker] Selesai dalam ${seconds}s ` +
      `dicek=${stats.checked} update=${stats.updated} notif=${stats.notifications} ` +
      `push_ok=${stats.pushOk} push_gagal=${stats.pushFail} token_removed=${stats.tokenRemoved}.`,
    );
    return stats;
  } finally {
    sedangBerjalan = false;
  }
}

async function main() {
  if (process.argv.includes('--once')) {
    await checkAll('manual');
    return;
  }

  if (!cron.validate(CRON_SCHEDULE)) {
    throw new Error(`CRON_SCHEDULE tidak valid: ${CRON_SCHEDULE}`);
  }
  cron.schedule(CRON_SCHEDULE, () => {
    checkAll('cron').catch((error) => {
      console.error(`[chapter-checker] Pemeriksaan cron gagal: ${error.message}`);
    });
  }, {
    name: 'chapter-checker',
    timezone: CRON_TIMEZONE,
    noOverlap: true,
  });
  console.log(`[chapter-checker] Jalan. Jadwal: ${CRON_SCHEDULE} (${CRON_TIMEZONE}).`);
}

main().catch((error) => {
  console.error(`[chapter-checker] Fatal: ${error.message}`);
  process.exitCode = 1;
});
