import 'package:supabase_flutter/supabase_flutter.dart';

/// Aturan username: huruf kecil, angka, underscore, 3–20 karakter.
final usernameRegExp = RegExp(r'^[a-z0-9_]{3,20}$');

/// Validasi username. Mengembalikan pesan error atau null bila valid.
String? validasiUsername(String value) {
  final teks = value.trim();
  if (teks.isEmpty) return 'Username wajib diisi.';
  if (!usernameRegExp.hasMatch(teks)) {
    return '3–20 karakter: huruf kecil, angka, underscore.';
  }
  return null;
}

/// Validasi email sederhana. Mengembalikan pesan error atau null.
String? validasiEmail(String value) {
  final teks = value.trim();
  if (teks.isEmpty) return 'Email wajib diisi.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(teks)) {
    return 'Format email tidak valid.';
  }
  return null;
}

/// Validasi password (minimal 8 karakter).
String? validasiPassword(String value) {
  if (value.isEmpty) return 'Password wajib diisi.';
  if (value.length < 8) return 'Password minimal 8 karakter.';
  return null;
}

/// Menerjemahkan error Supabase/auth umum ke Bahasa Indonesia.
String pesanAuthRamah(Object error) {
  if (error is AuthException) {
    return _dariPesan(error.message);
  }
  if (error is AuthApiException) {
    return _dariPesan(error.message);
  }
  return _dariPesan(error.toString());
}

String _dariPesan(String pesan) {
  final t = pesan.toLowerCase();
  if (t.contains('invalid login credentials')) {
    return 'Email atau password salah.';
  }
  if (t.contains('user already registered') ||
      t.contains('already been registered') ||
      t.contains('email address has already')) {
    return 'Email sudah terdaftar. Silakan masuk.';
  }
  if (t.contains('password should be at least')) {
    return 'Password minimal 8 karakter.';
  }
  if (t.contains('invalid email') ||
      (t.contains('email address') && t.contains('invalid'))) {
    return 'Format email tidak valid.';
  }
  if (t.contains('email not confirmed')) {
    return 'Email belum diverifikasi. Cek kotak masuk kamu.';
  }
  if (t.contains('duplicate') || t.contains('already exists')) {
    if (t.contains('username')) return 'Username sudah dipakai.';
    return 'Data sudah terdaftar.';
  }
  if (t.contains('user not found')) {
    return 'Akun tidak ditemukan. Periksa email kamu.';
  }
  if (t.contains('too many requests') || t.contains('rate limit')) {
    return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
  }
  if (t.contains('network') ||
      t.contains('socketexception') ||
      t.contains('failed host') ||
      t.contains('connection')) {
    return 'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.';
  }
  if (t.contains('cancelled') || t.contains('canceled')) {
    return 'Login dibatalkan.';
  }
  return 'Terjadi kesalahan. Coba lagi.';
}
