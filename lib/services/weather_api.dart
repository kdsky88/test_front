import 'dart:convert';
import 'package:http/http.dart' as http;

/// 하루치 날씨(예보).
class DailyWeather {
  final DateTime date;
  final int code; // WMO weather code
  final double tMax;
  final double tMin;

  const DailyWeather({
    required this.date,
    required this.code,
    required this.tMax,
    required this.tMin,
  });

  String get emoji => switch (code) {
        0 => '☀️',
        1 || 2 => '🌤️',
        3 => '☁️',
        45 || 48 => '🌫️',
        >= 51 && <= 57 => '🌦️',
        >= 61 && <= 67 => '🌧️',
        >= 71 && <= 77 => '❄️',
        >= 80 && <= 82 => '🌧️',
        85 || 86 => '🌨️',
        >= 95 => '⛈️',
        _ => '🌡️',
      };
}

/// 무료 open-meteo(키 불필요). 지역명 → 지오코딩 → 여행 기간 예보(최대 16일 앞).
class WeatherApi {
  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<List<DailyWeather>> forecast({
    required String region,
    DateTime? start,
    DateTime? end,
  }) async {
    // 1) 지오코딩
    final geoUri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(region)}&count=1&language=ko');
    final g = await http.get(geoUri);
    if (g.statusCode != 200) return const [];
    final results = (jsonDecode(g.body) as Map<String, dynamic>)['results'] as List?;
    if (results == null || results.isEmpty) return const [];
    final r0 = results.first as Map<String, dynamic>;
    final lat = (r0['latitude'] as num).toDouble();
    final lon = (r0['longitude'] as num).toDouble();

    // 2) 날짜 범위: [오늘, 오늘+15] 안에서 여행 기간과 겹치는 부분(최대 7일 표시).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 15));
    var from = (start != null && start.isAfter(today))
        ? DateTime(start.year, start.month, start.day)
        : today;
    if (from.isAfter(maxDate)) return const []; // 먼 미래 → 예보 없음
    var to = end != null ? DateTime(end.year, end.month, end.day) : from.add(const Duration(days: 3));
    if (to.isAfter(maxDate)) to = maxDate;
    if (to.isBefore(from)) to = from.add(const Duration(days: 2));
    if (to.difference(from).inDays > 6) to = from.add(const Duration(days: 6));

    // 3) 예보
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto'
        '&start_date=${_d(from)}&end_date=${_d(to)}');
    final f = await http.get(uri);
    if (f.statusCode != 200) return const [];
    final daily = (jsonDecode(f.body) as Map<String, dynamic>)['daily'] as Map<String, dynamic>?;
    if (daily == null) return const [];
    final times = (daily['time'] as List).cast<String>();
    final codes = daily['weathercode'] as List;
    final tmax = daily['temperature_2m_max'] as List;
    final tmin = daily['temperature_2m_min'] as List;
    return [
      for (int i = 0; i < times.length; i++)
        DailyWeather(
          date: DateTime.parse(times[i]),
          code: (codes[i] as num?)?.toInt() ?? 0,
          tMax: (tmax[i] as num?)?.toDouble() ?? 0,
          tMin: (tmin[i] as num?)?.toDouble() ?? 0,
        ),
    ];
  }
}
