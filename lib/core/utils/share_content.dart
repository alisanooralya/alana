import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'deep_link.dart';

String mangaShareUrl(String mangaId) => mangaDeepLink(mangaId);

String chapterShareUrl(String mangaId, String chapterId) {
  return chapterDeepLink(mangaId, chapterId);
}

Future<void> shareLink(
  BuildContext context, {
  required String text,
  required String link,
}) async {
  final renderBox = context.findRenderObject() as RenderBox?;
  final origin = renderBox == null
      ? null
      : renderBox.localToGlobal(Offset.zero) & renderBox.size;
  debugPrint('[Share] shareLink started: $link, origin: $origin');
  try {
    debugPrint('[Share] Calling SharePlus.instance.share');
    final result = await SharePlus.instance.share(
      ShareParams(
        text: text,
        uri: Uri.parse(link),
        sharePositionOrigin: origin,
      ),
    );
    debugPrint(
      '[Share] SharePlus.instance.share completed: '
      'status=${result.status}, raw=${result.raw}',
    );
  } catch (error, stack) {
    debugPrint('[Share] SharePlus.instance.share failed: $error\n$stack');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka menu berbagi.')),
      );
  }
}

Future<void> shareManga(BuildContext context, String title, String mangaId) {
  final link = mangaShareUrl(mangaId);
  return shareLink(context, text: 'Baca $title di Alana! $link', link: link);
}

Future<void> shareChapter(
  BuildContext context, {
  required String mangaTitle,
  required String chapterTitle,
  required String mangaId,
  required String chapterId,
}) {
  final chapter = chapterTitle.isEmpty ? chapterId : chapterTitle;
  final link = chapterShareUrl(mangaId, chapterId);
  return shareLink(
    context,
    text: 'Baca $mangaTitle — $chapter di Alana! $link',
    link: link,
  );
}
