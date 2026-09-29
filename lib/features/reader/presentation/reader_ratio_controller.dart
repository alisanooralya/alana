import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:alana/core/diagnostics/error_log.dart';
import 'package:alana/models/page.dart' as manga;

import '../data/page_ratio.dart';
import '../data/ratio_probe.dart';

/// Memegang rasio satu chapter dan memperbaruinya per halaman.
///
/// Satu `ValueNotifier` per halaman, jadi rasio yang baru datang hanya
/// membangun ulang `AspectRatio` milik halaman itu. Tidak ada `setState` di
/// halaman reader, sehingga tinggi satu item berubah tidak membangun ulang
/// seluruh `ListView`.
///
/// Rasio yang diketahui disimpan terpisah dari rasio efektif: `pilihRasio`
/// memakai tetangga terdekat, jadi rasio baru bisa mengubah nilai efektif
/// beberapa halaman sekaligus. Karena itu setiap perubahan memicu
/// perhitungan ulang semua halaman, tetapi hanya notifier yang nilainya
/// benar-benar berbeda yang dinotifikasi.
class ReaderRatioController {
  ReaderRatioController({
    required this.pages,
    required this.online,
    RatioProbe? probe,
  }) : _probe = probe ?? RatioProbe(),
       // Panjang harus ditetapkan di sini. Growable list tidak lagi bertambah
       // sendiri saat ditulis dengan indeks: `list[0] = x` pada list kosong
       // melempar RangeError, dan itu menggagalkan seluruh build reader.
       _diketahui = List<double?>.filled(pages.length, null),
       _efektif = List<double>.filled(pages.length, rasioKonstantaAwal) {
    for (var i = 0; i < pages.length; i++) {
      _diketahui[i] = _rasioAwal(pages[i]);
    }
    for (var i = 0; i < pages.length; i++) {
      _efektif[i] = pilihRasio(index: i, rasionya: _diketahui);
    }
  }

  final List<manga.Page> pages;
  final bool online;
  final RatioProbe _probe;

  /// Empat, bukan enam. Enam adalah batas koneksi ke CDN, dan sisanya perlu
  /// disisakan untuk unduhan gambar dan preload; probe yang terlalu banyak
  /// membuat unduhan yang sedang dibaca ikut lambat.
  static const int konkurensi = 4;

  /// Jendela probe di sekitar halaman yang sedang tampil.
  static const int _jendelaDepan = 8;
  static const int _jendelaBelakang = 2;

  /// Berapa halaman ke depan yang ditunggu sebelum list pertama ditampilkan.
  static const int halamanAntar = 2;

  final List<double?> _diketahui;
  final List<double> _efektif;
  final Map<int, List<Completer<void>>> _menunggu = {};
  bool _dibatalkan = false;
  bool _diblokir = false;
  int? _statusBlokir;
  int _jendelaAktif = -1;
  int _generasi = 0;

  List<ValueNotifier<double?>>? _notifier;

  /// Dibuat sekali lalu dipakai ulang. `ListView.builder` membangun ulang item
  /// berkali-kali, dan membuat notifier baru setiap kali akan menulis ke
  /// heap tanpa pernah dilepas.
  List<ValueNotifier<double?>> get notifier {
    final ada = _notifier;
    if (ada != null) return ada;
    final dibuat = [
      for (var i = 0; i < pages.length; i++)
        ValueNotifier<double?>(_efektif[i]),
    ];
    _notifier = dibuat;
    return dibuat;
  }

  double? _rasioAwal(manga.Page page) {
    final dariApi = page.aspectRatio;
    if (dariApi != null && dariApi.isFinite && dariApi > 0) return dariApi;
    if (page.imageUrl.isEmpty) return null;
    return RatioCache.ambil(page.imageUrl);
  }

  /// Rasio yang akan dipakai item pada [index]. Dipanggil sekali saat membuat
  /// item, bukan tiap build.
  double rasioEfektif(int index) {
    if (index < 0 || index >= _efektif.length) return rasioKonstantaAwal;
    return _efektif[index];
  }

