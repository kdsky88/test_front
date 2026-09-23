import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'places_api.dart';

/// 커버로 못 쓰는 위키 대표 이미지(도시 문서엔 흔하다): 몽타주 콜라주, 시청 건물,
/// 지도, 깃발/문장. 작게 보면 어디인지 알아볼 수 없어서 거른다.
final _junkImage = RegExp(
  r'montage|city_hall|cityhall|coat_of_arms|wappen|flag[_.]|locator|_map|map_',
  caseSensitive: false,
);

bool isUsableCoverImage(String url) {
  final file = Uri.parse(url).pathSegments.isEmpty
      ? url
      : Uri.parse(url).pathSegments.last;
  return !_junkImage.hasMatch(file);
}

/// 목적지명 → 대표 이미지 URL(키 불필요, 위키백과).
///
/// 도시 문서의 대표 이미지는 몽타주·청사·지도인 경우가 많고 검색이 엉뚱한 문서로
/// 새기도 해서(예: '제주' → '제주 4·3 사건'), **그 지역의 대표 관광지 이름**으로 먼저
/// 찾는다(제주→만장굴, 파리→에펠탑). 관광지 목록은 백엔드가 지역별로 캐시하는
/// 기존 추천 검색을 그대로 쓴다. 실패하면 목적지명으로 폴백, 그것도 없으면 null
/// (호출부가 단색 커버로 폴백). 결과는 영구 캐시(빈="없음").
class DestinationImageApi {
  static final Map<String, String?> _mem = {};

  static Future<String?> imageUrl(String destination) async {
    final key = destination.trim();
    if (key.isEmpty) return null;
    if (_mem.containsKey(key)) return _mem[key];

    final prefs = await SharedPreferences.getInstance();
    // v2: 도시명 대신 대표 관광지로 찾도록 바뀌어서, 예전에 캐시된 엉뚱한 사진을 버린다.
    final cacheKey = 'cover_img_v2_$key';
    if (prefs.containsKey(cacheKey)) {
      final v = prefs.getString(cacheKey);
      final url = (v == null || v.isEmpty) ? null : v;
      _mem[key] = url;
      return url;
    }

    String? url;
    try {
      // 상위 몇 곳을 순서대로 — 덜 유명한 곳은 위키 문서가 없을 수 있다.
      final places = await PlacesApi.recommend(
        region: key,
        type: 'attraction',
        limit: 3,
      );
      for (final p in places.take(3)) {
        url = await _wikiThumb(p.name);
        if (url != null) break;
      }
    } catch (_) {/* 부가정보라 무시 — 아래 폴백으로 */}
    url ??= await _wikiThumb(key);

    await prefs.setString(cacheKey, url ?? ''); // 없음도 캐시(재요청 방지)
    _mem[key] = url;
    return url;
  }

  /// 위키 검색 상위 5개 중 쓸 만한 썸네일이 있는 첫 문서. origin=*는 웹 CORS용.
  static Future<String?> _wikiThumb(String query) async {
    try {
      final uri = Uri.parse('https://ko.wikipedia.org/w/api.php').replace(
        queryParameters: {
          'action': 'query',
          'format': 'json',
          'prop': 'pageimages',
          'piprop': 'thumbnail',
          'pithumbsize': '640',
          'generator': 'search',
          'gsrsearch': query,
          'gsrlimit': '5',
          'origin': '*',
        },
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final pages =
          (json['query']?['pages'] as Map<String, dynamic>?)?.values.toList() ??
          [];
      pages.sort(
        (a, b) => ((a['index'] ?? 99) as num).compareTo((b['index'] ?? 99) as num),
      );
      for (final p in pages) {
        final src = (p as Map<String, dynamic>)['thumbnail']?['source'] as String?;
        if (src != null && isUsableCoverImage(src)) return src;
      }
    } catch (_) {/* 부가정보라 무시 */}
    return null;
  }
}
