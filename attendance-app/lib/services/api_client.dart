import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import 'session_store.dart';

/// Thrown when the server rejected our token (expired / invalid).
class AuthExpiredException implements Exception {
  @override
  String toString() => 'Session expired';
}

/// Any other failure. [network] is true when the server could not be reached at all.
class ApiException implements Exception {
  ApiException(this.message, {this.code = 'error', this.network = false});
  final String message;
  final String code;
  final bool network;
  @override
  String toString() => message;
}

class ApiResponse {
  ApiResponse(this.statusCode, this.json);
  final int statusCode;
  final Map<String, dynamic> json;
  String get status => json['status'] as String? ?? '';
  String get message => json['message'] as String? ?? '';
}

/// All HTTP traffic goes through here. Flutter never talks to MongoDB directly.
class ApiClient {
  ApiClient(this._store) {
    _dio = Dio(BaseOptions(
      baseUrl: _normalize(_store.serverUrl),
      connectTimeout: AppConfig.requestTimeout,
      sendTimeout: AppConfig.requestTimeout,
      receiveTimeout: AppConfig.requestTimeout,
      contentType: 'application/json',
      // 4xx are meaningful answers (404 not_registered, 409 already_attended); handled below.
      validateStatus: (s) => s != null && s < 500,
    ));
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      final token = _store.session?.token;
      if (token != null && o.extra['auth'] != false) o.headers['Authorization'] = 'Bearer $token';
      h.next(o);
    }));
  }

  final SessionStore _store;
  late final Dio _dio;

  /// True after the last request failed to reach the server.
  final ValueNotifier<bool> offline = ValueNotifier(false);

  static String _normalize(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  void setBaseUrl(String url) => _dio.options.baseUrl = _normalize(url);

  Future<ApiResponse> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    try {
      debugPrint('[API REQUEST] $method ${_dio.options.baseUrl}$path | Data: $data');
      final res = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, extra: {'auth': auth}),
      );
      debugPrint('[API RESPONSE] ${res.statusCode} from $path | Body: ${res.data}');
      offline.value = false;
      final body = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final code = res.statusCode ?? 0;
      if (code == 401 && auth) throw AuthExpiredException();
      return ApiResponse(code, body);
    } on DioException catch (e) {
      debugPrint('[API ERROR] ${e.type} -> ${e.message} (cause: ${e.error}) | Response: ${e.response?.data}');
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          offline.value = true;
          throw ApiException('Cannot reach the server. Check your internet connection.', code: 'network', network: true);
        default:
          offline.value = false;
          throw ApiException('The server had a problem. Please try again.', code: 'server_error');
      }
    }
  }

  Future<({Session session, String role})> login(String operatorId, String password) async {
    debugPrint('[LOGIN] Attempting login to: ${_dio.options.baseUrl}/api/auth/login with operatorId: "$operatorId" (pwd len: ${password.length})');
    final res = await _request('POST', '/api/auth/login',
        data: {'operatorId': operatorId, 'password': password}, auth: false);
    if (res.statusCode != 200) {
      debugPrint('[LOGIN FAILED] Server returned: status=${res.statusCode}, message="${res.message}", code="${res.status}"');
      throw ApiException(
        res.statusCode == 401 || res.statusCode == 429 || res.statusCode == 400
            ? (res.message.isNotEmpty ? res.message : 'Could not sign in.')
            : 'Could not sign in.',
        code: res.status,
      );
    }
    final op = res.json['operator'] as Map<String, dynamic>;
    return (
      session: Session(
        token: res.json['token'] as String,
        operatorId: op['operatorId'] as String,
        displayName: op['displayName'] as String? ?? '',
      ),
      role: op['role'] as String? ?? '',
    );
  }

  Future<EventInfo> fetchEvent() async {
    final res = await _request('GET', '/api/events/${AppConfig.eventId}');
    if (res.statusCode != 200) throw ApiException(res.message, code: res.status);
    return EventInfo.fromJson(res.json['event'] as Map<String, dynamic>);
  }

  Future<AttendanceStats> fetchStats() async {
    final res = await _request('GET', '/api/events/${AppConfig.eventId}/attendance/stats');
    if (res.statusCode != 200) throw ApiException(res.message, code: res.status);
    return AttendanceStats.fromJson(res.json);
  }

  /// Returns the raw response: 201 marked, 409 already_attended, 404 not_registered, 400 invalid.
  Future<ApiResponse> markAttendance({required String srn, required String deviceId, DateTime? scannedAt}) {
    return _request('POST', '/api/events/${AppConfig.eventId}/attendance', data: {
      'srn': srn,
      'deviceId': deviceId,
      if (scannedAt != null) 'scannedAt': scannedAt.toUtc().toIso8601String(),
    });
  }

  Future<AttendancePage> listAttendance({
    required int page,
    String search = '',
    String filter = 'all',
  }) async {
    final res = await _request('GET', '/api/events/${AppConfig.eventId}/attendance', query: {
      'page': page,
      'limit': AppConfig.recordsPageSize,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'filter': filter,
    });
    if (res.statusCode != 200) throw ApiException(res.message.isEmpty ? 'Could not load records.' : res.message, code: res.status);
    return AttendancePage(
      items: (res.json['items'] as List).map((e) => AttendanceRecord.fromJson({
            ...(e as Map<String, dynamic>),
          })).toList(),
      hasMore: res.json['hasMore'] as bool? ?? false,
      total: (res.json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>> fetchSnapshotPage({String? updatedSince, String? afterId}) async {
    final res = await _request('GET', '/api/participants/snapshot', query: {
      'limit': 1000,
      'updatedSince': ?updatedSince,
      'afterId': ?afterId,
    });
    if (res.statusCode != 200) throw ApiException(res.message, code: res.status);
    return res.json;
  }
}