  /// Pasang rasio hasil decode (`ImageInfo`) atau hasil baca header lokal.
  /// Nilai `null` berarti probe tidak berhasil; pemanggil lalu menunggu
  /// jaring pengaman di `ReaderImage`. Aman dipanggil berkali-kali.
  ///
  /// Nilai yang sudah cocok diabaikan. `ReaderImage` melaporkan dimensi setiap
  /// kali gambar tampil, termasuk dari cache, jadi tanpa penjaga ini satu
  /// chapter bisa menulis Hive puluhan kali untuk nilai yang sama.
  void tetapkan(int index, double? rasio) {
    if (index < 0 || index >= _diketahui.length) return;
    if (rasio == null || !rasio.isFinite || rasio <= 0) return;

    final lama = _diketahui[index];
    if (lama != null && (lama - rasio).abs() / lama < 0.001) return;

    final url = pages[index].imageUrl;
    if (url.isNotEmpty) RatioCache.simpan(url, rasio);
    _diketahui[index] = rasio;
    _perbaruiEfektif();
    _lepasMenunggu(index);
  }

  void _perbaruiEfektif() {
    final daftar = _notifier;
    for (var i = 0; i < pages.length; i++) {
      final baru = pilihRasio(index: i, rasionya: _diketahui);
      if (baru == _efektif[i]) continue;
      _efektif[i] = baru;
      // Kalau notifier belum pernah dibuat, nilainya sudah tersimpan di
      // `_efektif` dan akan dipakai saat notifier dibangun.
      if (daftar != null) daftar[i].value = baru;
    }
  }

  void _lepasMenunggu(int index) {
    final daftar = _menunggu.remove(index);
    if (daftar == null) return;
    for (final c in daftar) {
      if (!c.isCompleted) c.complete();
    }
  }

  /// Tunggu rasio untuk halaman aktif dan [halamanAntar] berikutnya, paling
  /// lama [batas]. Setelah itu list ditampilkan dengan rasio yang sudah ada
  /// dan sisanya memakai fallback. Tidak ada yang menunggu lebih lama dari
  /// [batas], jadi list tidak pernah tertahan.
  Future<void> tungguAwal(
    int aktif, {
    Duration batas = const Duration(milliseconds: 1500),
  }) async {
    if (_dibatalkan) return;
    final perlu = <int>[];
    for (var d = 0; d <= halamanAntar; d++) {
      final i = aktif + d;
      if (i < pages.length && _diketahui[i] == null) perlu.add(i);
    }
    if (perlu.isEmpty) return;

    // Online: probe jaringan. Offline: baca header berkas lokal, yang tidak
    // menambah trafik sama sekali.
    aturJendela(aktif);
    await Future.any<void>([
      Future.wait(perlu.map(_tungguDiketahui)),
      Future<void>.delayed(batas),
    ]);
    // Kalau batas yang menang, sisanya masih menggantung. Buang supaya tidak
    // ditahan sampai akhir chapter.
    for (final i in perlu) {
      _menunggu.remove(i);
    }
  }

  Future<void> _tungguDiketahui(int index) {
    if (_diketahui[index] != null) return Future<void>.value();
    if (_dibatalkan) return Future<void>.value();
    final completer = Completer<void>();
    _menunggu.putIfAbsent(index, () => <Completer<void>>[]).add(completer);
    return completer.future;
  }

  /// Geser jendela probe mengikuti halaman yang sedang tampil.
  ///
  /// Jendela hanya [_jendelaDepan] halaman ke depan dan [_jendelaBelakang] ke
  /// belakang, bukan seluruh chapter. Chapter 60 halaman yang hanya dibaca
  /// sampai halaman 5 mengirim 11 probe, bukan 60. Probe untuk halaman yang
  /// rasionya sudah ada di `RatioCache` juga dilewati, jadi chapter yang pernah
  /// dibuka hanya menambah request untuk halaman yang baru.
  ///
  /// Memanggil ulang ini menggeser jendela; probe yang masih antre tapi belum
  /// mulai dibatalkan lewat [_generasi], jadi yang tidak terpakai tidak pernah
  /// menyentuh jaringan.
  void aturJendela(int aktif) {
    if (_dibatalkan || _diblokir) return;
    if (aktif < 0) aktif = 0;
    if (aktif >= pages.length) aktif = pages.length - 1;
    if (aktif == _jendelaAktif) return;
    _jendelaAktif = aktif;
    _generasi++;
    _jadwal();
  }

