import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodeResult {
  final String displayName; // 전체 주소(검색 목록 표시용)
  final double lat;
  final double lon;

  const GeocodeResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  /// 저장/뱃지용 짧은 이름: 전체 주소의 첫 구간.
  String get shortName => displayName.split(',').first.trim();
}

/// OSM Nominatim 지오코딩(무료, API 키 불필요).
/// 정책: User-Agent 필수, 초당 1회 → 호출부에서 디바운스할 것.
/// 웹은 브라우저가 User-Agent를 대신 채우므로 헤더 설정은 네이티브(APK)용.
class GeocodingApi {
  static Future<List<GeocodeResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {'q': q, 'format': 'json', 'limit': '5'},
    );
    final res = await http.get(uri, headers: {
      'User-Agent': 'test-todo-app/1.0 (kdsky88@gmail.com)',
      'Accept': 'application/json',
    });
    if (res.statusCode != 200) return const [];
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) {
          final m = e as Map<String, dynamic>;
          return GeocodeResult(
            displayName: m['display_name'] as String? ?? '',
            // Nominatim은 lat/lon을 문자열로 반환.
            lat: double.tryParse(m['lat']?.toString() ?? '') ?? 0,
            lon: double.tryParse(m['lon']?.toString() ?? '') ?? 0,
          );
        })
        .where((r) => r.displayName.isNotEmpty)
        .toList();
  }
}
