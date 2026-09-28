typedef EntriGabung = ({DateTime updated, Map<String, dynamic> data});

class HasilGabung {
  const HasilGabung({
    required this.lokal,
    required this.unggah,
    required this.hapusRemote,
    required this.tombsSisa,
  });

  final Map<String, Map<String, dynamic>> lokal;
  final List<Map<String, dynamic>> unggah;
  final List<String> hapusRemote;
  final Map<String, DateTime> tombsSisa;
}

HasilGabung gabung({
  required Map<String, EntriGabung> lokal,
  required Map<String, EntriGabung> remote,
  required Map<String, DateTime> tombs,
  Map<String, DateTime> tombsRemote = const {},
  required Map<String, dynamic> Function(Map<String, dynamic> data) keBaris,
}) {
  final hasilLokal = <String, Map<String, dynamic>>{};
  final unggah = <Map<String, dynamic>>[];
  final hapusRemote = <String>[];
  final tombsSisa = <String, DateTime>{};

  final semuaId = <String>{
    ...lokal.keys,
    ...remote.keys,
    ...tombs.keys,
    ...tombsRemote.keys,
  };
  for (final id in semuaId) {
    final l = lokal[id];
    final r = remote[id];
    final tLokal = tombs[id];
    final tRemote = tombsRemote[id];
    DateTime? t;
    if (tLokal != null && tRemote != null) {
      t = tRemote.isAfter(tLokal) ? tRemote : tLokal;
    } else {
      t = tLokal ?? tRemote;
    }

    if (t != null) {
      if (l != null && l.updated.isAfter(t)) {
        hasilLokal[id] = l.data;
        unggah.add(keBaris(l.data));
      } else if (r != null && r.updated.isAfter(t)) {
        hasilLokal[id] = r.data;
      } else {
        if (r != null) hapusRemote.add(id);
        if (tLokal != null) tombsSisa[id] = tLokal;
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
