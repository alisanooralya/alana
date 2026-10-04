# Alana — Temukan Ceritamu.

Aplikasi Android untuk membaca manhwa (webtoon-style) dengan Flutter.
Wajib login (Supabase Auth): email+password dan Google Sign-In.

## Menjalankan

Kredensial **tidak di-hardcode**. Isi lewat `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xyzcompany.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=isi-dengan-anon-atau-publishable-key \
  --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
```

| Define | Wajib | Keterangan |
|---|---|---|
| `SUPABASE_URL` | Ya | URL project, dari dashboard Supabase → Project Settings → API |
| `SUPABASE_ANON_KEY` | Ya | Anon/publishable key (boleh dilihat publik, terkendali RLS) |
| `GOOGLE_WEB_CLIENT_ID` | Bila pakai Google | Web Client ID dari Google Cloud Console (OAuth 2.0) |

Tanpa `SUPABASE_URL`/`SUPABASE_ANON_KEY`, halaman login menampilkan
pesan konfigurasi dan tombol dinonaktifkan.

## CI (GitHub Actions)

Workflow `Build APK` membaca nilai yang sama dari Secrets repo:

- Buka repo → Settings → Secrets and variables → Actions → New repository secret:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `GOOGLE_WEB_CLIENT_ID` (opsional, tombol Google nonaktif bila kosong)

Build release meneruskannya sebagai `--dart-define`. Nilai tidak pernah
di-commit ke repo.

## Google Sign-In (Android)

1. Google Cloud Console → Credentials → buat OAuth client **Web**
   (catat Client ID → `GOOGLE_WEB_CLIENT_ID`) dan **Android**
   (isi package `com.alana` + SHA-1 keystore debug dan release).
2. Dashboard Supabase → Authentication → Sign In/Providers → aktifkan
   **Google**, isi Client ID dan Client Secret (dari client Web).
3. SHA-1 debug lokal: `keytool -list -v -keystore ~/.android/debug.keystore`
   (password `android`). SHA-1 release mengikuti keystore penandatangan APK.

## Signing release (agar SHA-1 tetap)

APK CI default memakai debug keys (SHA-1 acak tiap run) — Google Sign-In
tidak akan stabil. Buat satu keystore release sekali saja:

```bash
# Di laptop:
keytool -genkeypair -v -keystore alana-release.jks -alias alana \
  -keyalg RSA -keysize 2048 -validity 10000
# Windows PowerShell (base64 satu baris):
certutil -encode alana-release.jks alana-release.b64
# Linux/macOS:
base64 -w0 alana-release.jks   # macOS: base64 -i alana-release.jks | tr -d '\n'
```

Simpan sebagai Secrets repo: `KEYSTORE_BASE64` (isi file b64),
`KEYSTORE_PASSWORD`, `KEY_ALIAS` (`alana`), `KEY_PASSWORD`.
Workflow otomatis memakai keystore ini bila Secrets ada, dan fallback
ke debug keys bila tidak. SHA-1-nya (`keytool -list -v -keystore
alana-release.jks`) daftarkan di OAuth client Android — cukup sekali,
berlaku untuk semua build berikutnya. **Jangan commit file .jks.**

## Alur auth

- Belum login → otomatis ke `/masuk`; tab lain terkunci.
- Masuk bisa pakai **email atau username** (satu field; ada `@` = email,
  selain itu lewat Edge Function `login-with-username` yang anti-enumerasi).
- Daftar (`/daftar`): username (unik, `a-z0-9_`, 3–20) + email + password (min 8).
  Bila konfirmasi email aktif di Supabase, user diarahkan ke
  `/verifikasi-email` setelah daftar.
- Lupa password (`/lupa-password`): kirim tautan reset via email.
- Sesi tersimpan otomatis — tetap login setelah aplikasi ditutup.

## Firebase Cloud Messaging (tanpa flutterfire_cli)

- `android/app/google-services.json` sudah ada di repo; plugin
  `com.google.gms.google-services` dipasang manual di gradle.
  `Firebase.initializeApp()` tanpa opsi (baca file itu langsung) —
  tanpa `firebase_options.dart`, tanpa menjalankan flutterfire.
