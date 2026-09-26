import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

import '../data/chapter_report_repository.dart';

enum ReportSheetResult { submitted, alreadyReported }

class ChapterReportSheet extends ConsumerStatefulWidget {
  const ChapterReportSheet({super.key, required this.chapterId});

  final String chapterId;

  @override
  ConsumerState<ChapterReportSheet> createState() => _ChapterReportSheetState();
}

class _ChapterReportSheetState extends ConsumerState<ChapterReportSheet> {
  final _noteController = TextEditingController();
  ChapterReportReason? _reason;
  bool _memuat = false;
  String? _error;
  String? _errorMentah;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Pilih alasan laporan.');
      return;
    }
    final note = _noteController.text.trim();
    if (reason == ChapterReportReason.lainnya && note.isEmpty) {
      setState(() => _error = 'Tuliskan keterangan masalah.');
      return;
    }

    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      setState(() => _error = 'Sesi login tidak tersedia.');
      return;
    }

    setState(() {
      _memuat = true;
      _error = null;
      _errorMentah = null;
    });

    try {
      final repository = ref.read(reportRepositoryProvider);
      final pending = await repository.sudahAdaPending(
        userId: userId,
        chapterId: widget.chapterId,
      );
      if (pending) {
        if (mounted) {
          Navigator.of(context).pop(ReportSheetResult.alreadyReported);
        }
        return;
      }

      await repository.kirim(
        userId: userId,
        chapterId: widget.chapterId,
        reason: reason,
        note: note,
      );
      if (mounted) {
        Navigator.of(context).pop(ReportSheetResult.submitted);
      }
    } on ReportAlreadyExistsException {
      if (mounted) {
        Navigator.of(context).pop(ReportSheetResult.alreadyReported);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _memuat = false;
          _error = pesanErrorRamah(error);
          // TODO sementara: tampilkan pesan asli Supabase apa adanya.
          _errorMentah = error.toString();
          if (error is PostgrestException) {
            _errorMentah =
                '${error.toString()}\n'
                'code: ${error.code}\n'
                'message: ${error.message}\n'
                'details: ${error.details}';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Laporkan Masalah',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text('Bantu kami memperbaiki chapter ini.'),
            const SizedBox(height: 18),
            Text('Alasan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final reason in ChapterReportReason.values)
                  ChoiceChip(
                    label: Text(reason.label),
                    selected: _reason == reason,
                    onSelected: _memuat
                        ? null
                        : (_) => setState(() {
                            _reason = reason;
                            _error = null;
                            _errorMentah = null;
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              enabled: !_memuat,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan opsional',
                hintText: _reason == ChapterReportReason.lainnya
                    ? 'Jelaskan masalahnya'
                    : 'Tambahkan konteks jika diperlukan',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() {
                    _error = null;
                    _errorMentah = null;
                  });
                }
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            // TODO sementara: hapus blok ini setelah akar masalah diperbaiki.
            if (_errorMentah != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMentah!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _memuat ? null : () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _memuat ? null : _kirim,
                  icon: _memuat
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Kirim'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
