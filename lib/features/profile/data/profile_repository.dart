import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

import 'profile.dart';

/// Repository profil: baca/ubah tabel `profiles` + upload avatar.
///
/// Avatar disimpan di bucket `avatars` path `{uid}/avatar.jpg`
/// (upsert), lalu URL berversi (`?v=timestamp`) disimpan ke
/// `profiles.avatar_url` agar cache tidak menampilkan foto lama.
class ProfileRepository {
  const ProfileRepository();

  SupabaseClient get _client => SupabaseSetup.instance;

  /// Mengambil profil sekali.
  Future<Profile?> ambil(String uid) async {
    final baris = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .eq('id', uid)
        .maybeSingle();
    if (baris == null) return null;
    return Profile.fromMap(Map<String, dynamic>.from(baris));
  }

  /// Mengecek username dipakai user lain (di luar [kecualiUid]).
  ///
  /// Memanggil fungsi `username_taken` yang hanya mengembalikan boolean.
  /// Select langsung ke `profiles` selalu gagal untuk pengguna baru karena
  /// policy select hanya berlaku bagi yang sudah login, jadi pengecekan tidak
  /// pernah memberi jawaban. null = tidak bisa dicek; pemanggil tetap
  /// lanjutkan dan andalkan error unik dari database.
  Future<bool?> usernameDipakai(String username, {String? kecualiUid}) async {
    try {
      final hasil = await _client.rpc('username_taken', {
        'p_username': username,
        'p_kecuali': (kecualiUid == null || kecualiUid.isEmpty)
            ? null
            : kecualiUid,
      });
      return hasil == true;
    } catch (_) {
      return null;
    }
  }

  /// Mengubah display_name dan/atau username milik [uid].
  Future<void> ubah(String uid, {String? displayName, String? username}) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName.trim();
    if (username != null) data['username'] = username.trim();
    if (data.isEmpty) return;
    await _client.from('profiles').update(data).eq('id', uid);
  }

  /// Upload foto avatar (upsert) + simpan URL berversi ke profil.
  /// Mengembalikan URL final yang disimpan.
  Future<String> unggahAvatar(String uid, File file) async {
    final path = '$uid/avatar.jpg';
    await _client.storage
        .from('avatars')
        .upload(
          path,
          file,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    final berversi = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client
        .from('profiles')
        .update({'avatar_url': berversi})
        .eq('id', uid);
    return berversi;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return const ProfileRepository();
});