- Token perangkat disimpan ke tabel `device_tokens` saat login/app-start
  (diperbarui saat refresh, dihapus saat logout/toggle mati).
- Toggle: Profil → Pengaturan → "Notifikasi chapter baru".
- Verifikasi token: Dashboard → Table Editor → `device_tokens`,
  cari baris `user_id`-mu (kolom `fcm_token` + `updated_at`).
- Tes manual: Edge Functions → `check-new-chapters` → Invoke (POST `{}`),
  atau curl dengan service role key:
  ```bash
  curl -X POST https://<ref>.supabase.co/functions/v1/check-new-chapters \
    -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
    -H "Content-Type: application/json" -d '{}'
  ```
  Respons ringkasan `{checked, updated, notifikasi, push_terkirim, ...}`;
  log detail di Edge Functions → Logs.

## Edge Functions

Deploy lewat workflow **Deploy Edge Functions** (manual atau otomatis saat
`supabase/functions/**` berubah). Secrets: `SUPABASE_ACCESS_TOKEN`,
`SUPABASE_PROJECT_REF`. SQL mentah ada di `supabase/sql/` (jalankan manual
di SQL Editor).

| Fungsi | Akses | Tugas |
|---|---|---|
| `rate-limit-login` | publik (`--no-verify-jwt`) | Rate limit login email+password: 5x gagal/15 mnt per email, 30x per IP |
| `delete-account` | JWT (verify default) | Hapus akun + avatar milik pemanggil |
| `login-with-username` | publik (`--no-verify-jwt`, `config.toml`) | Login username → token (anti-enumerasi, rate limit IP+username) |

## Halaman legal dan share (GitHub Pages)

Semua dokumen statis ada di `docs/`, dilayani GitHub Pages oleh workflow
**Deploy Halaman Legal**. Aktifkan sekali di repo → **Settings → Pages →
Source → `GitHub Actions`**. Workflow hanya jalan saat `docs/**` berubah, jadi
tidak memicu build APK (`build-apk.yml` punya `paths-ignore: docs/**`).

| URL | Isi |
|---|---|
| `https://alisanooralya.github.io/alana/` | Beranda |
| `https://alisanooralya.github.io/alana/privacy/` | Kebijakan privasi |
| `https://alisanooralya.github.io/alana/delete-account/` | Cara hapus akun |
| `https://alisanooralya.github.io/alana/manga/?id=<mangaId>` | Halaman share manga |

`_tautanPrivasi` dan `_tautanHapusAkun` di `about_page.dart` diisi dua URL
legal di atas. Play Console mewajibkannya. `_tautanPengembang` diisi alamat
email polos **tanpa** `mailto:`.

### Share manga

`lib/core/utils/share_content.dart` memakai URL `https`, bukan deep link
`alana://`. Alasannya `alana://` hanya bisa dibuka aplikasi Alana sendiri,
jadi begitu dikirim ke WhatsApp atau Telegram isinya jadi teks mati.

Bentuk URL-nya query string, bukan path bersih. GitHub Pages menyajikan path
tanpa ekstensi lewat `404.html` dengan status 404, sementara crawler preview
WhatsApp, Telegram, dan X hanya merender preview untuk status 200. Path bersih
`/manga/<id>` tetap bisa dibuka karena `404.html` memuat renderer yang sama,
tapi statusnya 404 sehingga preview-nya tidak muncul.

Metadata diambil dari `api.shngm.io` langsung di browser; API tersebut mengirim
`Access-Control-Allow-Origin: *` jadi tidak butuh backend. Semua teks dari API
ditulis lewat `textContent`, bukan `innerHTML`.

**Batas yang diketahui:** halaman statis tidak bisa menyertakan judul dan
sampul per-manga di tag Open Graph, karena crawler preview tidak menjalankan
JavaScript. Preview akan menampilkan judul situs generik, bukan judul manga.
Menghilangkannya butuh App Links, yaitu `assetlinks.json` plus intent filter
`autoVerify` di `AndroidManifest.xml` — belum dikonfigurasi di repo ini.
