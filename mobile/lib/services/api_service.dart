import 'package:dio/dio.dart';

import '../constants/constants.dart';
import '../models/enums.dart';
import '../models/sos_request.dart';
import '../utils/api_exception.dart';

/// Thin wrapper around the ResQMesh AI backend's SOS endpoints.
/// Every method here corresponds to exactly one route in the frozen
/// OpenAPI contract - no extra endpoints, no renamed fields, no
/// invented query parameters. The base URL comes from
/// [AppConstants.baseUrl] only; it is never hardcoded here.
class ApiService {
  ApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.baseUrl,
                connectTimeout: AppConstants.apiConnectTimeout,
                receiveTimeout: AppConstants.apiReceiveTimeout,
                sendTimeout: AppConstants.apiSendTimeout,
                headers: const {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;

  /// POST /api/sos
  Future<SosRequest> createSos(SosRequestCreate payload) async {
    try {
      final response = await _dio.post('/sos', data: payload.toJson());
      return SosRequest.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// GET /api/sos
 Future<List<SosRequest>> listSos({
  SosStatus? status,
  EmergencyLevel? emergencyLevel,
  String sort = 'newest',
}) async {
  try {
    final response = await _dio.get(
      '/sos',
      queryParameters: {
        if (status != null) 'status': status.apiValue,
        if (emergencyLevel != null)
          'emergency_level': emergencyLevel.apiValue,
        'sort': sort,
      },
    );


    final data = response.data as List<dynamic>;
    return data
        .map((item) => SosRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  } on DioException catch (error) {
    throw ApiException.fromDioException(error);
  }
}

  /// GET /api/sos/{uuid}
  Future<SosRequest> getSos(String uuid) async {
    try {
      final response = await _dio.get('/sos/$uuid');
      return SosRequest.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// PUT /api/sos/{uuid}/status
  Future<SosRequest> updateSosStatus(String uuid, SosStatus status) async {
    try {
      final response = await _dio.put(
        '/sos/$uuid/status',
        data: {'status': status.apiValue},
      );
      return SosRequest.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// DELETE /api/sos/{uuid}
  Future<void> deleteSos(String uuid) async {
    try {
      await _dio.delete('/sos/$uuid');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}
