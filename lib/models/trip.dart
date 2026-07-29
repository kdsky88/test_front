class Trip {
  final String id;
  final String title;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;

  const Trip({
    required this.id,
    required this.title,
    this.destination,
    this.startDate,
    this.endDate,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    title: json['title'] as String,
    destination: json['destination'] as String?,
    startDate: _parseDate(json['startDate']),
    endDate: _parseDate(json['endDate']),
  );

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return null;
    }
  }

  /// 여행 기간 D-day. 시작 전이면 "D-n", 여행 중이면 "여행 중", 끝났으면 "종료", 날짜 없으면 null.
  String? get dDayLabel {
    if (startDate == null) return null;
    final today = DateTime.now();
    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final now = DateTime(today.year, today.month, today.day);
    final days = start.difference(now).inDays;
    if (days > 0) return 'D-$days';
    final end = endDate == null ? start : DateTime(endDate!.year, endDate!.month, endDate!.day);
    if (!now.isAfter(end)) return '여행 중';
    return '종료';
  }
}
