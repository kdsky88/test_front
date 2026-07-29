import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/todo.dart';
import '../models/trip.dart';
import 'api_config.dart';
import 'auth_api.dart';

class TripApi {
  static const String baseUrl = apiBaseUrl;

  static Future<List<Trip>> getTrips() async {
    final response = await apiClient.get(
      Uri.parse('$baseUrl/trips'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data'] as List)
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _parseError(response);
  }

  static Future<List<Todo>> getTripTodos(String id) async {
    final response = await apiClient.get(
      Uri.parse('$baseUrl/trips/$id/todos'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data'] as List)
          .map((e) => Todo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _parseError(response);
  }

  static Future<Trip> createTrip({
    required String title,
    String? destination,
    String? startDate, // yyyy-MM-dd
    String? endDate,
  }) async {
    final body = <String, dynamic>{'title': title};
    if (destination != null && destination.isNotEmpty) body['destination'] = destination;
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
