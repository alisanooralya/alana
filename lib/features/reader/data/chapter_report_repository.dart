import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

enum ChapterReportReason {
  gambarRusak,
  gambarTidakLengkap,
  urutanHalaman,
  lainnya,
}

extension ChapterReportReasonValue on ChapterReportReason {
  String get label => switch (this) {
    ChapterReportReason.gambarRusak => 'Gambar rusak',
    ChapterReportReason.gambarTidakLengkap => 'Gambar tidak lengkap',
    ChapterReportReason.urutanHalaman => 'Urutan halaman salah',
    ChapterReportReason.lainnya => 'Lainnya',
  };

  String get value => switch (this) {
    ChapterReportReason.gambarRusak => 'gambar_rusak',
    ChapterReportReason.gambarTidakLengkap => 'gambar_tidak_lengkap',
    ChapterReportReason.urutanHalaman => 'urutan_halaman_salah',
    ChapterReportReason.lainnya => 'lainnya',
  };
}

class ReportAlreadyExistsException implements Exception {
  const ReportAlreadyExistsException();
}

class ReportRepository {
  const ReportRepository();

  Future<bool> sudahAdaPending({
    required String userId,
    required String chapterId,
  }) async {
    final response = await SupabaseSetup.instance
        .from('chapter_reports')
        .select('id')
        .eq('user_id', userId)
        .eq('chapter_id', chapterId)
        .eq('status', 'pending')
        .limit(1);
    if (response.error != null) throw response.error!;
    return response.data is List && response.data!.isNotEmpty;
  }

  Future<void> kirim({
    required String userId,
    required String chapterId,
    required ChapterReportReason reason,
    String? note,
  }) async {
    final response = await SupabaseSetup.instance
        .from('chapter_reports')
        .insert({
          'user_id': userId,
          'chapter_id': chapterId,
          'reason': reason.value,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
        })
        .select('id');
    final error = response.error;
    if (error == null) return;
    if (error.code == '23505' ||
        error.message.toLowerCase().contains('duplicate')) {
      throw const ReportAlreadyExistsException();
    }
    throw error;
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return const ReportRepository();
});
