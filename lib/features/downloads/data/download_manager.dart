import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/providers/konektivitas_provider.dart';
import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/reader/data/reader_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';
import 'package:alana/features/settings/data/settings_repository.dart';
import 'package:alana/models/page.dart' as manga;

import 'download_repository.dart';

class DownloadKoneksiPutus implements Exception {
  const DownloadKoneksiPutus();
}

class DownloadWifiTurun implements Exception {
  const DownloadWifiTurun();
}

/// Ditemba saat uid aktif berubah di tengah unduhan. Berbeda dari
/// DownloadKoneksiPutus: ini bukan kegagalan jaringan, jadi tidak boleh
/// ditulis sebagai status failed pada entry akun lama.
class DownloadGantiAkun implements Exception {
  const DownloadGantiAkun();
}

class DownloadRequest {
  const DownloadRequest({
    required this.userId,
    required this.mangaId,
    required this.chapterId,
    required this.mangaTitle,
    required this.chapterTitle,
    this.coverUrl = '',
  });

  final String userId;
  final String mangaId;
  final String chapterId;
  final String mangaTitle;
  final String chapterTitle;
  final String coverUrl;

  String get key => DownloadRepository.keyFor(userId, mangaId, chapterId);
}

class DownloadState {
  DownloadState({
    required Map<String, DownloadedChapter> entries,
    required this.queue,
    this.activeKey,
    this.waitingForWifi = false,
    this.message,
    Map<String, double> liveProgress = const {},
  }) : entries = Map.unmodifiable(entries),
       liveProgress = Map.unmodifiable(liveProgress);

  final Map<String, DownloadedChapter> entries;
  final List<DownloadRequest> queue;
  final String? activeKey;
  final bool waitingForWifi;
  final String? message;
  final Map<String, double> liveProgress;

  DownloadedChapter? entryFor(String key) => entries[key];

  DownloadState copyWith({
    Map<String, DownloadedChapter>? entries,
    List<DownloadRequest>? queue,
    String? activeKey,
    bool clearActive = false,
    bool? waitingForWifi,
    String? message,
    bool clearMessage = false,
    Map<String, double>? liveProgress,
  }) {
    return DownloadState(
      entries: entries ?? this.entries,
      queue: queue ?? this.queue,
      activeKey: clearActive ? null : activeKey ?? this.activeKey,
      waitingForWifi: waitingForWifi ?? this.waitingForWifi,
      message: clearMessage ? null : message ?? this.message,
      liveProgress: liveProgress ?? this.liveProgress,
    );
  }
}

class DownloadManager extends AsyncNotifier<DownloadState> {
  final Dio _dio = Dio();
  bool _pumping = false;
  CancelToken? _cancelToken;

  /// Nilai progress terakhir per key unduhan, dipakai untuk membandingkan
  /// dengan emission berikutnya.
  final Map<String, double> _progressTersimpan = {};
  DateTime? _progressTerakhirTulis;

  // Dio memanggil onReceiveProgress setiap chunk, bisa ratusan kali per
  // detik. Menulis state setiap panggilan memicu rebuild penuh di
  // setiap layar yang sedang membaca provider ini, lalu masuk ke
  // history_repository yang menulis ulang seluruh Hive box. Karena itu
  // progress dibatasi: satu penulisan per [_jedaProgress], dan hanya
  // kalau nilai progress benar-benar bergerak.
  static const Duration _jedaProgress = Duration(milliseconds: 400);
  static const double _minimalGeserProgress = 0.01;

  void _tulisProgressDebounce(String key, double nilai) {
    final waktu = DateTime.now();
    final lalu = _progressTerakhirTulis;
    final nilaiLalu = _progressTersimpan[key];
    final cukupJeda = lalu == null || waktu.difference(lalu) >= _jedaProgress;
    final cukupGeser =
        nilaiLalu == null || (nilai - nilaiLalu).abs() >= _minimalGeserProgress;
    if (!cukupJeda || !cukupGeser) return;

    _progressTerakhirTulis = waktu;
    _progressTersimpan[key] = nilai;
    final value = state.valueOrNull;
    if (value == null) return;
    _tulis(value.copyWith(liveProgress: {...value.liveProgress, key: nilai}));
  }

