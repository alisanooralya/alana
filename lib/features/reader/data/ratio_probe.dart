import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:alana/core/diagnostics/error_log.dart';

import 'page_ratio.dart';
import 'reader_net.dart';
import 'reader_repository.dart';

sealed class HasilProbe {
  const HasilProbe();
}

final class HasilRasio extends HasilProbe {
  const HasilRasio(this.rasio);

  final double rasio;
}

final class HasilKosong extends HasilProbe {
  const HasilKosong([this.statusCode]);

  final int? statusCode;
}

final class HasilDiblokir extends HasilProbe {
  const HasilDiblokir(this.statusCode);

  final int statusCode;
}

class RatioProbe {
  RatioProbe({Dio? dio}) : _dio = dio ?? Dio();

  static const int batasByte = 2048;

  static const Duration batasWaktu = Duration(seconds: 4);

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
            'Accept-Encoding': 'identity',
          },
          receiveTimeout: batasWaktu,
          sendTimeout: batasWaktu,
          followRedirects: true,
          maxRedirects: 3,
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
          if (collected.length >= batasByte) break;
        }
      } finally {
        if (!token.isCancelled) token.cancel('probe cukup');
      }
      bytes = collected.takeBytes();
    } on DioException catch (error) {
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
