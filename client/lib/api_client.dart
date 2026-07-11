import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper over Dio that handles JWT storage and JSON (de)serialization.
class ApiClient {
  ApiClient() : _dio = Dio(BaseOptions(baseUrl: resolveApiBaseUrl())) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'access_token';

  // ---- token helpers ----
  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> _saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  String _friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach the server. Is the API running?';
      }
      return e.message ?? 'Request failed';
    }
    return e.toString();
  }

  // ---- auth ----
  Future<void> signup(String email, String password) async {
    try {
      final res = await _dio.post('/auth/signup',
          data: {'email': email, 'password': password});
      await _saveToken(res.data['access_token'] as String);
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'username': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      await _saveToken(res.data['access_token'] as String);
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ---- vehicles ----
  Future<List<Vehicle>> listVehicles() async {
    try {
      final res = await _dio.get('/vehicles');
      return (res.data as List)
          .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  Future<Vehicle> createVehicle(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/vehicles', data: body);
      return Vehicle.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  Future<void> deleteVehicle(int id) async {
    try {
      await _dio.delete('/vehicles/$id');
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ---- fillups ----
  Future<List<Fillup>> listFillups(int vehicleId) async {
    try {
      final res = await _dio.get('/vehicles/$vehicleId/fillups');
      return (res.data as List)
          .map((e) => Fillup.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  Future<void> createFillup(int vehicleId, Map<String, dynamic> body) async {
    try {
      await _dio.post('/vehicles/$vehicleId/fillups', data: body);
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  Future<void> deleteFillup(int vehicleId, int fillupId) async {
    try {
      await _dio.delete('/vehicles/$vehicleId/fillups/$fillupId');
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ---- services ----
  Future<List<ServiceRecord>> listServices(int vehicleId) async {
    try {
      final res = await _dio.get('/vehicles/$vehicleId/services');
      return (res.data as List)
          .map((e) => ServiceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  Future<void> createService(int vehicleId, Map<String, dynamic> body) async {
    try {
      await _dio.post('/vehicles/$vehicleId/services', data: body);
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  Future<void> deleteService(int vehicleId, int serviceId) async {
    try {
      await _dio.delete('/vehicles/$vehicleId/services/$serviceId');
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ---- reminders ----
  Future<List<ReminderStatus>> reminderStatus(int vehicleId) async {
    try {
      final res = await _dio.get('/vehicles/$vehicleId/reminders/status');
      return (res.data as List)
          .map((e) => ReminderStatus.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ---- stats ----
  Future<VehicleStats> stats(int vehicleId) async {
    try {
      final res = await _dio.get('/vehicles/$vehicleId/stats');
      return VehicleStats.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }
}
