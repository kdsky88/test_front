import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 목적지명 → 대표 이미지 URL. Wikipedia REST 요약(키 불필요).
/// 부가정보라 실패하면 null(호출부가 단색 커버로 폴백). 결과는 영구 캐시(빈="없음").
class DestinationImageApi {
  static final Map<String, String?> _mem = {};

  static Future<String?> imageUrl(String destination) async {
    final key = destination.trim();
    if (key.isEmpty) return null;
    if (_mem.containsKey(key)) return _mem[key];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cover_img_$key';
    if (prefs.containsKey(cacheKey)) {
      final v = prefs.getString(cacheKey);
      final url = (v == null || v.isEmpty) ? null : v;
      _mem[key] = url;
      return url;
    }

    String? url;
    try {
      // 검색으로 대표 문서를 찾아 그 페이지 이미지를 가져온다(동음이의 페이지는
      // 썸네일이 없으므로 상위 5개 중 썸네일 있는 첫 결과를 쓴다). origin=*는 웹 CORS용.
      final uri = Uri.parse('https://ko.wikipedia.org/w/api.php').replace(queryParameters: {
        'action': 'query',
        'format': 'json',
        'prop': 'pageimages',
        'piprop': 'thumbnail',
        'pithumbsize': '640',
        'generator': 'search',
        'gsrsearch': key,
        'gsrlimit': '5',
        'origin': '*',
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final pages = (json['query']?['pages'] as Map<String, dynamic>?)?.values.toList() ?? [];
        pages.sort((a, b) =>
            ((a['index'] ?? 99) as num).compareTo((b['index'] ?? 99) as num));
        for (final p in pages) {
          final src = (p as Map<String, dynamic>)['thumbnail']?['source'] as String?;
          if (src != null) {
            url = src;
            break;
          }
        }
      }
    } catch (_) {/* 부가정보라 무시 */}

    await prefs.setString(cacheKey, url ?? ''); // 없음도 캐시(재요청 방지)
    _mem[key] = url;
    return url;
  }
}
