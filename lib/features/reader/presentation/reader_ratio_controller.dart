import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:alana/core/diagnostics/error_log.dart';
import 'package:alana/models/page.dart' as manga;

import '../data/page_ratio.dart';
import '../data/ratio_probe.dart';

class ReaderRatioController {
  ReaderRatioController({
    required this.pages,
    required this.online,
    RatioProbe? probe,
  }) : _probe = probe ?? RatioProbe(),
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

  static const int konkurensi = 4;
  static const int _jendelaDepan = 8;
  static const int _jendelaBelakang = 2;
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

  double rasioEfektif(int index) {
    if (index < 0 || index >= _efektif.length) return rasioKonstantaAwal;
    return _efektif[index];
  }

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

    aturJendela(aktif);
    await Future.any<void>([
      Future.wait(perlu.map(_tungguDiketahui)),
      Future<void>.delayed(batas),
    ]);
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
              _lepasMenunggu(index);
          }
        } catch (_) {
          _lepasMenunggu(index);
        }
      }
    }

    for (var i = 0; i < konkurensi && i < antre.length; i++) {
      unawaited(worker());
    }
  }

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
    _lepasSemuaMenunggu();
  }

  bool get diblokir => _diblokir;
  int? get statusBlokir => _statusBlokir;

  Future<HasilProbe> _ambilRasio(int index) async {
    final page = pages[index];
    if (!online) {
      final dimensi = await bacaDimensiFileLokal(page.imageUrl);
      if (dimensi == null) return const HasilKosong();
      return HasilRasio(dimensi.w / dimensi.h);
    }
    return _probe.probe(page.imageUrl);
  }

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

  void hentikan() {
    batalkan();
  }

  void dispose() {
    batalkan();
    final daftar = _notifier;
    _notifier = null;
    for (final n in daftar ?? const <ValueNotifier<double?>>[]) {
      n.dispose();
    }
  }
}
