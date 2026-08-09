import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/trip_api.dart';
import '../state/todo_notifier.dart';
import '../widgets/todo_form_dialog.dart';

const _sundayColor = Color(0xFFE5534B); // 일요일 빨강 (달력탭과 동일)
const _saturdayColor = Color(0xFF9AA0A6); // 토요일 회색
const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

/// 여행 기간 안에서만 날짜를 고를 수 있는 전체화면 달력(달력탭과 같은 구성).
/// 선택한 날의 일정 목록 + '이 날짜에 추가'.
class TripCalendarScreen extends StatefulWidget {
  const TripCalendarScreen({super.key, required this.trip, required this.notifier});

  final Trip trip;
  final TodoNotifier notifier;

  @override
  State<TripCalendarScreen> createState() => _TripCalendarScreenState();
}

class _TripCalendarScreenState extends State<TripCalendarScreen> {
  late int _year;
  late int _month;
  late DateTime _selectedDate;
  List<Todo>? _items;
  bool _loading = true;
  String? _error;

  bool get _hasRange =>
      widget.trip.startDate != null && widget.trip.endDate != null;
  DateTime get _rangeStart {
    final s = widget.trip.startDate!;
    return DateTime(s.year, s.month, s.day);
  }

  DateTime get _rangeEnd {
    final e = widget.trip.endDate!;
    return DateTime(e.year, e.month, e.day);
  }

  @override
  void initState() {
    super.initState();
    final base = widget.trip.startDate ?? DateTime.now();
    _year = base.year;
    _month = base.month;
    _selectedDate = DateTime(base.year, base.month, base.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await TripApi.getTripTodos(widget.trip.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '서버에 연결할 수 없습니다.';
        _loading = false;
      });
    }
  }

  bool _inRange(DateTime d) {
    if (!_hasRange) return true;
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(_rangeStart) && !day.isAfter(_rangeEnd);
  }

  List<Todo> _itemsOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return (_items ?? const []).where((t) {
      final from = (t.startAt ?? t.dueAt)?.toLocal();
      final to = (t.dueAt ?? t.startAt)?.toLocal();
      if (from == null || to == null) return false;
      final f = DateTime(from.year, from.month, from.day);
      final tt = DateTime(to.year, to.month, to.day);
      return !d.isBefore(f) && !d.isAfter(tt);
    }).toList();
  }

  bool get _canPrevMonth {
    if (!_hasRange) return true;
    return _year > _rangeStart.year ||
        (_year == _rangeStart.year && _month > _rangeStart.month);
  }

  bool get _canNextMonth {
    if (!_hasRange) return true;
    return _year < _rangeEnd.year ||
        (_year == _rangeEnd.year && _month < _rangeEnd.month);
  }

  void _prevMonth() => setState(() {
        if (_month == 1) {
          _month = 12;
          _year--;
        } else {
          _month--;
        }
      });

  void _nextMonth() => setState(() {
        if (_month == 12) {
          _month = 1;
          _year++;
        } else {
          _month++;
        }
      });

  Future<void> _addForSelected() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TodoFormDialog(
          notifier: widget.notifier,
          lockedTrip: widget.trip,
          initialDueAt: _selectedDate,
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _editItem(Todo todo) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TodoFormDialog(
          notifier: widget.notifier,
          lockedTrip: widget.trip,
          todo: todo,
        ),
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.trip.title)),
      body: Column(
        children: [
          _monthHeader(context),
          if (_loading)
            const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _grid(context),
                  const Divider(height: 1),
                  _selectedDaySection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: theme.colorScheme.primary,
            tooltip: '이전 달',
            onPressed: _canPrevMonth ? _prevMonth : null,
          ),
          Expanded(
            child: Text(
              '$_year년 $_month월',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: theme.colorScheme.primary,
            tooltip: '다음 달',
            onPressed: _canNextMonth ? _nextMonth : null,
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(_year, _month, 1);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final offset = firstDay.weekday % 7; // 일=0
    final cells = <int>[
      ...List.filled(offset, 0),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(0);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Row(
            children: List.generate(7, (i) {
              final color = i == 0
                  ? _sundayColor
                  : (i == 6 ? _saturdayColor : theme.colorScheme.onSurfaceVariant);
              return Expanded(
                child: Center(
                  child: Text(
                    _weekdays[i],
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          for (int row = 0; row < cells.length ~/ 7; row++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int c = 0; c < 7; c++)
                  Expanded(child: _dayCell(context, cells[row * 7 + c])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, int day) {
    if (day == 0) return const SizedBox(height: 64);
    final theme = Theme.of(context);
    final date = DateTime(_year, _month, day);
    final enabled = _inRange(date);
    final isSelected = _selectedDate.year == _year &&
        _selectedDate.month == _month &&
        _selectedDate.day == day;
    final now = DateTime.now();
    final isToday = now.year == _year && now.month == _month && now.day == day;

    Color? dayColor;
    if (!enabled) {
      dayColor = theme.colorScheme.onSurface.withValues(alpha: 0.4); // disabled: 어두운 배경 위 취소선
    } else if (isSelected) {
      dayColor = Colors.white;
    } else if (isToday) {
      dayColor = theme.colorScheme.primary;
    } else if (date.weekday == DateTime.sunday) {
      dayColor = _sundayColor;
    } else if (date.weekday == DateTime.saturday) {
      dayColor = _saturdayColor;
    }

    final dayItems = _itemsOn(date);
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDate = date);
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        decoration: enabled
            ? null
            : BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected && enabled ? theme.colorScheme.primary : null,
                shape: BoxShape.circle,
                border: isToday && enabled && !isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                  color: dayColor,
                  decoration: enabled ? null : TextDecoration.lineThrough,
                  decorationColor: dayColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // 일정 막대(최대 2개, 나머지는 +N) — 달력탭 느낌.
            if (enabled)
              for (int i = 0; i < dayItems.length && i < 2; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    dayItems[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
            // 나머지 항목은 아래 선택일 목록에서 확인(셀 오버플로우 방지).
          ],
        ),
      ),
    );
  }

  Widget _selectedDaySection(BuildContext context) {
    final theme = Theme.of(context);
    final items = _itemsOn(_selectedDate);
    final label = DateFormat('M월 d일 (E)', 'ko').format(_selectedDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$label 일정', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_error != null)
            Center(child: Text(_error!))
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('이 날 일정이 없어요.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            )
          else
            ...items.map((t) => _itemTile(context, t)),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _addForSelected,
            icon: const Icon(Icons.add),
            label: const Text('이 날짜에 추가'),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(BuildContext context, Todo todo) {
    final when = todo.startAt ?? todo.dueAt;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        todo.completed ? Icons.check_circle : Icons.radio_button_unchecked,
        color: todo.completed ? Colors.green : Theme.of(context).colorScheme.outline,
      ),
      title: Text(todo.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: (when == null && todo.placeName == null)
          ? null
          : Text(
              [
                if (when != null) DateFormat('HH:mm').format(when.toLocal()),
                if (todo.placeName != null) todo.placeName!,
              ].join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () => _editItem(todo),
    );
  }
}
