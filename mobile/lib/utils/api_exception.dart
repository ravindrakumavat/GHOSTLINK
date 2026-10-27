import 'package:dio/dio.dart';

/// A single, human-readable exception type that [ApiService] throws
/// instead of raw [DioException]s. Keeps providers and widgets from
/// ever needing to know about Dio's exception hierarchy.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          'The connection timed out. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'No internet connection. Check your network and try again.',
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final serverMessage = _extractServerMessage(error.response?.data);
        if (statusCode == 404) {
          return ApiException(
            serverMessage ?? 'The requested SOS request was not found.',
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return const ApiException(
            'The server encountered an error. Please try again later.',
          );
        }
        return ApiException(
          serverMessage ?? 'The request could not be completed.',
        );
      case DioExceptionType.cancel:
        return const ApiException('The request was cancelled.');
      case DioExceptionType.badCertificate:
        return const ApiException(
          'A secure connection could not be established.',
        );
      case DioExceptionType.unknown:
        return const ApiException('An unexpected network error occurred.');
    }
  }

  static String? _extractServerMessage(dynamic data) {
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  @override
  String toString() => message;
}
