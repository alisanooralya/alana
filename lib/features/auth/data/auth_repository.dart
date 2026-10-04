import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/config/app_config.dart';
import 'package:alana/core/diagnostics/error_log.dart';
import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/core/utils/deep_link.dart';

import 'auth_validators.dart';

class AuthRepository {
  AuthRepository();

  SupabaseClient get _client => SupabaseSetup.instance;

  Stream<AuthState> get perubahanSesi {
    _siaran ??= _client.auth.onAuthStateChange.asBroadcastStream();
    return _siaran!;
  }

  Stream<AuthState>? _siaran;
  bool _googleSiap = false;

  Session? get sesiAktif => _client.auth.currentSession;
  User? get userAktif => _client.auth.currentUser;

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

  Future<AuthResponse> masuk({
    required String email,
    required String password,
  }) async {
    final alamat = email.trim();
    await _cekBatasLogin(alamat);
    try {
      final hasil = await _client.auth.signInWithPassword(
        email: alamat,
        password: password,
      );
      await _catatPercobaanLogin(alamat, berhasil: true);
      return hasil;
    } catch (error) {
      if (_penolakanKredensial(error)) {
        await _catatPercobaanLogin(alamat, berhasil: false);
      }
      rethrow;
    }
  }

  Future<void> _cekBatasLogin(String email) async {
    try {
      await _client.functions.invoke(
        'rate-limit-login',
        body: {'action': 'check', 'email': email},
      );
    } on FunctionsHttpException catch (error) {
      if (error.status != 429) {
        ErrorLog.catat(error, StackTrace.current);
        return;
      }
      throw PercobaanLoginDibatasi(_detikTungguDari(error.details));
    } catch (error, stack) {
      ErrorLog.catat(error, stack);
    }
  }

  Future<void> _catatPercobaanLogin(
    String email, {
    required bool berhasil,
  }) async {
    try {
      await _client.functions.invoke(
        'rate-limit-login',
        body: {'action': 'record', 'email': email, 'success': berhasil},
      );
    } catch (error, stack) {
      ErrorLog.catat(error, stack);
    }
  }

  int _detikTungguDari(Object? details) {
    if (details is Map) {
      final nilai = details['retry_after_seconds'];
      if (nilai is num) return nilai.toInt();
      if (nilai is String) return int.tryParse(nilai) ?? 0;
    }
    return 0;
  }

  bool _penolakanKredensial(Object error) {
    if (error is! AuthApiException) return false;
    final kode = error.statusCode;
    return kode == '400' || kode == '401';
  }

  Future<AuthResponse> masukDenganUsername({
    required String username,
    required String password,
  }) async {
    final nama = username.trim();
    await _cekBatasLogin(nama);
    try {
      final hasil = await _client.functions.invoke(
        'login-with-username',
        body: {'username': nama, 'password': password},
      );
      final data = hasil.data;
      final segar = data is Map ? data['refresh_token']?.toString() : null;
      if (hasil.status != 200 || segar == null || segar.isEmpty) {
        await _catatPercobaanLogin(nama, berhasil: false);
        throw AuthException(_pesanFunctionLogin(data));
      }
      final sesi = await _client.auth
          .setSession(segar)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const AuthException(
              'Sesi terlalu lama tidak terbantu. Periksa jaringan lalu coba lagi.',
            ),
          );
      await _catatPercobaanLogin(nama, berhasil: true);
      return sesi;
    } catch (error) {
      if (error is AuthException) rethrow;
      final teks = error.toString();
      if (teks.contains('Username atau password salah')) {
        await _catatPercobaanLogin(nama, berhasil: false);
        throw const AuthException('Username atau password salah.');
      }
      throw AuthException(pesanAuthRamah(error));
    }
  }

  Future<AuthResponse> masukDenganGoogle() async {
    if (AppConfig.googleWebClientId.isEmpty) {
      throw const AuthException(
        'GOOGLE_WEB_CLIENT_ID belum diisi (lihat README).',
      );
    }

    final googleSignIn = GoogleSignIn.instance;
    if (!_googleSiap) {
      await googleSignIn.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );
      _googleSiap = true;
    }

    final googleUser = await googleSignIn.authenticate(
      scopeHint: const ['email', 'profile'],
    );

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

  Future<void> verifikasiPassword(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> gantiPassword(String passwordBaru) async {
    await _client.auth.updateUser(UserAttributes(password: passwordBaru));
  }

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

  Future<void> kirimResetPassword(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: resetPasswordLink(),
    );
  }

  Future<bool?> usernameDipakai(String username) async {
    try {
      final hasil = await _client.rpc(
        'username_taken',
        params: {'p_username': username},
      );
      return hasil == true;
    } catch (_) {
      return null;
    }
  }
}

String _pesanFunction(dynamic data) {
  if (data is Map && data['error'] != null) {
    return data['error'].toString();
  }
  if (data is String && data.isNotEmpty) return data;
  return 'Gagal menghapus akun. Coba lagi.';
}

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
