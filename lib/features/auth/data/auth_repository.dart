import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/config/app_config.dart';
import 'package:alana/core/supabase/supabase_setup.dart';

import 'auth_validators.dart';

/// Repository autentikasi via Supabase.
///
/// - Email+password: [daftar], [masuk], [kirimResetPassword], [keluar].
/// - Google native: [masukDenganGoogle] (idToken → signInWithIdToken).
/// Sesi disimpan otomatis oleh supabase_flutter.
class AuthRepository {
  AuthRepository();

  SupabaseClient get _client => SupabaseSetup.instance;

  /// Stream perubahan sesi. Dipakai router untuk redirect otomatis.
  ///
  /// Dibagikan sebagai broadcast agar bisa didengar router dan
  /// provider sesi sekaligus.
  Stream<AuthState> get perubahanSesi {
    _siaran ??= _client.auth.onAuthStateChange.asBroadcastStream();
    return _siaran!;
  }

  Stream<AuthState>? _siaran;
  bool _googleSiap = false;

  /// Sesi aktif saat ini (null bila belum login).
  Session? get sesiAktif => _client.auth.currentSession;

  /// User aktif saat ini (null bila belum login).
  User? get userAktif => _client.auth.currentUser;

  /// Mendaftar dengan username + email + password.
  ///
  /// Username dikirim sebagai metadata agar trigger profil bisa
  /// membacanya. Bila konfirmasi email aktif, tidak ada sesi yang
  /// dikembalikan (pemanggil menampilkan layar verifikasi).
  Future<AuthResponse> daftar({
    required String username,
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'username': username.trim()},
    );
  }

  /// Masuk dengan email + password.
  Future<AuthResponse> masuk({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Masuk dengan username via Edge Function `login-with-username`.
  ///
  /// Function mengembalikan token; sesi disimpan lewat `setSession`
  /// sehingga stream `onAuthStateChange` terpicu seperti login biasa.
  /// Akun Google-only gagal dengan pesan umum yang sama.
  Future<AuthResponse> masukDenganUsername({
    required String username,
    required String password,
  }) async {
    try {
      final hasil = await _client.functions.invoke(
        'login-with-username',
        body: {'username': username.trim(), 'password': password},
      );
      final data = hasil.data;
      final segar = data is Map ? data['refresh_token']?.toString() : null;
      if (hasil.status != 200 || segar == null || segar.isEmpty) {
        throw AuthException(_pesanFunctionLogin(data));
      }
      return await _client.auth.setSession(segar);
    } catch (error) {
      if (error is AuthException) rethrow;
      final teks = error.toString();
      if (teks.contains('Username atau password salah')) {
        throw const AuthException('Username atau password salah.');
      }
      throw AuthException(pesanAuthRamah(error));
    }
  }

  /// Masuk dengan akun Google (native, tanpa browser).
  ///
  /// Butuh `GOOGLE_WEB_CLIENT_ID` (lihat README).
  Future<AuthResponse> masukDenganGoogle() async {
    if (AppConfig.googleWebClientId.isEmpty) {
      throw const AuthException(
        'GOOGLE_WEB_CLIENT_ID belum diisi (lihat README).',
      );
    }

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: AppConfig.googleWebClientId);
    _googleSiap = true;

    var googleUser = await googleSignIn.attemptLightweightAuthentication();
    googleUser ??= await googleSignIn.authenticate();

    final authorization =
        await googleUser.authorizationClient.authorizationForScopes(const [
          'email',
          'profile',
        ]) ??
        await googleUser.authorizationClient.authorizeScopes(const [
          'email',
          'profile',
        ]);

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Tidak mendapat ID Token dari Google.');
    }

    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }

  /// Keluar (menghapus sesi tersimpan + sesi Google bila ada).
  Future<void> keluar() async {
    if (_googleSiap) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Abaikan: sesi Supabase tetap dihapus di bawah.
      }
      _googleSiap = false;
    }
    await _client.auth.signOut();
  }

  /// `true` bila user punya identity email (bisa ganti password).
  ///
  /// User yang hanya login Google tidak punya identity ini.
  bool get punyaIdentitasEmail {
    final user = userAktif;
    if (user == null) return false;
    final ids = user.identities;
    if (ids != null && ids.any((i) => i.provider == 'email')) {
      return true;
    }
    final providers = user.appMetadata['providers'];
    if (providers is List) return providers.contains('email');
    return false;
  }

  /// Verifikasi password saat ini dengan masuk ulang.
  Future<void> verifikasiPassword(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Mengganti password milik user aktif.
  Future<void> gantiPassword(String passwordBaru) async {
    await _client.auth.updateUser(UserAttributes(password: passwordBaru));
  }

  /// Menghapus akun milik pemanggil via Edge Function.
  ///
  /// Function memvalidasi JWT, menghapus avatar + user auth
  /// (data ikut cascade). Melempar dengan pesan jelas bila gagal.
  Future<void> hapusAkun() async {
    final hasil = await _client.functions.invoke('delete-account');
    if (hasil.status != 200) {
      final pesan = _pesanFunction(hasil.data);
      throw AuthException(pesan);
    }
    final data = hasil.data;
    if (data is Map && data['success'] != true) {
      throw AuthException(_pesanFunction(data));
    }
  }

  /// Mengirim email reset password.
  Future<void> kirimResetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Mengecek apakah username sudah dipakai di tabel `profiles`.
  ///
  /// Mengembalikan true bila sudah dipakai, false bila tersedia,
  /// null bila tidak bisa dicek (mis. RLS) — pemanggil tetap lanjut
  /// dan mengandalkan error unik saat daftar.
  Future<bool?> usernameDipakai(String username) async {
    try {
      final baris = await _client
          .from('profiles')
          .select('username')
          .eq('username', username.trim())
          .maybeSingle();
      return baris != null;
    } catch (_) {
      return null;
    }
  }
}

/// Ambil pesan error dari respons Edge Function.
String _pesanFunction(dynamic data) {
  if (data is Map && data['error'] != null) {
    return data['error'].toString();
  }
  if (data is String && data.isNotEmpty) return data;
  return 'Gagal menghapus akun. Coba lagi.';
}

/// Pesan login-username: hanya pesan generik yang lolos, sisanya umum.
String _pesanFunctionLogin(dynamic data) {
  if (data is Map &&
      data['error']?.toString().contains('Username atau password salah') ==
          true) {
    return 'Username atau password salah.';
  }
  return 'Gagal masuk. Coba lagi.';
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
