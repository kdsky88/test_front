import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/place.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/map_links.dart';
import '../services/places_api.dart';
import '../services/todo_api.dart';
import '../services/weather_api.dart';
import '../state/todo_notifier.dart';
import '../state/trip_detail_notifier.dart';
import '../theme.dart';
import '../widgets/todo_form_dialog.dart';
import '../widgets/offline_banner.dart';
import '../widgets/travel_card.dart';
import '../widgets/course_save_dialog.dart';
import '../widgets/recommendation_action.dart';
import '../services/day_course.dart';
import '../services/trip_schedule.dart';
import '../widgets/day_course_sheet.dart';
import '../widgets/surprise_place_sheet.dart';
import '../widgets/trip_item_card.dart';
import '../widgets/trip_overview.dart';
import 'currency_screen.dart';
import 'expenses_screen.dart';
import 'trip_calendar_screen.dart';
import 'trip_map_screen.dart';
import 'trip_preview_screen.dart';

final _dateFmt = DateFormat('yyyy.MM.dd');
final _dayFmt = DateFormat('M/d (E)', 'ko');
final _timeFmt = DateFormat('HH:mm');

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.trip, required this.notifier, this.detail});

  final Trip trip;
  final TodoNotifier notifier;
  final TripDetailNotifier? detail;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final TripDetailNotifier _detail;
  List<Todo>? get _todos => _detail.todos;
  set _todos(List<Todo>? value) => _detail.todos = value;
  bool get _loading => _detail.loading;
  bool get _offline => _detail.offline;
  String? get _error => _detail.error;

  // 즉흥 추천("아무거나") — 목적지 추천을 타입별 캐시.
  final _rng = Random();
  bool _courseSaving = false;
  final Map<String, List<Place>> _recoCache = {};

  // 목적지 날씨(open-meteo). null=미로드/없음.
  List<DailyWeather>? _weather;

  @override
  void initState() {
    super.initState();
    _detail = (widget.detail ?? TripDetailNotifier(widget.trip.id))..addListener(_onDetailChanged);
    _load();
    _loadWeather();
  }

  // 목적지 날씨(부가 정보라 실패해도 조용히 무시).
  Future<void> _loadWeather() async {
    final dest = widget.trip.destination?.trim();
    if (dest == null || dest.isEmpty) return;
    try {
      final w = await WeatherApi.forecast(
        region: dest,
        start: widget.trip.startDate,
        end: widget.trip.endDate,
      );
      if (mounted) setState(() => _weather = w);
    } catch (_) {
      /* 무시 */
    }
  }

  void _onDetailChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() => _detail.load();

  @override
  void dispose() {
    _detail.removeListener(_onDetailChanged);
    if (widget.detail == null) _detail.dispose(); // 주입받은 건 넘겨준 쪽이 정리
    super.dispose();
  }

  bool _requireConnection() {
    if (!_offline) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('오프라인에서는 저장된 일정만 볼 수 있어요.'),
      action: SnackBarAction(label: '다시 연결', onPressed: _load),
    ));
    return false;
  }

  Future<void> _addItem() async {
    if (!_requireConnection()) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TodoFormDialog(
        notifier: widget.notifier, lockedTrip: widget.trip,
        initialDueAt: widget.trip.isActiveOn(DateTime.now()) ? DateTime.now() : widget.trip.startDate,
      )),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _editItem(Todo todo) async {
    if (!_requireConnection()) return;
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

  Future<void> _deleteItem(Todo todo) async {
    if (!_requireConnection()) return;
    HapticFeedback.mediumImpact();
    // 낙관적: 목록에서 즉시 빼고 스낵바도 바로 띄운다(서버 응답 안 기다림). refetch 안 함.
    setState(() => _todos = (_todos ?? const []).where((t) => t.id != todo.id).toList());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text("'${todo.title}' 삭제됨"),
        action: SnackBarAction(
          label: '실행취소',
          onPressed: () async {
            final error = await widget.notifier.restoreTodo(todo);
            if (!mounted) return;
            _load();
            if (error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('복원하지 못했어요. $error')),
              );
            }
          },
        ),
      ));
    // 서버 삭제는 백그라운드. 실패했을 때만 원복 + 에러 안내.
    final deleted = await widget.notifier.deleteTodo(todo.id);
    if (!mounted || deleted) return;
    _load();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('삭제에 실패했어요.')));
  }

  // 방문 체크 = 그 일정 완료 토글(completed 재사용). 낙관적 반영 후 서버 반영.
  Future<void> _toggleVisited(Todo todo) async {
    if (!_requireConnection()) return;
    HapticFeedback.mediumImpact();
    final want = !todo.completed;
    setState(() {
      final i = _todos?.indexWhere((t) => t.id == todo.id) ?? -1;
      if (i >= 0) _todos![i] = _todos![i].copyWith(completed: want);
    });
    try {
      await TodoApi.updateTodo(id: todo.id, completed: want);
      widget.notifier.loadTodos(silent: true); // 다른 탭 동기화
    } catch (_) {
      if (mounted) {
        _load(); // 실패 시 서버 상태로 되돌림
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('반영하지 못했어요')));
      }
    }
  }

  // 여행 일정을 텍스트로 공유(카톡·메시지 등 어디든 붙여넣기).
  void _shareTrip() {
    HapticFeedback.selectionClick();
    SharePlus.instance.share(ShareParams(
        text: buildTripShareText(widget.trip, _todos ?? const []), subject: widget.trip.title));
  }

  List<DateTime> get _days => tripDays(widget.trip);

  List<Todo> _itemsOn(DateTime day) => itemsOnDay(_todos ?? const [], day);

  @override
  Widget build(BuildContext context) {
    final cover = AppTheme.coverFor(widget.trip.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.title),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '날짜별 일정 편집',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              if (!_requireConnection()) return;
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TripCalendarScreen(trip: widget.trip, notifier: widget.notifier),
              ));
              if (mounted) _load();
            },
          ),
          // 도구(공유·경비·환율)는 계획 화면과 안 섞이게 한 메뉴로 묶음.
          PopupMenuButton<String>(
            tooltip: '여행 도구',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'share':
                  _shareTrip();
                case 'expenses':
                  if (!_requireConnection()) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExpensesScreen(
                        tripId: widget.trip.id, tripTitle: widget.trip.title),
                  ));
                case 'currency':
                  if (!_requireConnection()) return;
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CurrencyScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.ios_share),
                  title: Text('공유'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'expenses',
                child: ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('경비'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'currency',
                child: ListTile(
                  leading: Icon(Icons.currency_exchange),
                  title: Text('환율'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _offline ? null : _addItem,
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(cover)),
    );
  }

  Widget _buildBody(Color cover) {
    // 첫 로딩만 전체 스피너. 재로딩은 기존 내용을 유지(깜빡임 방지).
    if (_loading && _todos == null) {
      return ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]);
    }
    if (_error != null) {
      return ListView(children: [
        if (_offline) OfflineBanner(lastSynced: _detail.lastSynced, onRetry: _load, retrying: _loading),
        _hero(cover),
        const SizedBox(height: 80),
        Center(child: Text(_error!)),
        const SizedBox(height: 12),
        Center(child: OutlinedButton(onPressed: _load, child: const Text('다시 시도'))),
      ]);
    }

    final days = _days;
    final today = DateUtils.dateOnly(DateTime.now());
    final active = widget.trip.isActiveOn(today);
    final children = <Widget>[];
    if (_offline) {
      children.add(OfflineBanner(
        lastSynced: _detail.lastSynced, onRetry: _load, retrying: _loading,
      ));
    }
    if (active) {
      children.add(_sectionHeader('오늘 일정', _dayFmt.format(today), cover));
      final todayItems = _itemsOn(today);
      if (todayItems.isEmpty) {
        children.add(const Padding(padding: EdgeInsets.all(16),
          child: Text('오늘은 비어 있어요. 장소를 추천받거나 일정을 직접 추가해보세요.')));
        children.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(onPressed: _offline ? null : _addItem,
            icon: const Icon(Icons.add), label: const Text('오늘 일정 추가'))));
      } else {
        final next = todayItems.where((t) => !t.completed && t.latitude != null && t.longitude != null).firstOrNull;
        if (next != null) { children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            onPressed: _offline ? null : () => openInGoogleMaps(
              lat: next.latitude!, lng: next.longitude!, directions: true),
            icon: const Icon(Icons.directions),
            label: Text('다음 장소 길찾기 · ${next.title}'),
          ),
        )); }
        children.addAll(todayItems.map(_itemCard));
      }
    }
    children.add(_hero(cover));
    children.add(_actionButtons());
    final located = _located;
    children.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(child: ExpansionTile(
      title: const Text('지도 · 날씨 · 여행 기록'),
      initiallyExpanded: !active,
      children: [
        // 여행 기록: 방문(완료)한 장소 수 / 전체 장소 수.
        TripRecordBar(visited: located.where((t) => t.completed).length, total: located.length),
        TripWeatherStrip(weather: _weather),
        if (located.isNotEmpty) ...[
          TextButton.icon(onPressed: _openPreview,
            icon: const Icon(Icons.slideshow_outlined), label: const Text('여행 미리보기')),
          TripMapCard(located: located, onPinTap: _showPlace, onFullscreen: _openMap),
        ],
      ],
    ))));
    if (!active && (_todos ?? const []).isEmpty && days.isNotEmpty) children.add(_emptyState());

    if (days.isEmpty) {
      // 기간 미정: 전체 항목을 한 목록으로.
      final all = _todos ?? const [];
      if (all.isEmpty) {
        children.add(_emptyState());
      } else {
        children.addAll(all.map(_itemCard));
      }
    } else {
      final matched = <String>{};
      for (var i = 0; i < days.length; i++) {
        final items = _itemsOn(days[i]);
        for (final t in items) {
          matched.add(t.id);
        }
        if (!active || !DateUtils.isSameDay(days[i], today)) {
          children.add(_daySection(i + 1, days[i], items, cover));
        }
      }
      // 기간에 안 잡힌 항목(날짜 없음 등)은 '그 외'로.
      final leftovers = (_todos ?? const []).where((t) => !matched.contains(t.id)).toList();
      if (leftovers.isNotEmpty) {
        children.add(_sectionHeader('그 외', null, cover));
        children.addAll(leftovers.map(_itemCard));
      }
    }

    children.add(const SizedBox(height: 88)); // FAB 여백
    return ListView(padding: const EdgeInsets.only(bottom: 8), children: children);
  }

  Widget _hero(Color cover) {
    final t = widget.trip;
    final dday = t.dDayLabel;
    final range = () {
      if (t.startDate == null && t.endDate == null) return '기간 미정';
      final s = t.startDate == null ? '?' : _dateFmt.format(t.startDate!);
      final e = t.endDate == null ? '?' : _dateFmt.format(t.endDate!);
      return t.startDate != null && t.endDate == null ? s : '$s ~ $e';
    }();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: TravelCard(
        title: t.title,
        destination: t.destination?.isNotEmpty == true ? t.destination! : t.title,
        imageDestination: t.destination ?? '',
        dateLabel: range,
        status: dday,
        cover: cover,
      ),
    );
  }

  List<Todo> get _located =>
      (_todos ?? const []).where((t) => t.latitude != null && t.longitude != null).toList();

  void _openMap({String? focusId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TripMapScreen(
        title: widget.trip.title,
        located: _located,
        focusId: focusId,
      ),
    ));
  }

  // 미리보기: 위치 있는 일정을 시간순(시간 없는 건 뒤로)으로 넘겨본다.
  void _openPreview() {
    final stops = _located
      ..sort((a, b) {
        final at = a.startAt ?? a.dueAt;
        final bt = b.startAt ?? b.dueAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1; // 시간 없는 건 뒤로
        if (bt == null) return -1;
        return at.compareTo(bt);
      });
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TripPreviewScreen(title: widget.trip.title, stops: stops),
    ));
  }

  Future<List<Place>?> _recosFor(String type) async {
    if (_recoCache.containsKey(type)) return _recoCache[type];
    final dest = widget.trip.destination?.trim();
    if (dest == null || dest.isEmpty) return null;
    try {
      // 즉흥 추천은 설명·별점 포함(detail).
      final places = await PlacesApi.recommend(region: dest, type: type, detail: true);
      _recoCache[type] = places;
      return places;
    } catch (_) {
      return null;
    }
  }

  // 즉흥 추천: 관광지/맛집 중 랜덤 타입 → 랜덤 1곳.
  Future<void> _surprise() async {
    if (!_requireConnection()) return;
    final dest = widget.trip.destination?.trim();
    if (dest == null || dest.isEmpty) return;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    var type = _rng.nextBool() ? 'attraction' : 'food';
    var places = await _recosFor(type);
    if (places == null || places.isEmpty) {
      type = type == 'attraction' ? 'food' : 'attraction';
      places = await _recosFor(type);
    }
    if (mounted) Navigator.of(context).pop(); // 로딩 닫기
    if (!mounted) return;
    if (places == null || places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추천을 불러오지 못했어요')),
      );
      return;
    }
    _showSurprise(places[_rng.nextInt(places.length)]);
  }

  void _showSurprise(Place initial) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SurprisePlaceSheet(
        initial: initial,
        recos: _recosFor,
        rng: _rng,
        onAdd: _addFromSurprise,
      ),
    );
  }

  // 일정 담을 날짜 선택(여행 기간으로 제한, 기간 없으면 넓게). 취소면 null.
  Future<DateTime?> _pickTripDay() async {
    final s = widget.trip.startDate, e = widget.trip.endDate;
    final now = DateTime.now();
    final first = DateTime((s ?? DateTime(now.year - 1)).year, (s ?? DateTime(now.year - 1)).month, (s ?? DateTime(now.year - 1)).day);
    final last = DateTime((e ?? DateTime(now.year + 5)).year, (e ?? DateTime(now.year + 5)).month, (e ?? DateTime(now.year + 5)).day);
    var initial = s ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: '일정 날짜 선택',
    );
  }

  Future<void> _addFromSurprise(Place p) async {
    if (!_requireConnection()) return;
    final day = await _pickTripDay();
    if (day == null || !mounted) return;
    Navigator.of(context).pop(); // 시트 닫기
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TodoFormDialog(
        notifier: widget.notifier,
        lockedTrip: widget.trip,
        initialTitle: p.name,
        initialPlaceName: p.name,
        initialLat: p.latitude,
        initialLng: p.longitude,
        initialDueAt: day,
      ),
    ));
    if (ok == true) _load();
  }

  Widget _actionButtons() {
    final dest = widget.trip.destination?.trim();
    if (dest == null || dest.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: RecommendationAction(title: '장소 추천', subtitle: '마음에 드는 한 곳 발견하기',
          icon: Icons.explore_outlined, onTap: _offline ? null : _surprise)),
        const SizedBox(width: 12),
        Expanded(child: RecommendationAction(title: '하루 코스', subtitle: '관광지와 맛집을 한 번에',
          icon: Icons.route_outlined, primary: true, onTap: _offline ? null : _course)),
      ])),
    );
  }

  // 하루 코스: 관광지/맛집을 anchor 근처로 묶어 시간대별.
  Future<void> _course() async {
    if (!_requireConnection()) return;
    final dest = widget.trip.destination?.trim();
    if (dest == null || dest.isEmpty) return;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final attractions = await _recosFor('attraction') ?? const [];
    final foods = await _recosFor('food') ?? const [];
    if (mounted) Navigator.of(context).pop();
    if (!mounted) return;
    if (attractions.isEmpty && foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추천을 불러오지 못했어요')));
      return;
    }
    _showCourse(_buildCourse(attractions, foods));
  }

  List<(String, Place)> _buildCourse(List<Place> attractions, List<Place> foods) =>
      buildDayCourse(attractions, foods,
          distance: Geolocator.distanceBetween, rng: _rng);

  void _showCourse(List<(String, Place)> initial) {
    if (initial.isEmpty) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // 지도 + 6곳이라 기본 높이로는 모자람
      builder: (_) => DayCourseSheet(
        initial: initial,
        rebuild: () => _buildCourse(
          _recoCache['attraction'] ?? const [],
          _recoCache['food'] ?? const [],
        ),
        onAdd: _addCourse,
      ),
    );
  }

  Future<void> _addCourse(List<(String, Place)> stops) async {
    if (!_requireConnection() || _courseSaving) return;
    _courseSaving = true;
    try {
    final day = await _pickTripDay();
    if (day == null || !mounted) return;
    Navigator.of(context).pop(); // 시트 닫기
    int hourFor(String slot) => switch (slot) {
          '점심' => 12,
          '저녁' => 19,
          _ => 9, // 아침
        };
    // 같은 슬롯이 2곳이라 두 번째는 +1시간(타임라인에서 겹치지 않게).
    int hourAt(int i) {
      final slot = stops[i].$1;
      return hourFor(slot) + stops.take(i).where((s) => s.$1 == slot).length;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CourseSaveDialog(
        names: stops.map((stop) => stop.$2.name).toList(),
        save: (index) {
          final place = stops[index].$2;
          final at = DateTime(day.year, day.month, day.day, hourAt(index));
          return widget.notifier.createTodo(
            title: place.name,
            priority: TodoPriority.medium,
            tripId: widget.trip.id,
            startAt: at.toUtc().toIso8601String(),
            latitude: place.latitude,
            longitude: place.longitude,
            placeName: place.name,
          );
        },
      ),
    );
    if (mounted) _load();
    } finally {
      _courseSaving = false;
    }
  }

  void _showPlace(Todo todo) {
    final when = todo.startAt ?? todo.dueAt;
    final time = when != null ? '${_timeFmt.format(when.toLocal())}  ' : '';
    // 장소명이 제목과 다르면 둘 다, 같으면(발견 저장 등) 하나만.
    final label = (todo.placeName != null && todo.placeName != todo.title)
        ? '${todo.title} · ${todo.placeName}'
        : todo.title;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('📍 $time$label'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(label: '수정', onPressed: () => _editItem(todo)),
      ));
  }

  Widget _daySection(int dayNo, DateTime date, List<Todo> items, Color cover) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Day $dayNo', _dayFmt.format(date), cover),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('일정 없음',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          )
        else
          ...items.map(_itemCard),
      ],
    );
  }

  Widget _sectionHeader(String badge, String? sub, Color cover) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 6, children: [
        Text(badge, style: theme.textTheme.titleMedium),
        if (sub != null) Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _itemCard(Todo todo) => TripItemCard(
        todo: todo,
        offline: _offline,
        // 탭 = 지도(장소 있을 때), 없으면 수정. 수정은 우측 메뉴로.
        onTap: () => todo.latitude != null ? _openMap(focusId: todo.id) : _editItem(todo),
        onToggleVisited: () => _toggleVisited(todo),
        onEdit: () => _editItem(todo),
        onDelete: () => _deleteItem(todo),
      );

  Widget _emptyState() {
    final theme = Theme.of(context);
    final hasDest = widget.trip.destination?.trim().isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 56, bottom: 8),
      child: Column(
        children: [
          Text('🗓️', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('아직 일정이 없어요',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            hasDest ? "위에서 장소나 하루 코스를 추천받거나 직접 추가해보세요." : '일정을 추가해 여행을 채워보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _offline ? null : _addItem,
            icon: const Icon(Icons.add),
            label: const Text('일정 추가'),
          ),
        ],
      ),
    );
  }
}