  @override
  Future<DownloadState> build() async {
    ref.onDispose(() => _dio.close(force: true));
    // Ganti akun harus terasa seketika, bukan setelah chapter yang sedang
    // diunduh selesai. Tanpa listener ini, directory akun lama masih ditulis
    // sampai unduhan berjalan tamat.
    ref.listen<String?>(userIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        _cancelToken?.cancel('ganti akun');
      }
    });
    ref.listen(konektivitasProvider, (previous, next) {
      final value = state.valueOrNull;
      if (value == null) return;
      if (value.waitingForWifi || value.queue.isNotEmpty) {
        unawaited(_pump());
      }
    });
    ref.listen(settingsRepositoryProvider, (previous, next) {
      if (state.valueOrNull?.waitingForWifi == true) {
        unawaited(_pump());
      }
    });
    final repository = ref.watch(downloadRepositoryProvider);
    final entries = await repository.verifyAll();
    final queue = entries
        .where((entry) => entry.status == DownloadStatus.queued)
        .map(
          (entry) => DownloadRequest(
            userId: entry.userId,
            mangaId: entry.mangaId,
            chapterId: entry.chapterId,
            mangaTitle: entry.mangaTitle,
            chapterTitle: entry.chapterTitle,
          ),
        )
        .toList();
    final result = DownloadState(
      entries: {for (final entry in entries) entry.key: entry},
      queue: queue,
    );
    unawaited(Future<void>.delayed(Duration.zero, _pump));
    return result;
  }

  Future<void> enqueue(DownloadRequest request) async {
    if (request.mangaId.isEmpty || request.chapterId.isEmpty) return;
    if (request.userId.isEmpty) return;
    var current = state.valueOrNull;
    if (current == null) {
      try {
        current = await future;
      } catch (_) {
        return;
      }
    }
    final existing = current.entries[request.key];
    if (existing?.status == DownloadStatus.completed) return;
    final entry =
        (existing ??
                DownloadedChapter(
                  userId: request.userId,
                  mangaId: request.mangaId,
                  chapterId: request.chapterId,
                  mangaTitle: request.mangaTitle,
                  chapterTitle: request.chapterTitle,
                  coverLocalPath: '',
                  totalPages: 0,
                  downloadedPages: 0,
                  status: DownloadStatus.queued,
                  fileSizeBytes: 0,
                  createdAt: DateTime.now(),
                ))
            .copyWith(
              mangaTitle: request.mangaTitle,
              chapterTitle: request.chapterTitle,
              status: DownloadStatus.queued,
              errorMessage: '',
            );
    await ref.read(downloadRepositoryProvider).save(entry);
    final queue = [
      request,
      ...current.queue.where((item) => item.key != request.key),
    ];
    _tulis(
      current.copyWith(
        entries: {...current.entries, entry.key: entry},
        queue: queue,
        clearMessage: true,
      ),
    );
    unawaited(_pump());
  }

  Future<void> enqueueAll(List<DownloadRequest> requests) async {
    for (final request in requests) {
      await enqueue(request);
    }
  }

  Future<void> retry(String key) async {
    final current = state.valueOrNull;
    final entry = current?.entries[key];
    if (entry == null) return;
    await enqueue(
      DownloadRequest(
        userId: entry.userId,
        mangaId: entry.mangaId,
        chapterId: entry.chapterId,
        mangaTitle: entry.mangaTitle,
        chapterTitle: entry.chapterTitle,
      ),
    );
  }

  Future<void> pause(String key) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.activeKey == key) {
      _cancelToken?.cancel('dibatalkan pengguna');
      return;
    }
    final queue = current.queue.where((item) => item.key != key).toList();
    final entry = current.entries[key];
    if (entry == null) {
      _tulis(current.copyWith(queue: queue));
      return;
    }
    final dijeda = entry.copyWith(
      status: DownloadStatus.paused,
      errorMessage: 'Download dijeda.',
    );
    await ref.read(downloadRepositoryProvider).save(dijeda);
    _tulis(
      current.copyWith(
        entries: {...current.entries, key: dijeda},
        queue: queue,
      ),
    );
  }

  Future<void> cancel(String key) async {
    await pause(key);
    if (state.valueOrNull?.entries[key] == null) return;
    await deleteChapter(key);
  }

  Future<void> deleteChapter(String key) async {
    final current = state.valueOrNull;
    final entry = current?.entries[key];
    if (entry == null) return;
    if (current!.activeKey == key) _cancelToken?.cancel('dibatalkan pengguna');
    await ref
        .read(downloadRepositoryProvider)
        .deleteChapter(entry.mangaId, entry.chapterId);
    final entries = {...current.entries}..remove(key);
    _tulis(
      current.copyWith(
        entries: entries,
        queue: current.queue.where((item) => item.key != key).toList(),
      ),
    );
  }

  Future<void> deleteManga(String mangaId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.entries.values.any((entry) => entry.mangaId == mangaId)) {
      if (current.activeKey != null &&
          current.entries[current.activeKey]?.mangaId == mangaId) {
        _cancelToken?.cancel('dibatalkan pengguna');
      }
      await ref.read(downloadRepositoryProvider).deleteManga(mangaId);
    }
    final entries = {...current.entries}
      ..removeWhere((key, entry) => entry.mangaId == mangaId);
    _tulis(
      current.copyWith(
        entries: entries,
        queue: current.queue.where((item) => item.mangaId != mangaId).toList(),
      ),
    );
  }

  Future<void> _pump() async {
    if (_pumping) return;
    final current = state.valueOrNull;
    if (current == null || current.activeKey != null) return;
    if (current.queue.isEmpty) {
      if (current.waitingForWifi) {
        _tulis(current.copyWith(waitingForWifi: false));
      }
      return;
    }

    final request = current.queue.first;
    final entry = current.entries[request.key];
    if (entry == null) {
      _tulis(current.copyWith(queue: current.queue.skip(1).toList()));
      return _pump();
    }
    if (entry.status == DownloadStatus.completed) {
      _tulis(current.copyWith(queue: current.queue.skip(1).toList()));
      return _pump();
    }

    final wifiOnly = ref.read(settingsRepositoryProvider).wifiOnlyDownloads;
    if (wifiOnly &&
        !_wifiTersedia(ref.read(konektivitasProvider).valueOrNull)) {
      _tulis(current.copyWith(waitingForWifi: true));
      return;
    }
    if (ref.read(luringProvider)) {
      _tulis(
        current.copyWith(
          queue: [request, ...current.queue.skip(1)],
          message: 'Menunggu koneksi internet untuk mulai mengunduh.',
        ),
      );
      return;
    }

    _pumping = true;
    _tulis(
      current.copyWith(
        activeKey: request.key,
        queue: current.queue.skip(1).toList(),
        waitingForWifi: false,
        clearMessage: true,
      ),
    );
    try {
      await _unduh(request, entry);
    } catch (error) {
      // Ganti akun di tengah unduhan: jangan sentuh Hive maupun state lama,
      // karena repository yang di-capture masih menunjuk direktori akun
      // sebelumnya. Penanganan ada di finally.
      if (error is DownloadGantiAkun) return;
      if (state.valueOrNull == null) return;
      if (error is DownloadKoneksiPutus || error is DownloadWifiTurun) {
        final wifi = error is DownloadWifiTurun;
        final kini = state.valueOrNull ?? current;
        await _gagal(
          kini,
          request,
          wifi
              ? 'Wi-Fi terputus. Menunggu Wi-Fi.'
              : 'Koneksi terputus, unduhan dijeda.',
          DownloadStatus.paused,
        );
        _tulis(
          (state.valueOrNull ?? kini).copyWith(
            queue: [request, ...(state.valueOrNull ?? kini).queue],
            waitingForWifi: true,
          ),
        );
        return;
      }
      final dibatalkan =
          error is DioException && error.type == DioExceptionType.cancel;
      if (dibatalkan) {
        await _gagal(
          state.valueOrNull ?? current,
          request,
          'Download dijeda.',
          DownloadStatus.paused,
          cancel: true,
        );
      } else {
        await _gagal(
          state.valueOrNull ?? current,
          request,
          _pesanDownload(error),
          DownloadStatus.failed,
        );
      }
    } finally {
      _pumping = false;
      // Hanya saat uid benar-benar berganti. Kalau dijalankan setiap selesai
      // unduhan, sisa antrean ikut terhapus dan chapter berikutnya tidak
      // pernah ikut terunduh.
      if (!_pemilikMasihAktif(request.userId)) {
        _hentikanKarenaGantiAkun();
      }
      _cancelToken = null;
      await _pump();
    }
  }

  Future<void> _unduh(DownloadRequest request, DownloadedChapter entry) async {
    final repository = ref.read(downloadRepositoryProvider);
    // Pemilik dicapture sekali di awal. repository yang di-capture di atas
    // masih menunjuk ke direktori akun lama, jadi setiap titik henti harus
    // memverifikasi uid aktif sebelum menulis ke sana.
    final pemilik = repository.userId;
    if (pemilik.isEmpty) {
      throw const FormatException('Unduhan tidak punya pemilik akun.');
    }
    final pages = await ref
        .read(readerRepositoryProvider)
        .getPages(request.chapterId);
    _pastikanPemilik(pemilik);
    if (pages.isEmpty) {
      throw const FormatException('Chapter tidak memiliki halaman.');
    }

    final chapterDirectory = await repository.chapterDirectory(
      request.mangaId,
      request.chapterId,
    );
    _pastikanPemilik(pemilik);
    if (chapterDirectory == null) {
      throw const FormatException('Unduhan tidak punya pemilik akun.');
    }
    var coverPath = entry.coverLocalPath;
    if (coverPath.isEmpty && request.coverUrl.isNotEmpty) {
      final mangaDirectory = await repository.mangaDirectory(request.mangaId);
      _pastikanPemilik(pemilik);
      if (mangaDirectory != null) {
        coverPath = '${mangaDirectory.path}/cover.jpg';
        await _unduhFile(request.coverUrl, coverPath);
        _pastikanPemilik(pemilik);
      }
    }

    var ukuranKumulatif = await _ukuranFolder(chapterDirectory);
    var current = entry.copyWith(
      totalPages: pages.length,
      status: DownloadStatus.downloading,
      coverLocalPath: coverPath,
      downloadedPages: 0,
      fileSizeBytes: ukuranKumulatif + await _ukuranFile(coverPath),
      errorMessage: '',
    );
    await repository.save(current);
    final setelahSimpan = state.valueOrNull;
    if (setelahSimpan == null) return;
    _tulis(_denganEntry(setelahSimpan, current));

    for (var index = 0; index < pages.length; index++) {
      _pastikanPemilik(pemilik);
      final wifiOnly = ref.read(settingsRepositoryProvider).wifiOnlyDownloads;
      if (wifiOnly &&
          !_wifiTersedia(ref.read(konektivitasProvider).valueOrNull)) {
        throw const DownloadWifiTurun();
      }
      if (ref.read(luringProvider)) {
        throw const DownloadKoneksiPutus();
      }

      final page = pages[index];
      final path =
          '${chapterDirectory.path}/${(index + 1).toString().padLeft(3, '0')}.jpg';
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        await _unduhFile(
          page.imageUrl,
          path,
          onProgress: (received, total) {
            if (total <= 0) return;
            final nilai = ((index + (received / total)) / pages.length)
                .clamp(0, 1)
                .toDouble();
            _tulisProgressDebounce(request.key, nilai);
          },
        );
        // Dio sudah menulis sebagian byte ke `path` sebelum selesai,
        // jadi file harus dihapus agar tidak tertinggal di folder akun lama.
        _pastikanPemilik(pemilik);
        ukuranKumulatif += await _ukuranFile(path);
      }
      current = current.copyWith(
        downloadedPages: index + 1,
        fileSizeBytes: ukuranKumulatif + await _ukuranFile(coverPath),
      );
      await repository.save(current);
      final setelahHalaman = state.valueOrNull;
      if (setelahHalaman == null) return;
      _tulis(_denganEntry(setelahHalaman, current));
      _progressTersimpan.remove(request.key);
    }

    _pastikanPemilik(pemilik);
    current = current.copyWith(
      status: DownloadStatus.completed,
      downloadedPages: pages.length,
      fileSizeBytes: ukuranKumulatif + await _ukuranFile(coverPath),
      errorMessage: '',
    );
    await repository.save(current);
    final value = state.valueOrNull;
    if (value == null) return;
    final live = {...value.liveProgress}..remove(request.key);
    _tulis(
      _denganEntry(
        value.copyWith(activeKey: null, clearActive: true, liveProgress: live),
        current,
      ),
    );
  }

  /// Melempar [DownloadGantiAkun] kalau uid aktif sudah bukan pemilik
  /// unduhan ini. Dipanggil setelah tiap await yang menyentuh disk.
  void _pastikanPemilik(String pemilik) {
    if (state.valueOrNull == null) throw const DownloadGantiAkun();
    if ((ref.read(userIdProvider) ?? '') != pemilik) {
      throw const DownloadGantiAkun();
    }
  }

  /// Tanpa efek samping, dipakai di finally untuk memutuskan apakah
  /// state perlu dibersihkan.
  bool _pemilikMasihAktif(String pemilik) {
    if (pemilik.isEmpty) return false;
    return (ref.read(userIdProvider) ?? '') == pemilik;
  }

  Future<void> _unduhFile(
    String url,
    String path, {
    void Function(int received, int total)? onProgress,
  }) async {
    _cancelToken = CancelToken();
    await _dio.download(
      url,
      path,
      cancelToken: _cancelToken,
      deleteOnError: true,
      options: Options(headers: readerImageHeaders),
      onReceiveProgress: onProgress,
    );
  }

  Future<void> _gagal(
    DownloadState current,
    DownloadRequest request,
    String message,
    DownloadStatus status, {
    bool cancel = false,
  }) async {
    final existing =
        current.entries[request.key] ??
        await ref
            .read(downloadRepositoryProvider)
            .find(request.mangaId, request.chapterId);
    if (existing == null) return;
    final entry = existing.copyWith(status: status, errorMessage: message);
    await ref.read(downloadRepositoryProvider).save(entry);
    final live = {...current.liveProgress}..remove(request.key);
    _tulis(
      _denganEntry(
        current.copyWith(
          activeKey: null,
          clearActive: true,
          message: cancel ? null : message,
          clearMessage: cancel,
          liveProgress: live,
        ),
        entry,
      ),
    );
  }

  DownloadState _denganEntry(DownloadState state, DownloadedChapter entry) {
    return state.copyWith(entries: {...state.entries, entry.key: entry});
  }

  void _tulis(DownloadState value) {
    state = AsyncData(value);
  }

  /// Dijalankan saat state berubah menjadi null atau account sudah berganti.
  /// Membatalkan unduhan yang sedang berjalan supaya tidak ada penulisan
  /// lagi ke direktori akun lama setelah pindah akun.
  void _hentikanKarenaGantiAkun() {
    final ini = state.valueOrNull;
    _cancelToken?.cancel('ganti akun');
    _cancelToken = null;
    _pumping = false;
    if (ini != null && (ini.activeKey != null || ini.queue.isNotEmpty)) {
      state = AsyncData(
        ini.copyWith(
          activeKey: null,
          clearActive: true,
          queue: const [],
          liveProgress: const {},
        ),
      );
    }
  }

  String _pesanDownload(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('no space') ||
        text.contains('disk full') ||
        text.contains('enospc')) {
      return 'Penyimpanan penuh, hapus beberapa unduhan lalu coba lagi.';
    }
    return pesanErrorRamah(error);
  }
}

