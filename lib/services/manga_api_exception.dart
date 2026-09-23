import 'package:dio/dio.dart';

/// Error thrown by [MangaApiService] when an API call fails.
class MangaApiException implements Exception {
  final String message;
  final int? statusCode;

  const MangaApiException(this.message, {this.statusCode});

  /// Wraps any [error] thrown while performing [action] into a
  /// [MangaApiException]. Already wrapped errors are returned as-is.
  factory MangaApiException.from(String action, Object error) {
    if (error is MangaApiException) return error;

    if (error is DioException && error.response != null) {
      final response = error.response!;
      final data = response.data;
      final message = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (error.message ?? '');
      return MangaApiException(
        'Failed to $action: ${response.statusCode} - $message',
        statusCode: response.statusCode,
      );
    }

    return MangaApiException('Failed to $action: $error');
  }

  @override
  String toString() => 'MangaApiException: $message';
}
