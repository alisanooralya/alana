import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:hive/hive.dart';

import 'package:alana/core/storage/app_storage.dart';

typedef Dimensi = ({int w, int h});

const Set<int> _sofJpeg = {
  0xC0,
  0xC1,
  0xC2,
  0xC3,
  0xC5,
  0xC6,
  0xC7,
  0xC9,
  0xCA,
  0xCB,
  0xCD,
  0xCE,
  0xCF,
};

Dimensi? parseJpeg(Uint8List b) {
  if (b.length < 4) return null;
  if (b[0] != 0xFF || b[1] != 0xD8) return null;

  var i = 2;
  while (i + 1 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final m = b[i + 1];
    if (m == 0xFF) {
      i++;
      continue;
    }
    if (m == 0xD8 || m == 0xD9 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) {
      i += 2;
      continue;
    }
    if (m == 0xDA) return null;
    if (i + 4 > b.length) return null;

    final panjang = (b[i + 2] << 8) | b[i + 3];
    if (panjang < 2) return null;

    if (_sofJpeg.contains(m)) {
      if (i + 9 > b.length) return null;
      final h = (b[i + 5] << 8) | b[i + 6];
      final w = (b[i + 7] << 8) | b[i + 8];
      if (w <= 0 || h <= 0) return null;
      return (w: w, h: h);
    }
    i += 2 + panjang;
  }
  return null;
}

Dimensi? parsePng(Uint8List b) {
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length < 24) return null;
  for (var i = 0; i < sig.length; i++) {
    if (b[i] != sig[i]) return null;
  }
  if (b[12] != 0x49 || b[13] != 0x48 || b[14] != 0x44 || b[15] != 0x52) {
    return null;
  }
  final view = ByteData.sublistView(b);
  final w = view.getUint32(16);
  final h = view.getUint32(20);
  if (w <= 0 || h <= 0) return null;
  return (w: w, h: h);
}

Dimensi? parseWebp(Uint8List b) {
  if (b.length < 20) return null;
  if (b[0] != 0x52 || b[1] != 0x49 || b[2] != 0x46 || b[3] != 0x46) return null;
  if (b[8] != 0x57 || b[9] != 0x45 || b[10] != 0x42 || b[11] != 0x50) {
    return null;
  }
  final tag = String.fromCharCodes(b.sublist(12, 16));

  if (tag == 'VP8X') {
    if (b.length < 26) return null;
    final w = 1 + (b[20] | (b[21] << 8) | (b[22] << 16));
    final h = 1 + (b[23] | (b[24] << 8) | (b[25] << 16));
    if (w <= 0 || h <= 0) return null;
    return (w: w, h: h);
  }

  if (tag == 'VP8 ') {
    if (b.length < 26) return null;
    if (b[19] != 0x9D || b[20] != 0x01 || b[21] != 0x2A) return null;
    final w = b[22] | ((b[23] & 0x3F) << 8);
    final h = b[24] | ((b[25] & 0x3F) << 8);
    if (w <= 0 || h <= 0) return null;
    return (w: w, h: h);
  }

  if (tag == 'VP8L') {
    if (b.length < 21) return null;
    if (b[16] != 0x2F) return null;
    final bits = b[17] | (b[18] << 8) | (b[19] << 16) | (b[20] << 24);
    final w = (bits & 0x3FFF) + 1;
    final h = ((bits >> 14) & 0x3FFF) + 1;
    if (w <= 0 || h <= 0) return null;
    return (w: w, h: h);
  }

  return null;
}

Dimensi? parseHeaderGambar(Uint8List b) {
  if (b.isEmpty) return null;
  return parseJpeg(b) ?? parsePng(b) ?? parseWebp(b);
}

Future<Dimensi?> bacaDimensiFileLokal(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final w = descriptor.width;
    final h = descriptor.height;
    if (w <= 0 || h <= 0) return null;
    return (w: w, h: h);
  } catch (_) {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

const double rasioKonstantaAwal = 0.1;

double pilihRasio({
  required int index,
  required List<double?> rasionya,
  double konstanta = rasioKonstantaAwal,
}) {
  if (index < 0 || index >= rasionya.length) return konstanta;

  final sendiri = _sah(rasionya[index]);
  if (sendiri != null) return sendiri;

  final sebelum = index > 0 ? _sah(rasionya[index - 1]) : null;
  final sesudah = index + 1 < rasionya.length
      ? _sah(rasionya[index + 1])
      : null;
  if (sebelum != null) return sebelum;
  if (sesudah != null) return sesudah;

  return medianDiketahui(rasionya) ?? konstanta;
}

double? _sah(double? nilai) {
  if (nilai == null) return null;
  if (!nilai.isFinite || nilai <= 0) return null;
  return nilai;
}

double? medianDiketahui(List<double?> rasionya) {
  final ada = rasionya.map(_sah).whereType<double>().toList()..sort();
  if (ada.isEmpty) return null;
  final tengah = ada.length ~/ 2;
  if (ada.length.isOdd) return ada[tengah];
  return (ada[tengah - 1] + ada[tengah]) / 2;
}

class RatioCache {
  const RatioCache._();

  static const int maksEntri = 5000;

  static Box? get _box => AppStorage.pageRatioBox;

  static double? ambil(String imageUrl) {
    if (imageUrl.isEmpty) return null;
    final nilai = _box?.get(imageUrl);
    if (nilai is num) {
      final r = nilai.toDouble();
      if (r.isFinite && r > 0) return r;
    }
    if (nilai is List && nilai.length == 2) {
      final w = nilai[0];
      final h = nilai[1];
      if (w is num && h is num && w > 0 && h > 0) return w / h;
    }
    return null;
  }

  static void simpan(String imageUrl, double rasio) {
    final box = _box;
    if (box == null || imageUrl.isEmpty) return;
    if (!rasio.isFinite || rasio <= 0) return;
    box.put(imageUrl, rasio);
    _buangLebih();
  }

  static void simpanDimensi(String imageUrl, Dimensi d) {
    simpan(imageUrl, d.w / d.h);
  }

  static void _buangLebih() {
    final box = _box;
    if (box == null) return;
    final jumlah = box.length;
    if (jumlah <= maksEntri) return;
    final kunci = box.keys.toList();
    final buang = jumlah - maksEntri;
    for (var i = 0; i < buang && i < kunci.length; i++) {
      box.delete(kunci[i]);
    }
  }

  static int get jumlahEntri => _box?.length ?? 0;

  static Future<void> kosongkan() async {
    await _box?.clear();
  }
}
