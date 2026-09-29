import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:alana/core/diagnostics/error_log.dart';

import 'page_ratio.dart';
import 'reader_net.dart';
import 'reader_repository.dart';

/// Hasil satu probe.
///
/// Pemisahan ini penting karena 403 dan 429 tidak boleh dicoba ulang dalam
/// sesi yang sama: mencoba lagi hanya memperpanjang pemblokiran dan menambah
/// trafik ke server yang sedang menolak.
sealed class HasilProbe {
  const HasilProbe();
}

/// Rasio berhasil dibaca dari header.
final class HasilRasio extends HasilProbe {
  const HasilRasio(this.rasio);

  final double rasio;
}

/// Tidak ada yang bisa dibaca: 404, header tak dikenal, timeout, atau error
/// jaringan. Boleh dicoba lagi di sesi berikutnya.
final class HasilKosong extends HasilProbe {
  const HasilKosong([this.statusCode]);

  final int? statusCode;
}

/// Server menolak: 403 atau 429. Pemanggil harus menghentikan seluruh probe
/// chapter dan mengandalkan jaring pengaman `ImageInfo`.
final class HasilDiblokir extends HasilProbe {
  const HasilDiblokir(this.statusCode);

  final int statusCode;
}

/// Ambil rasio gambar dari header berkas dengan mengunduh **2 KB pertama saja**.
///
///-Ini yang membuat tinggi item bisa dikunci sejak frame pertama, jadi jalur
/// online tidak perlu menunggu decode dan tidak pernah perlu mengoreksi tinggi
/// setelah gambar tampil. Server mendukung `accept-ranges: bytes`, dan marker
/// SOF JPEG berada di offset sekitar 140, jadi 2 KB lebih dari cukup.
///
/// Semua request melewati [batasKoneksiCdn] supaya probe berbagi batas dengan
/// unduhan gambar dan preload.
class RatioProbe {
  RatioProbe({Dio? dio}) : _dio = dio ?? Dio();

  /// 2048. SOF JPEG terukur di offset 140, VP8L dan VP8X di bawah 26, PNG di
  /// bawah 24, jadi 2 KB memberi ruang untuk EXIF dan APP1 yang besar.
  static const int batasByte = 2048;

  static const Duration batasWaktu = Duration(seconds: 4);

  /// Status yang berarti "coba lagi nanti" atau memang tidak akan berhasil
  /// dalam sesi ini. Keduanya tidak di-retry.
  static const int statusForbidden = 403;
  static const int statusTooManyRequests = 429;

  static bool diblokir(int? status) =>
      status == statusForbidden || status == statusTooManyRequests;

  final Dio _dio;

  Future<HasilProbe> probe(String url) async {
    if (url.isEmpty) return const HasilKosong();
    PenghitungTrafik.tambahProbe();
    try {
      return await batasKoneksiCdn.jalankan(() => _probeDalam(url));
    } catch (_) {
      return const HasilKosong();
    }
  }

  Future<HasilProbe> _probeDalam(String url) async {
    final token = CancelToken();
    Uint8List bytes;
    int? status;

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            ...readerImageHeaders,
            'Range': 'bytes=0-${batasByte - 1}',
            // Tanpa ini server boleh mengompres, dan offset byte dari range
            // tidak lagi sama dengan offset di dalam berkas.
            'Accept-Encoding': 'identity',
          },
          receiveTimeout: batasWaktu,
          sendTimeout: batasWaktu,
          followRedirects: true,
          maxRedirects: 3,
          // 403 dan 429 harus sampai ke sini sebagai respons biasa supaya bisa
          // diklasifikasikan, bukan dilempar sebagai exception.
          validateStatus: (kode) => kode != null && kode >= 200 && kode < 500,
        ),
      );

      status = response.statusCode;
      if (diblokir(status)) {
        return HasilDiblokir(status!);
      }
      if (status != 200 && status != 206) {
        return HasilKosong(status);
      }

      final body = response.data;
      if (body == null) return HasilKosong(status);

      final collected = BytesBuilder(copy: false);
      try {
        await for (final chunk in body.stream) {
          collected.add(chunk);
          // Pada 206 stream berhenti sendiri di 2048 byte. Pada 200 — server
          // mengabaikan `Range` dan mau mengirim berkas penuh yang bisa
          // beberapa megabyte — kita berhenti sendiri dan batalkan di bawah.
          if (collected.length >= batasByte) break;
        }
      } finally {
        if (!token.isCancelled) token.cancel('probe cukup');
      }
      bytes = collected.takeBytes();
    } on DioException catch (error) {
      // Pembatalan yang kita sengaja lakukan bukan kegagalan.
      if (error.type != DioExceptionType.cancel) {
        if (diblokir(error.response?.statusCode)) {
          return HasilDiblokir(error.response!.statusCode!);
        }
        _catat(url, error);
      }
      return HasilKosong(error.response?.statusCode);
    } catch (error) {
      _catat(url, error);
      return const HasilKosong();
    }

    final dimensi = parseHeaderGambar(bytes);
    if (dimensi == null) {
      ErrorLog.catat(
        StateError('header gambar tidak terbaca untuk $url'),
        StackTrace.current,
      );
      return HasilKosong(status);
    }
    return HasilRasio(dimensi.w / dimensi.h);
  }

  void _catat(String url, Object error) {
    ErrorLog.catat(
      StateError('probe rasio gagal: $url — $error'),
      StackTrace.current,
    );
  }
}
