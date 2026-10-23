import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/trip.dart';

// 여행 상세의 일정 묶기·공유 텍스트(순수 함수, 테스트용).

final _dateFmt = DateFormat('yyyy.MM.dd');
final _dayFmt = DateFormat('M/d (E)', 'ko');
final _timeFmt = DateFormat('HH:mm');

/// 여행 기간의 날짜들(시작·종료 둘 다 있을 때만). 없으면 빈 목록 = 기간 미정.
List<DateTime> tripDays(Trip trip) {
  final s = trip.startDate, e = trip.endDate;
  if (s == null || e == null) return const [];
  final start = DateTime(s.year, s.month, s.day);
  final end = DateTime(e.year, e.month, e.day);
  return [
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) d,
  ];
}

/// 그날에 걸친 일정(시작~마감 범위가 그날을 포함), 시간순.
List<Todo> itemsOnDay(List<Todo> todos, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return todos.where((t) {
    final from = (t.startAt ?? t.dueAt)?.toLocal();
    final to = (t.dueAt ?? t.startAt)?.toLocal();
    if (from == null || to == null) return false;
    final f = DateTime(from.year, from.month, from.day);
    final tt = DateTime(to.year, to.month, to.day);
    return !d.isBefore(f) && !d.isAfter(tt);
  }).toList()
    ..sort((a, b) {
      final at = (a.startAt ?? a.dueAt);
      final bt = (b.startAt ?? b.dueAt);
      if (at == null || bt == null) return 0;
      return at.compareTo(bt);
    });
}

/// 여행 일정을 텍스트로(카톡·메시지 등 어디든 붙여넣기).
String buildTripShareText(Trip t, List<Todo> all) {
  final b = StringBuffer();
  b.writeln('✈️ ${t.title}${t.destination != null ? ' (${t.destination})' : ''}');
  if (t.startDate != null) {
    final s = _dateFmt.format(t.startDate!);
    final e = t.endDate != null ? _dateFmt.format(t.endDate!) : null;
    b.writeln('📅 ${e != null ? '$s ~ $e' : s}');
  }
  final days = tripDays(t);
  String line(Todo x) {
    final when = x.startAt ?? x.dueAt;
    final time = when != null ? '${_timeFmt.format(when.toLocal())} ' : '';
    final visited = x.completed ? '✅ ' : '';
    final place = (x.placeName != null && x.placeName != x.title) ? ' · ${x.placeName}' : '';
    return '  $visited$time${x.title}$place';
  }

  if (days.isEmpty) {
    if (all.isNotEmpty) {
      b.writeln();
      for (final x in all) {
        b.writeln(line(x));
      }
    }
  } else {
    final matched = <String>{};
    for (var i = 0; i < days.length; i++) {
      final items = itemsOnDay(all, days[i]);
      for (final x in items) {
        matched.add(x.id);
      }
      b.writeln();
      b.writeln('Day ${i + 1} · ${_dayFmt.format(days[i])}');
      if (items.isEmpty) {
        b.writeln('  (일정 없음)');
      } else {
        for (final x in items) {
          b.writeln(line(x));
        }
      }
    }
    final leftovers = all.where((x) => !matched.contains(x.id)).toList();
    if (leftovers.isNotEmpty) {
      b.writeln();
      b.writeln('그 외');
      for (final x in leftovers) {
        b.writeln(line(x));
      }
    }
  }
  b.writeln();
  b.write('— P의 여행 플래너');
  return b.toString();
}
