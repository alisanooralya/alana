import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class BatasKoneksi {
  BatasKoneksi(this.maks) : _tersedia = maks;

  final int maks;

  int _tersedia;
  final Queue<Completer<void>> _antrean = Queue<Completer<void>>();

  int _aktif = 0;
  int _puncak = 0;

  int get aktif => _aktif;
  int get puncak => _puncak;
  int get tersedia => _tersedia;
  int get menunggu => _antrean.length;

  Future<T> jalankan<T>(Future<T> Function() aksi) async {
    await ambil();
    try {
      return await aksi();
    } finally {
      buang();
    }
  }

  Future<void> ambil() async {
    if (_tersedia > 0) {
      _tersedia--;
    } else {
      final c = Completer<void>();
      _antrean.add(c);
      await c.future;
    }
    _aktif++;
    if (_aktif > _puncak) _puncak = _aktif;
  }

  void buang() {
    _aktif--;
    if (_antrean.isNotEmpty) {
      _antrean.removeFirst().complete();
    } else {
      _tersedia++;
    }
  }

  void resetPuncak() => _puncak = _aktif;
}

final BatasKoneksi batasKoneksiCdn = BatasKoneksi(6);

class PenghitungTrafik {
  const PenghitungTrafik._();

  static int _probe = 0;
  static int _unduhan = 0;
  static int _hitCache = 0;

  static int get probe => _probe;
  static int get unduhan => _unduhan;
  static int get hitCache => _hitCache;

  static bool get aktif => kDebugMode;

  static void tambahProbe([int n = 1]) {
    if (!kDebugMode) return;
    _probe += n;
  }

  static void tambahUnduhan([int n = 1]) {
    if (!kDebugMode) return;
    _unduhan += n;
  }

  static void tambahHitCache([int n = 1]) {
    if (!kDebugMode) return;
    _hitCache += n;
  }

  static void reset() {
    _probe = 0;
    _unduhan = 0;
    _hitCache = 0;
    batasKoneksiCdn.resetPuncak();
  }

  static String ringkas() {
    return 'reader: probe=$_probe unduhan=$_unduhan '
        'hitCache=$_hitCache puncakKoneksi=${batasKoneksiCdn.puncak}/'
        '${batasKoneksiCdn.maks}';
  }
}

String readerCacheKey(String url) => 'reader/$url';

class ReaderFileService implements FileService {
  ReaderFileService({HttpFileService? dalam})
    : _dalam = dalam ?? HttpFileService();

  final HttpFileService _dalam;

  @override
  int concurrentFetches = 4;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    await batasKoneksiCdn.ambil();
    var dilepas = false;
    void lepas() {
      if (dilepas) return;
      dilepas = true;
      batasKoneksiCdn.buang();
    }

    try {
      PenghitungTrafik.tambahUnduhan();
      final respons = await _dalam.get(url, headers: headers);
      return _ResponsBerbatas(respons, lepas);
    } catch (_) {
      lepas();
      rethrow;
    }
  }
}

class _ResponsBerbatas implements FileServiceResponse {
  _ResponsBerbatas(this._dalam, this._lepas);

  final FileServiceResponse _dalam;
  final void Function() _lepas;

  @override
  int get statusCode => _dalam.statusCode;

  @override
  int? get contentLength => _dalam.contentLength;

  @override
  DateTime get validTill => _dalam.validTill;

  @override
  String? get eTag => _dalam.eTag;

  @override
  String get fileExtension => _dalam.fileExtension;

  @override
  Stream<List<int>> get content async* {
    try {
      await for (final chunk in _dalam.content) {
        yield chunk;
      }
    } finally {
      _lepas();
    }
  }
}

class ReaderCacheManager extends CacheManager {
  ReaderCacheManager(super.config);

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    final stream = super.getFileStream(
      url,
      key: key,
      headers: headers,
      withProgress: withProgress,
    );
    return stream.transform(
      StreamTransformer<FileResponse, FileResponse>.fromHandlers(
        handleData: (data, sink) {
          if (data is FileInfo && data.source == FileSource.Cache) {
            PenghitungTrafik.tambahHitCache();
          }
          sink.add(data);
        },
      ),
    );
  }
}

final ReaderCacheManager readerCacheManager = ReaderCacheManager(
  Config(
    'reader_cache',
    stalePeriod: const Duration(days: 14),
    maxNrOfCacheObjects: 600,
    fileService: ReaderFileService(),
  ),
);

Future<void> kosongkanCacheGambarReader() {
  return readerCacheManager.emptyCache();
}
