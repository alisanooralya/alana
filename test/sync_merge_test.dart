import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/sync/data/merge.dart';

Map<String, dynamic> _baris(Map<String, dynamic> data) => {
  'id': data['id'],
  'updated': (data['updated'] as DateTime).toIso8601String(),
};

EntriGabung _e(String iso, [String extra = '']) => (
  updated: DateTime.parse(iso),
  data: {'id': 'x', 'updated': DateTime.parse(iso), 'extra': extra},
);

void main() {
  group('gabung last-write-wins', () {
    test('lokal lebih baru menang dan diunggah', () {
      final hasil = gabung(
        lokal: {'a': _e('2026-01-02T00:00:00Z', 'lokal')},
        remote: {'a': _e('2026-01-01T00:00:00Z', 'remote')},
        tombs: const {},
        keBaris: _baris,
      );
      expect(hasil.lokal['a']!['extra'], 'lokal');
      expect(hasil.unggah, hasLength(1));
      expect(hasil.hapusRemote, isEmpty);
    });

    test('remote lebih baru menang tanpa unggah', () {
      final hasil = gabung(
        lokal: {'a': _e('2026-01-01T00:00:00Z', 'lokal')},
        remote: {'a': _e('2026-01-02T00:00:00Z', 'remote')},
        tombs: const {},
        keBaris: _baris,
      );
      expect(hasil.lokal['a']!['extra'], 'remote');
      expect(hasil.unggah, isEmpty);
    });

    test('seri dimenangkan remote agar konvergen', () {
      final hasil = gabung(
        lokal: {'a': _e('2026-01-01T00:00:00Z', 'lokal')},
        remote: {'a': _e('2026-01-01T00:00:00Z', 'remote')},
        tombs: const {},
        keBaris: _baris,
      );
      expect(hasil.lokal['a']!['extra'], 'remote');
      expect(hasil.unggah, isEmpty);
    });

    test('lokal saja diunggah, remote saja diambil', () {
      final hasil = gabung(
        lokal: {'a': _e('2026-01-01T00:00:00Z')},
        remote: {'b': _e('2026-01-01T00:00:00Z')},
        tombs: const {},
        keBaris: _baris,
      );
      expect(hasil.lokal.keys, containsAll(['a', 'b']));
      expect(hasil.unggah.map((b) => b['id']), ['x']);
    });

    test('tombstone menghapus remote yang lebih lama', () {
      final hasil = gabung(
        lokal: const {},
        remote: {'a': _e('2026-01-01T00:00:00Z')},
        tombs: {'a': DateTime.parse('2026-01-03T00:00:00Z')},
        keBaris: _baris,
      );
      expect(hasil.lokal.containsKey('a'), isFalse);
      expect(hasil.hapusRemote, ['a']);
      expect(hasil.tombsSisa.keys, ['a']);
    });

    test('remote lebih baru dari tombstone hidup lagi', () {
      final hasil = gabung(
        lokal: const {},
        remote: {'a': _e('2026-01-05T00:00:00Z', 'remote')},
        tombs: {'a': DateTime.parse('2026-01-03T00:00:00Z')},
        keBaris: _baris,
      );
      expect(hasil.lokal['a']!['extra'], 'remote');
      expect(hasil.hapusRemote, isEmpty);
      expect(hasil.tombsSisa, isEmpty);
    });

    test('tombstone tanpa remote tidak antre hapus', () {
      final hasil = gabung(
        lokal: const {},
        remote: const {},
        tombs: {'a': DateTime.parse('2026-01-03T00:00:00Z')},
        keBaris: _baris,
      );
      expect(hasil.hapusRemote, isEmpty);
      expect(hasil.tombsSisa.keys, ['a']);
    });
  });
}
