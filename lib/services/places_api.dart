import 'dart:convert';
import '../models/place.dart';
import 'api_config.dart';

class PlacesApi {
  static const String baseUrl = apiBaseUrl;

  /// 지역명으로 관광지/맛집 추천. type='attraction'|'food'.
  static Future<List<Place>> recommend({
    required String region,
    required String type,
    int limit = 20,
    bool detail = false, // 설명·별점 포함(상위 티어) — 즉흥 추천 등에서만
  }) async {
    final uri = Uri.parse('$baseUrl/places/recommend').replace(queryParameters: {
      'region': region,
      'type': type,
      'limit': '$limit',
      if (detail) 'detail': 'true',
    });
    final response = await apiClient.get(uri, headers: jsonHeaders);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data'] as List)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw parseApiError(response);
  }

  /// 현재 위치 반경 추천(내 주변). type='attraction'|'food'.
  static Future<List<Place>> nearby({
    required double lat,
    required double lng,
    required String type,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/places/nearby').replace(queryParameters: {
      'lat': '$lat',
      'lng': '$lng',
      'type': type,
      'limit': '$limit',
    });
    final response = await apiClient.get(uri, headers: jsonHeaders);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data'] as List)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw parseApiError(response);
  }
}