final downloadManagerProvider =
    AsyncNotifierProvider<DownloadManager, DownloadState>(() {
      return DownloadManager();
    });

final downloadStorageBytesProvider = FutureProvider<int>((ref) async {
  ref.watch(
    downloadManagerProvider.select((value) {
      final data = value.valueOrNull;
      return '${data?.activeKey}:${data?.entries.length}';
    }),
  );
  return ref.watch(downloadRepositoryProvider).totalStorageBytes();
});

final offlinePageListProvider =
    FutureProvider.family<
      List<manga.Page>,
      ({String mangaId, String chapterId})
    >((ref, kunci) async {
      final entries = await ref.watch(downloadRepositoryProvider).all();
      DownloadedChapter? entry;
      for (final item in entries) {
        if (item.chapterId == kunci.chapterId &&
            item.mangaId == kunci.mangaId) {
          entry = item;
          break;
        }
      }
      if (entry == null || entry.status != DownloadStatus.completed) {
        return const [];
      }
      final files = await ref
          .watch(downloadRepositoryProvider)
          .pageFiles(entry.mangaId, entry.chapterId);
      return [
        for (var index = 0; index < files.length; index++)
          manga.Page(index: index + 1, imageUrl: files[index].path),
      ];
    });

bool _wifiTersedia(List<ConnectivityResult>? status) {
  return status?.contains(ConnectivityResult.wifi) == true;
}

Future<int> _ukuranFile(String path) async {
  if (path.isEmpty) return 0;
  try {
    return await File(path).length();
  } catch (_) {
    return 0;
  }
}

Future<int> _ukuranFolder(Directory directory) async {
  var total = 0;
  if (!await directory.exists()) return total;
  await for (final entity in directory.list(recursive: true)) {
    if (entity is! File) continue;
    try {
      total += await entity.length();
    } catch (_) {}
  }
  return total;
}
