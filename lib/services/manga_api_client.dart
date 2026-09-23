import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Low-level HTTP client for the Shinigami API.
///
/// Handles base URLs, headers and timeouts. Business-level calls live in
/// `MangaApiService`.
class MangaApiClient {
  static const String webBaseUrl = 'https://app.shinigami.asia';
  static const String apiBaseUrl = 'https://api.shngm.io';
  static const String cdnBaseUrl = 'https://storage.shngm.id';

  late final Dio _api = _createApiDio();
  final Dio _images = Dio();

  Dio _createApiDio() {
    return Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: _apiHeaders(),
      ),
    );
  }

  /// Performs a GET request and returns the decoded response body.
  Future<dynamic> getData(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _api.get<dynamic>(
      path,
      queryParameters: queryParameters,
    );
    return response.data;
  }

  /// Like [getData], but guarantees the body is a JSON object.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await getData(path, queryParameters: queryParameters);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid response from API');
    }
    return data;
  }

  /// Downloads an image and returns its raw bytes.
  Future<Uint8List> downloadImage(String imageUrl) async {
    final response = await _images.get<List<int>>(
      imageUrl,
      options: Options(
        headers: _imageHeaders(),
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Map<String, String> _apiHeaders() {
    return {
      'Accept': 'application/json',
      'DNT': '1',
      'Origin': webBaseUrl,
      'Sec-GPC': '1',
      'X-Requested-With': _randomString(Random().nextInt(20) + 1),
    };
  }

  Map<String, String> _imageHeaders() {
    return {
      'Accept':
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      'DNT': '1',
      'Referer': '$webBaseUrl/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-GPC': '1',
      'X-Requested-With': _randomString(Random().nextInt(20) + 1),
    };
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rnd = Random();
    return List.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
  }
}
