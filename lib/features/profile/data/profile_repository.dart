import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

import 'profile.dart';

class ProfileRepository {
  const ProfileRepository();

  SupabaseClient get _client => SupabaseSetup.instance;

  Future<Profile?> ambil(String uid) async {
    final baris = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .eq('id', uid)
        .maybeSingle();
    if (baris == null) return null;
    return Profile.fromMap(Map<String, dynamic>.from(baris));
  }

  Future<bool?> usernameDipakai(String username, {String? kecualiUid}) async {
    try {
      final hasil = await _client.rpc(
        'username_taken',
        params: {
          'p_username': username,
          'p_kecuali': (kecualiUid == null || kecualiUid.isEmpty)
              ? null
              : kecualiUid,
        },
      );
      return hasil == true;
    } catch (_) {
      return null;
    }
  }

  Future<void> ubah(String uid, {String? displayName, String? username}) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName.trim();
    if (username != null) data['username'] = username.trim();
    if (data.isEmpty) return;
    await _client.from('profiles').update(data).eq('id', uid);
  }

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
