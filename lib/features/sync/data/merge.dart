/// Logika merge last-write-wins (murni, tanpa I/O).
///
/// Dipakai untuk bookmark maupun riwayat: pemanggil menormalkan
/// baris lokal dan remote ke [EntriGabung] lalu membangun baris
/// remote dari `data` lewat [keBaris].
///
/// - Seri (`updated` sama): remote menang agar perangkat konvergen.
/// - Lokal pending yang kalah: gugur (ditimpa remote).
/// - Tombstone (hapus lokal): menghapus remote kecuali remote lebih baru
///   (dianggap dibuat ulang di perangkat lain → hidup lagi).
typedef EntriGabung = ({DateTime updated, Map<String, dynamic> data});

class HasilGabung {
  const HasilGabung({
    required this.lokal,
    required this.unggah,
    required this.hapusRemote,
    required this.tombsSisa,
  });

  /// Status lokal gabungan (id → map entri, flag pending apa adanya).
  final Map<String, Map<String, dynamic>> lokal;

  /// Baris remote lengkap untuk batch upsert.
  final List<Map<String, dynamic>> unggah;

  /// ID untuk dihapus di remote.
  final List<String> hapusRemote;

  /// Tombstone yang bertahan (belum terdorong).
  final Map<String, DateTime> tombsSisa;
}

HasilGabung gabung({
  required Map<String, EntriGabung> lokal,
  required Map<String, EntriGabung> remote,
  required Map<String, DateTime> tombs,
  required Map<String, dynamic> Function(Map<String, dynamic> data) keBaris,
}) {
  final hasilLokal = <String, Map<String, dynamic>>{};
  final unggah = <Map<String, dynamic>>[];
  final hapusRemote = <String>[];
  final tombsSisa = <String, DateTime>{};

  final semuaId = <String>{...lokal.keys, ...remote.keys, ...tombs.keys};
  for (final id in semuaId) {
    final l = lokal[id];
    final r = remote[id];
    final t = tombs[id];

    if (t != null) {
      if (r != null && r.updated.isAfter(t)) {
        // Dibuat ulang di perangkat lain setelah dihapus di sini.
        hasilLokal[id] = r.data;
      } else {
        if (r != null) hapusRemote.add(id);
        tombsSisa[id] = t;
      }
      continue;
    }

    if (l != null && r != null) {
      if (l.updated.isAfter(r.updated)) {
        hasilLokal[id] = l.data;
        unggah.add(keBaris(l.data));
      } else {
        hasilLokal[id] = r.data;
      }
      continue;
    }

    if (l != null) {
      hasilLokal[id] = l.data;
      unggah.add(keBaris(l.data));
      continue;
    }

    hasilLokal[id] = r!.data;
  }

  return HasilGabung(
    lokal: hasilLokal,
    unggah: unggah,
    hapusRemote: hapusRemote,
    tombsSisa: tombsSisa,
  );
}