  void _jadwal() {
    final antre = <int>[];
    for (var i = _jendelaAktif; i < _jendelaDepan; i++) {
      if (i < pages.length && _diketahui[i] == null) antre.add(i);
    }
    for (var i = _jendelaAktif - 1; i > -_jendelaBelakang; i--) {
      if (i >= 0 && i < pages.length && _diketahui[i] == null) antre.add(i);
    }
    if (antre.isEmpty) return;

    final generasi = _generasi;
    var kursor = 0;

    Future<void> worker() async {
      while (!_dibatalkan && !_diblokir) {
        if (kursor >= antre.length) return;
        // Jendela sudah bergeser sejak antrean ini dibuat; sisanya dibuang.
        if (generasi != _generasi) return;
        final index = antre[kursor++];
        try {
          final hasil = await _ambilRasio(index);
          if (_dibatalkan) return;
          switch (hasil) {
            case HasilRasio(:final rasio):
              tetapkan(index, rasio);
            case HasilDiblokir(:final statusCode):
              _blokirSeluruhChapter(statusCode);
              return;
            case HasilKosong():
              // Tidak ada yang bisa dilakukan di sini. Halaman ini akan
              // memakai rasio tetangga sampai jaring pengaman `ImageInfo`
              // memberikannya nilai setelah decode.
              _lepasMenunggu(index);
          }
        } catch (_) {
          // Jaring pengaman terakhir supaya satu halaman rusak tidak
          // menghentikan antrean.
          _lepasMenunggu(index);
        }
      }
    }

    for (var i = 0; i < konkurensi && i < antre.length; i++) {
      unawaited(worker());
    }
  }

  /// Server menolak dengan 403 atau 429: hentikan seluruh probe chapter ini
  /// selama sisa sesi dan pakai jaring pengaman `ImageInfo`. Tidak ada retry
  /// otomatis untuk kedua status itu.
  void _blokirSeluruhChapter(int statusCode) {
    if (_diblokir) return;
    _diblokir = true;
    _statusBlokir = statusCode;
    ErrorLog.catat(
      StateError(
        'probe rasio dihentikan untuk ${pages.length} halaman ini '
        '(HTTP $statusCode); memakai rasio dari decode',
      ),
      StackTrace.current,
    );
    // Halaman yang sedang ditunggu tidak akan pernah datang; lepaskan supaya
    // `tungguAwal` tidak menahan 1,5 detik percuma.
    _lepasSemuaMenunggu();
  }

  bool get diblokir => _diblokir;
  int? get statusBlokir => _statusBlokir;

  Future<HasilProbe> _ambilRasio(int index) async {
    final page = pages[index];
    if (!online) {
      // Offline: baca header berkas lokal. Tidak ada trafik jaringan sama
      // sekali, dan hasilDlokal tidak perlu lewat probe.
      final dimensi = await bacaDimensiFileLokal(page.imageUrl);
      if (dimensi == null) return const HasilKosong();
      return HasilRasio(dimensi.w / dimensi.h);
    }
    return _probe.probe(page.imageUrl);
  }

  /// Hentikan semua probe: yang antre dibuang, yang sedang berjalan
  /// dibiarkan. Setiap probe punya timeout 4 detik dan hanya empat yang aktif.
  void batalkan() {
    if (_dibatalkan) return;
    _dibatalkan = true;
    _generasi++;
    _lepasSemuaMenunggu();
  }

  void _lepasSemuaMenunggu() {
    for (final daftar in _menunggu.values) {
      for (final c in daftar) {
        if (!c.isCompleted) c.complete();
      }
    }
    _menunggu.clear();
  }

  bool get dibatalkan => _dibatalkan;

  /// Berhenti bekerja tanpa membuang notifier.
  ///
  /// Dipakai saat daftar halaman berganti di tengah `build`. Notifier lama
  /// masih didengarkan `ReaderImage` yang belum rebuilt, dan
  /// `ChangeNotifier.removeListener` melempar assertion kalau dipakai setelah
  /// `dispose`. Notifier lamanya nanti dibuang garbage collector begitu
  /// `didUpdateWidget` melepas listener-nya.
  void hentikan() {
    batalkan();
  }

  /// Hanya aman dipanggil setelah semua `ReaderImage` yang memakai notifier ini
  /// sudah `dispose`, yaitu dari `State.dispose` halaman reader — anak di-unmount
  /// sebelum induknya.
  void dispose() {
    batalkan();
    final daftar = _notifier;
    _notifier = null;
    for (final n in daftar ?? const <ValueNotifier<double?>>[]) {
      n.dispose();
    }
  }
}
