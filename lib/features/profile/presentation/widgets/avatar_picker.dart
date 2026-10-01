import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:alana/core/diagnostics/error_log.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

import '../../data/profile_repository.dart';

/// Alur pilih foto profil langsung: bottom-sheet sumber -> crop 1:1 ->
/// upload ke Supabase Storage -> invalidate [profileProvider].
/// Dipakai tombol "Pasang Foto" di [ProfilePage].
/// Return true bila upload berhasil.
Future<bool> pilihDanUnggahAvatar(
  BuildContext context,
  WidgetRef ref,
) async {
  final sumber = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil dari kamera'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (sumber == null || !context.mounted) return false;

  if (sumber == ImageSource.camera) {
    final izin = await Permission.camera.request();
    if (!izin.isGranted) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Izin kamera diperlukan untuk foto profil.'),
          ),
        );
      return false;
    }
  }

  final diambil = await ImagePicker().pickImage(
    source: sumber,
    imageQuality: 90,
  );
  if (diambil == null || !context.mounted) return false;

  final potong = await ImageCropper().cropImage(
    sourcePath: diambil.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 80,
    maxWidth: 512,
    maxHeight: 512,
    uiSettings: [
      AndroidUiSettings(toolbarTitle: 'Potong foto', lockAspectRatio: true),
    ],
  );
  if (potong == null || !context.mounted) return false;

  final uid = ref.read(userIdProvider);
  if (uid == null || uid.isEmpty) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Sesi tidak valid. Masuk ulang.')),
      );
    return false;
  }

  try {
    await ref
        .read(profileRepositoryProvider)
        .unggahAvatar(uid, File(potong.path));
    ref.invalidate(profileProvider);
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Foto profil diperbarui.')),
      );
    return true;
  } catch (error, stack) {
    ErrorLog.catat(error, stack);
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesanAuthRamah(error))));
    return false;
  }
}
