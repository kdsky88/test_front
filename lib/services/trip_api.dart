import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/todo.dart';
import '../models/trip.dart';
import 'api_config.dart';
import 'auth_api.dart';
import 'offline_cache.dart';

class TripApi {
  static const String baseUrl = apiBaseUrl;

  static Future<List<Trip>> getTrips() async {
    final owner = AuthSession.currentEmail;
    final generation = AuthSession.generation;
    final response = await apiClient.get(
      Uri.parse('$baseUrl/trips'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      if (owner != null && generation == AuthSession.generation) {
        await OfflineCache.putTrips(owner, response.body);
      }
      return _parseTrips(response.body);
    }
    throw _parseError(response);
  }

  /// 네트워크 실패 시 마지막으로 받은 여행 목록(없으면 빈 리스트).
  static Future<List<Trip>> cachedTrips() async {
    final owner = AuthSession.currentEmail;
    if (owner == null) return const [];
    final body = await OfflineCache.getTrips(owner);
    return body == null ? const [] : _parseTrips(body);
  }

  static List<Trip> _parseTrips(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Todo>> getTripTodos(String id) async {
    final owner = AuthSession.currentEmail;
    final generation = AuthSession.generation;
    final response = await apiClient.get(
      Uri.parse('$baseUrl/trips/$id/todos'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      if (owner != null && generation == AuthSession.generation) {
        await OfflineCache.putTripTodos(owner, id, response.body);
      }
      return _parseTodos(response.body);
    }
    throw _parseError(response);
  }

  /// 네트워크 실패 시 그 여행의 마지막 일정(없으면 빈 리스트).
  static Future<List<Todo>> cachedTripTodos(String id) async {
    final owner = AuthSession.currentEmail;
    if (owner == null) return const [];
    final body = await OfflineCache.getTripTodos(owner, id);
    return body == null ? const [] : _parseTodos(body);
  }

  static List<Todo> _parseTodos(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => Todo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Trip> createTrip({
    required String title,
    String? destination,
    String? startDate, // yyyy-MM-dd
    String? endDate,
  }) async {
    final body = <String, dynamic>{'title': title};
    if (destination != null && destination.isNotEmpty) {
      body['destination'] = destination;
    }
    if (startDate != null) body['startDate'] = startDate;
    if (endDate != null) body['endDate'] = endDate;

    final response = await apiClient.post(
      Uri.parse('$baseUrl/trips'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Trip.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw _parseError(response);
  }

  static Future<Trip> updateTrip(
    String id, {
    required String title,
    String? destination,
    String? startDate, // yyyy-MM-dd
    String? endDate,
  }) async {
    // 편집 폼은 항상 모든 필드를 보내므로 present 플래그를 전부 켜서 전송(빈 목적지는 해제).
    final body = <String, dynamic>{
      'title': title,
      'destination': destination ?? '',
      'startDate': startDate,
      'endDate': endDate,
    };
    final response = await apiClient.patch(
      Uri.parse('$baseUrl/trips/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Trip.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw _parseError(response);
  }

  static Future<void> deleteTrip(String id) async {
    final response = await apiClient.delete(
      Uri.parse('$baseUrl/trips/$id'),
      headers: _headers,
    );
    if (response.statusCode == 204) return;
    throw _parseError(response);
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (AuthSession.accessToken case final token?)
      'Authorization': 'Bearer $token',
  };

  static ApiException _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        statusCode: response.statusCode,
        error: ApiError.fromJson(json),
      );
    } catch (_) {
      return ApiException(
        statusCode: response.statusCode,
        error: ApiError(code: 'INTERNAL_ERROR', message: '서버 응답을 처리할 수 없습니다.'),
      );
    }
  }
}
