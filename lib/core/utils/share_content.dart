import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

const shareBaseUrl = 'https://<domain-nanti>';

String mangaShareUrl(String mangaId) => '$shareBaseUrl/manga/$mangaId';

String chapterShareUrl(String mangaId, String chapterId) {
  return '$shareBaseUrl/manga/$mangaId/chapter/$chapterId';
}

Future<void> shareText(BuildContext context, String text) async {
  final renderBox = context.findRenderObject() as RenderBox?;
  final origin = renderBox == null
      ? null
      : renderBox.localToGlobal(Offset.zero) & renderBox.size;
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka menu berbagi.')),
      );
  }
}

Future<void> shareManga(BuildContext context, String title, String mangaId) {
  return shareText(context, 'Baca $title di Alana! ${mangaShareUrl(mangaId)}');
}

Future<void> shareChapter(
  BuildContext context, {
  required String mangaTitle,
  required String chapterTitle,
  required String mangaId,
  required String chapterId,
}) {
  final chapter = chapterTitle.isEmpty ? chapterId : chapterTitle;
  return shareText(
    context,
    'Baca $mangaTitle — $chapter di Alana! ${chapterShareUrl(mangaId, chapterId)}',
  );
}
