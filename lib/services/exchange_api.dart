import 'dart:convert';
import 'package:http/http.dart' as http;

class ExchangeRates {
  final String base;
  final Map<String, double> rates; // 1 base = rates[code] (해당 통화)
  final String date;
  const ExchangeRates({required this.base, required this.rates, required this.date});

  double? rateTo(String code) => rates[code];
}

/// 무료 환율(open.er-api.com, 키 불필요). base 기준 전 통화 환율.
class ExchangeApi {
  /// 실패(오프라인·타임아웃·형식 오류)는 null — 화면은 '불러오지 못했어요'로 처리.
  static Future<ExchangeRates?> fetch(String base) async {
    try {
      return await _fetch(base);
    } catch (_) {
      return null;
    }
  }

  static Future<ExchangeRates?> _fetch(String base) async {
    final res = await http
        .get(Uri.parse('https://open.er-api.com/v6/latest/$base'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['result'] != 'success') return null;
    final raw = j['rates'] as Map<String, dynamic>;
    final rates = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    final date = (j['time_last_update_utc'] as String?) ?? '';
    return ExchangeRates(base: base, rates: rates, date: date.length >= 16 ? date.substring(0, 16) : date);
  }
}
