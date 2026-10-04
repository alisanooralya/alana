import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:alana/core/diagnostics/error_log.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

import '../../data/profile_repository.dart';

bool _prosesAvatarBerjalan = false;

const _batasPilih = Duration(seconds: 120);
const _batasCrop = Duration(seconds: 120);

Future<bool> pilihDanUnggahAvatar(BuildContext context, WidgetRef ref) async {
  if (_prosesAvatarBerjalan) return false;
  _prosesAvatarBerjalan = true;
  try {
    return await _pilihDanUnggahAvatarInner(context, ref);
  } finally {
    _prosesAvatarBerjalan = false;
  }
}

Future<bool> _pilihDanUnggahAvatarInner(
  BuildContext context,
  WidgetRef ref,
) async {
  final uid = ref.read(userIdProvider);
  final repoProfil = ref.read(profileRepositoryProvider);

  ImageSource? sumber;
  var tahap = 'memilih foto';

  try {
    var opsiTerkunci = false;
    sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          void pilih(ImageSource nilai) {
            if (opsiTerkunci) return;
            opsiTerkunci = true;
            setSheetState(() {});
            Navigator.of(context).pop(nilai);
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  enabled: !opsiTerkunci,
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pilih dari galeri'),
                  onTap: () => pilih(ImageSource.gallery),
                ),
                ListTile(
                  enabled: !opsiTerkunci,
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Ambil dari kamera'),
                  onTap: () => pilih(ImageSource.camera),
                ),
              ],
            ),
          );
        },
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

    final diambil = await ImagePicker()
        .pickImage(source: sumber, imageQuality: 90)
        .timeout(_batasPilih);
    if (diambil == null || !context.mounted) return false;

    tahap = 'memotong foto';
    final potong = await ImageCropper()
        .cropImage(
          sourcePath: diambil.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 80,
          maxWidth: 512,
          maxHeight: 512,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Potong foto',
              toolbarColor: const Color(0xFF0B0B17),
              toolbarWidgetColor: Colors.white,
              statusBarLight: false,
              navBarLight: false,
              backgroundColor: const Color(0xFF0B0B17),
              activeControlsWidgetColor: Colors.white,
              lockAspectRatio: true,
              hideBottomControls: true,
            ),
          ],
        )
        .timeout(_batasCrop);
    if (potong == null || !context.mounted) return false;

    if (uid == null || uid.isEmpty) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Sesi tidak valid. Masuk ulang.')),
        );
      return false;
    }

    tahap = 'mengunggah foto';
    await repoProfil.unggahAvatar(uid, File(potong.path));
    if (!context.mounted) return false;
    ref.invalidate(profileProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Foto profil diperbarui.')));
    return true;
  } on PlatformException catch (error, stack) {
    return _gagal(context, error, stack, sumber, tahap);
  } catch (error, stack) {
    return _gagal(context, error, stack, sumber, tahap);
  }
}

Future<bool> _gagal(
  BuildContext context,
  Object error,
  StackTrace stack,
  ImageSource? sumber,
  String tahap,
) async {
  ErrorLog.catat(error, stack);
  if (!context.mounted) return false;
  final pesan = switch (error) {
    TimeoutException(:final message?) => message,
    _ when tahap == 'mengunggah foto' => pesanAuthRamah(error),
    _ => _pesanTahap(sumber, tahap),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan)));
  return false;
}

String _pesanTahap(ImageSource? sumber, String tahap) {
  if (tahap == 'memotong foto') {
    return 'Gagal memotong foto. Coba pilih gambar lain.';
  }
  if (sumber == ImageSource.camera) {
    return 'Gagal mengambil foto dari kamera. Coba lagi.';
  }
  return 'Gagal memilih foto dari galeri. Coba lagi.';
}
