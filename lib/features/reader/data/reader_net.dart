import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Pembatas koneksi serentak ke host CDN.
///
/// Satu objek untuk probe, unduhan gambar, dan preload, sehingga batasnya
/// berlaku untuk trafik reader secara keseluruhan, bukan per jalur. Tanpa ini
/// ketiga jalannya bisa bertumpuk dan membuka belasan koneksi sekaligus ke
/// server yang sama saat sedang fling.
class BatasKoneksi {
  BatasKoneksi(this.maks) : _tersedia = maks;

  final int maks;

  int _tersedia;
  final Queue<Completer<void>> _antrean = Queue<Completer<void>>();

  int _aktif = 0;
  int _puncak = 0;

  /// Koneksi yang benar-benar sedang berjalan, termasuk yang sedang stream.
  int get aktif => _aktif;

  /// Rekor jumlah koneksi bersamaan, untuk dicetak sebagai ringkasan.
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
      // Permit langsung dihand-over ke penunggu, tidak lewat `_tersedia`.
      _antrean.removeFirst().complete();
    } else {
      _tersedia++;
    }
  }

  void resetPuncak() => _puncak = _aktif;
}

/// Batas total probe + unduhan + preload yang boleh menyentuh CDN bersamaan.
final BatasKoneksi batasKoneksiCdn = BatasKoneksi(6);

/// Penghitung request untuk diagnosa, hanya hidup di mode debug.
///
/// [unduhan] dihitung di [ReaderFileService] yang hanya dipakai cache manager
/// reader, jadi unduhan dari halaman lain tidak ikut terhitung. Angka_target
/// satu sesi baca saja, jadi pemanggil yang mencetak ringkasan memanggil
/// [reset] lebih dulu.
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

/// Kunci cache untuk reader.
///
/// Dipakai oleh `CachedNetworkImage`, `CachedNetworkImageProvider` di dalam
/// `precacheImage`, dan apa pun yang butuh file yang sama. Penting karena
/// `cacheKey` diteruskan sebagai `key` ke `CacheManager.getFileStream`:
/// selama nilainya sama untuk satu url, permintaan kedua dilayani dari cache
/// dan tidak terjadi unduhan ganda.
///
/// Diturunkan dari url, bukan dari counter, supaya dua pemanggil yang tidak
/// saling tahu tetap menghasilkan kunci yang sama.
String readerCacheKey(String url) => 'reader/$url';

/// File service reader.
///
/// Mengambil permit [batasKoneksiCdn] selama unduhan berjalan, bukan hanya
/// sampai header diterima, dan menghitung setiap unduhan nyata.
class ReaderFileService implements FileService {
  ReaderFileService({HttpFileService? dalam})
    : _dalam = dalam ?? HttpFileService();

  final HttpFileService _dalam;

  /// Antrean internal `WebHelper` juga membatasi jumlah unduhan. Nilainya
  /// dibuat lebih ketat dari batas global supaya tidak semua permit dipakai
  /// unduhan dan probe ikut tertahan.
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

/// Permit ditahan sampai seluruh isi stream habis, bukan hanya sampai header
/// diterima. Melepas lebih awal membuat batas enam tidak berlaku untuk transfer
/// yang justru paling lama.
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

  /// Permit ditahan sampai seluruh isi stream habis, bukan hanya sampai header
  /// diterima. Melepas lebih awal membuat batas enam tidak berlaku untuk
  /// transfer yang justru paling lama. `finally` juga jalan saat langganan
  /// dibatalkan, jadi tidak ada permit yang menggantung.
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

/// Cache manager khusus reader.
///
/// Dipisah dari `DefaultCacheManager` supaya membaca chapter tidak ikut
/// menyingkirkan cache gambar home, detail, dan library yang memakai cache
/// manager bawaan.
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
          // Berkas yang sudah lengkap di disk dilayani tanpa memanggil file
          // service sama sekali. CDN mengirim `cache-control: max-age` satu
          // tahun, jadi dalam masa 14 hari berkas praktis selalu fresh dan hit
          // tidak beririsan dengan unduhan.
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

/// Menghapus cache gambar reader.
///
/// **Tidak** menyentuh rasio. Rasio disimpan di Hive box terpisah
/// `page_ratio` milik `RatioCache`, bukan di cache manager, jadi membersihkan
/// gambar tidak membuat probe 2 KB diulang untuk halaman yang rasionya sudah
/// diketahui. Yang menghapus box itu hanya `AppStorage.hapusBoxUser`, dan itu
/// hanya dijalankan untuk box per pengguna `bm`/`rh`/`sm`.
Future<void> kosongkanCacheGambarReader() {
  return readerCacheManager.emptyCache();
}
