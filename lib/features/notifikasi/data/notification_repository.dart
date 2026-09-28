import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

import 'notifikasi.dart';

class NotificationRepository {
  const NotificationRepository();

  SupabaseClient get _client => SupabaseSetup.instance;

  Future<List<Notifikasi>> daftar(String uid) async {
    final baris = await _client
        .from('notifications')
        .select(
          'id, type, title, body, manga_id, chapter_id, '
          'is_read, created_at',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return [
      for (final b in baris)
        Notifikasi.fromMap(Map<String, dynamic>.from(b as Map)),
    ];
  }

  Future<int> hitungBelumDibaca(String uid) async {
    final List<dynamic> baris = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('is_read', false)
        .limit(100);
    return baris.length;
  }

  Future<void> tandaiDibaca(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> tandaiSemuaDibaca(String uid) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return const NotificationRepository();
});
