/* Halaman share Alana.
 *
 * Halaman statis: metadata diambil dari api.shngm.io langsung dari browser.
 * API tersebut mengirim Access-Control-Allow-Origin: *, jadi tidak butuh
 * backend. Semua teks dari API ditulis lewat textContent, tidak pernah
 * innerHTML, supaya string dari server tidak bisa disuntik sebagai HTML.
 *
 * Satu file ini dipakai dua kali: oleh /manga/ (status 200,|link yang
 * dipublikasikan app) dan oleh /404.html (menangkap URL bersih /manga/<uuid>).
 * Keduanya membaca id dari query string atau dari path.
 */

const API = 'https://api.shngm.io';
const DALAM_APP = 'alana://manga/';

const el = {
  memuat: document.getElementById('memuat'),
  galat: document.getElementById('galat'),
  kartu: document.getElementById('kartu'),
  cover: document.getElementById('cover'),
  judul: document.getElementById('judul'),
  sub: document.getElementById('sub'),
  sinopsis: document.getElementById('sinopsis'),
  tombol: document.getElementById('tombol'),
  tombolLabel: document.getElementById('tombol-label'),
};

/* Terima dua bentuk URL:
 *   /alana/manga/?id=<uuid>&chapter=<uuid>   -> status 200, dipakai share
 *   /alana/manga/<uuid>/chapter/<uuid>       -> ditangkap lewat 404.html
 */
function bacaId() {
  const q = new URLSearchParams(location.search);
  let mangaId = q.get('id');
  let chapterId = q.get('chapter');
  if (mangaId) return { mangaId, chapterId };

  const cocok = location.pathname.match(
    /\/manga\/([0-9a-f-]{36})(?:\/chapter\/([0-9a-f-]{36}))?/i,
  );
  if (cocok) return { mangaId: cocok[1], chapterId: cocok[2] || null };
  return { mangaId: null, chapterId: null };
}

async function ambil(path) {
  const respons = await fetch(API + path, {
    headers: { Accept: 'application/json' },
  });
  if (!respons.ok) throw new Error('HTTP ' + respons.status);
  const body = await respons.json();
  if (body.retcode !== 0 || !body.data) throw new Error('retcode ' + body.retcode);
  return body.data;
}

/* Singkatnya "Ongoing"/"Finished" sudah ditentukan API lewat angka; yang
 * bisa ditampilkan apa adanya adalah judul, tahun, dan jumlah chapter. */
function baris(meta) {
  return meta.filter(Boolean).join(' · ');
}

const BULAN = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/* API mengirim release_date sebagai timestamp ISO mentah
 * ("2026-09-25T03:02:50Z"). Menampilkannya apa adanya terlihat seperti
 * log server, jadi diubah ke "25 September 2026". */
function tanggal(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.getDate() + ' ' + BULAN[d.getMonth()] + ' ' + d.getFullYear();
}

function setTeks(node, nilai) {
  node.textContent = nilai == null || nilai === '' ? '-' : String(nilai);
}

function tampilkan() {
  el.memuat.hidden = true;
  el.kartu.hidden = false;
}

function gagal(pesan) {
  el.memuat.hidden = true;
  el.galat.hidden = false;
  el.galat.textContent = pesan;
}

async function muat() {
  const { mangaId, chapterId } = bacaId();
  if (!mangaId) {
    gagal('Tautan tidak lengkap: id manga tidak ditemukan di alamat.');
    return;
  }

  let manga;
  let chapter = null;
  try {
    manga = await ambil('/v1/manga/detail/' + encodeURIComponent(mangaId));
    if (chapterId) {
      // Chapter tidak boleh menggagalkan seluruh halaman: tetap tampilkan
      // manga walau satu endpoint bermasalah.
      chapter = await ambil(
        '/v1/chapter/detail/' + encodeURIComponent(chapterId),
      ).catch(() => null);
    }
  } catch (err) {
    gagal('Data manga tidak bisa dimuat dari sumber. Coba lagi sebentar lagi.');
    return;
  }

  document.title = manga.title + ' — Alana';
  setTeks(el.judul, manga.title);
  setTeks(el.sub, baris([manga.alternative_title, manga.release_year]));

  if (manga.cover_image_url) {
    el.cover.src = manga.cover_image_url;
    el.cover.alt = 'Sampul ' + manga.title;
  } else {
    el.cover.hidden = true;
  }

  const sinopsis = (manga.description || '').trim();
  if (sinopsis) {
    setTeks(el.sinopsis, sinopsis);
  } else {
    el.sinopsis.hidden = true;
  }

  // Tombol tujuan: ke chapter tertentu kalau ada, ke detail manga kalau tidak.
  const dasar = DALAM_APP + encodeURIComponent(mangaId);
  const tujuan =
    chapterId && chapter
      ? dasar + '/chapter/' + encodeURIComponent(chapterId)
      : dasar;
  el.tombol.href = tujuan;
  el.tombolLabel.textContent =
    chapterId && chapter ? 'Buka chapter di Alana' : 'Buka di Alana';

  // Ringkasan chapter, hanya kalau chapter yang dibagikan ada.
  // chapter_title sering kosong dari API, jadi tanggal jadi cadangan.
  if (chapter) {
    document.getElementById('nota-chapter').hidden = false;
    setTeks(document.getElementById('chapter-nomor'), chapter.chapter_number);
    const ringkas = baris([
      chapter.chapter_title,
      tanggal(chapter.release_date),
    ]);
    const node = document.getElementById('chapter-ringkas');
    node.textContent = ringkas;
    node.hidden = ringkas === '';
  }


  tampilkan();
}

muat();