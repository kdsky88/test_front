import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/place.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/places_api.dart';
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

  // 여행지 추천(관광지/맛집) — 목적지 기준, 타입별 캐시로 중복 호출 방지.
  String _recoType = 'attraction';
  final Map<String, List<Place>> _recoCache = {};
  bool _recoLoading = false;
  String? _recoError;

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
    _loadRecos();
  }

  // 목적지 기준 추천 로드. 타입별 캐시 있으면 재호출 안 함(과금 절약).
  Future<void> _loadRecos() async {
    final dest = widget.trip.destination?.trim();
    if (dest == null || dest.isEmpty) return;
    if (_recoCache.containsKey(_recoType)) return;
    setState(() {
      _recoLoading = true;
      _recoError = null;
    });
    try {
      final places = await PlacesApi.recommend(region: dest, type: _recoType);
      if (!mounted) return;
      setState(() {
        _recoCache[_recoType] = places;
        _recoLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _recoError = e.error.message;
        _recoLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recoError = '추천을 불러오지 못했어요';
        _recoLoading = false;
      });
    }
  }

  void _onRecoTypeChanged(String type) {
    if (type == _recoType) return;
    HapticFeedback.selectionClick();
    setState(() {
      _recoType = type;
      _recoError = null;
    });
    _loadRecos();
  }

  // 추천 카드 → 그 장소로 일정 폼 열기(장소·제목 채워서, 선택한 날짜).
  Future<void> _addFromReco(Place place) async {
    HapticFeedback.mediumImpact();
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TodoFormDialog(
          notifier: widget.notifier,
          lockedTrip: widget.trip,
          initialDueAt: _selectedDate,
          initialTitle: place.name,
          initialPlaceName: place.name,
          initialLat: place.latitude,
          initialLng: place.longitude,
        ),
      ),
    );
    if (ok == true) _load();
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

  // 좌우 스와이프로 월 이동(여행 기간 내에서만).
  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -80 && _canNextMonth) {
      HapticFeedback.mediumImpact();
      _nextMonth();
    } else if (v > 80 && _canPrevMonth) {
      HapticFeedback.mediumImpact();
      _prevMonth();
    }
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
          // 그리드는 스크롤 밖(고정) — 세로 스크롤이 좌우 스와이프를 먹지 않게(달력탭과 동일).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: _onSwipe,
            child: _grid(context),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: _selectedDaySection(context),
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
              HapticFeedback.mediumImpact();
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
          _recoSection(theme),
        ],
      ),
    );
  }

  // 이 여행지 추천(관광지/맛집). 카드 탭 → 그 장소로 일정 폼(선택한 날짜).
  Widget _recoSection(ThemeData theme) {
    final dest = widget.trip.destination?.trim();
    if (dest == null || dest.isEmpty) return const SizedBox.shrink();
    final recos = _recoCache[_recoType];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Icon(Icons.recommend_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$dest 추천',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: 'attraction', label: Text('관광지'), icon: Icon(Icons.photo_camera_outlined, size: 18)),
            ButtonSegment(value: 'food', label: Text('맛집'), icon: Icon(Icons.restaurant_outlined, size: 18)),
          ],
          selected: {_recoType},
          onSelectionChanged: (s) => _onRecoTypeChanged(s.first),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: _recoLoading
              ? const Center(child: CircularProgressIndicator())
              : _recoError != null
                  ? Center(child: Text(_recoError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)))
                  : (recos == null || recos.isEmpty)
                      ? Center(child: Text('추천이 없어요', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) => _recoCard(theme, recos[i]),
                        ),
        ),
      ],
    );
  }

  Widget _recoCard(ThemeData theme, Place place) {
    return SizedBox(
      width: 180,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _addFromReco(place),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (place.category != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    place.category!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
                if (place.address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    place.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 15, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('일정 추가',
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
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
