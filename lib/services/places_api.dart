import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place.dart';
import '../models/todo.dart'; // ApiException / ApiError
import 'api_config.dart';
import 'auth_api.dart';

class PlacesApi {
  static const String baseUrl = apiBaseUrl;

  /// 지역명으로 관광지/맛집 추천. type='attraction'|'food'.
  static Future<List<Place>> recommend({
    required String region,
    required String type,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/places/recommend').replace(queryParameters: {
      'region': region,
      'type': type,
      'limit': '$limit',
    });
    final response = await apiClient.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data'] as List)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _parseError(response);
  }

  static Map<String, String> get _headers => {
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
