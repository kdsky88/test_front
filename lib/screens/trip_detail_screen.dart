import 'dart:math';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/place.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/map_links.dart';
import '../services/places_api.dart';
import '../services/trip_api.dart';
import '../services/weather_api.dart';
import '../state/todo_notifier.dart';
import '../theme.dart';
import '../widgets/todo_form_dialog.dart';
import 'currency_screen.dart';
import 'trip_calendar_screen.dart';
import 'trip_map_screen.dart';

final _dateFmt = DateFormat('yyyy.MM.dd');
final _dayFmt = DateFormat('M/d (E)', 'ko');
final _timeFmt = DateFormat('HH:mm');

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.trip, required this.notifier});

  final Trip trip;
  final TodoNotifier notifier;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  List<Todo>? _todos;
  bool _loading = true;
  String? _error;

  // 즉흥 추천("아무거나") — 목적지 추천을 타입별 캐시.
  final _rng = Random();
  final Map<String, List<Place>> _recoCache = {};

  // 목적지 날씨(open-meteo). null=미로드/없음.
  List<DailyWeather>? _weather;

  @override
  void initState() {
    super.initState();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final todos = await TripApi.getTripTodos(widget.trip.id);
      if (!mounted) return;
      setState(() {
        _todos = todos;
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

  Future<void> _addItem() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripCalendarScreen(trip: widget.trip, notifier: widget.notifier),
      ),
    );
    _load();
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

  List<DateTime> get _days {
    final s = widget.trip.startDate, e = widget.trip.endDate;
    if (s == null || e == null) return const [];
    final start = DateTime(s.year, s.month, s.day);
    final end = DateTime(e.year, e.month, e.day);
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    return days;
  }

  List<Todo> _itemsOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return (_todos ?? const []).where((t) {
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

  @override
  Widget build(BuildContext context) {
    final cover = AppTheme.coverFor(widget.trip.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.title),
        backgroundColor: cover,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            tooltip: '환율',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CurrencyScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(cover)),
    );
  }

  Widget _buildBody(Color cover) {
    if (_loading) {
      return ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]);
    }
    if (_error != null) {
      return ListView(children: [
        _hero(cover),
        const SizedBox(height: 80),
        Center(child: Text(_error!)),
        const SizedBox(height: 12),
        Center(child: OutlinedButton(onPressed: _load, child: const Text('다시 시도'))),
      ]);
    }

    final days = _days;
    final children = <Widget>[_hero(cover)];

    // 목적지 날씨 스트립(예보 범위 내일 때).
    children.add(_weatherStrip());
    // 즉흥/하루 코스 버튼(목적지 있을 때).
    children.add(_actionButtons());

    // 위치가 있는 일정을 여행 지도에 핀으로.
    final located = (_todos ?? const [])
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();
    if (located.isNotEmpty) children.add(_tripMap(located));

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
        children.add(_daySection(i + 1, days[i], items, cover));
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
    return Container(
      width: double.infinity,
      color: cover,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppTheme.emojiFor(t.id), style: const TextStyle(fontSize: 44)),
              const Spacer(),
              if (dday != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(dday, style: TextStyle(color: cover, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  [if (t.destination != null) t.destination!, range].join('  ·  '),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
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
    Place current = initial;
    GoogleMapController? mapCtrl;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final theme = Theme.of(ctx);
          Future<void> reroll() async {
            HapticFeedback.selectionClick();
            final type = _rng.nextBool() ? 'attraction' : 'food';
            final places = await _recosFor(type) ?? const [];
            if (places.isEmpty || !ctx.mounted) return;
            setSheet(() => current = places[_rng.nextInt(places.length)]);
            mapCtrl?.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(current.latitude, current.longitude), 15));
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎲 아무거나',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(current.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (current.category != null)
                        Text(current.category!,
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                      if (current.rating != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star, size: 15, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(current.rating!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ],
                  ),
                  if (current.description != null) ...[
                    const SizedBox(height: 8),
                    Text(current.description!,
                        style: TextStyle(fontSize: 13.5, height: 1.35, color: theme.colorScheme.onSurface)),
                  ],
                  if (current.address != null) ...[
                    const SizedBox(height: 8),
                    Text(current.address!,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  // 위치 미리보기(핀). 팬/줌은 시트와 안 싸우게 끄고, 탭하면 구글 지도로.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 150,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(current.latitude, current.longitude),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('surprise'),
                            position: LatLng(current.latitude, current.longitude),
                          ),
                        },
                        onMapCreated: (c) => mapCtrl = c,
                        onTap: (_) => openInGoogleMaps(lat: current.latitude, lng: current.longitude),
                        zoomGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _addFromSurprise(current),
                          icon: const Icon(Icons.add),
                          label: const Text('일정으로 추가'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => openInGoogleMaps(
                            lat: current.latitude, lng: current.longitude, directions: true),
                        icon: const Icon(Icons.directions),
                        label: const Text('길찾기'),
                      ),
                    ],
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: reroll,
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('다른 거'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addFromSurprise(Place p) async {
    Navigator.of(context).pop(); // 시트 닫기
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TodoFormDialog(
        notifier: widget.notifier,
        lockedTrip: widget.trip,
        initialTitle: p.name,
        initialPlaceName: p.name,
        initialLat: p.latitude,
        initialLng: p.longitude,
      ),
    ));
    if (ok == true) _load();
  }

  Widget _actionButtons() {
    final dest = widget.trip.destination?.trim();
    if (dest == null || dest.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _surprise,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('아무거나'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _course,
              icon: const Icon(Icons.route_outlined),
              label: const Text('하루 코스'),
            ),
          ),
        ],
      ),
    );
  }

  // 하루 코스: 관광지/맛집을 anchor 근처로 묶어 시간대별.
  Future<void> _course() async {
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

  List<(String, Place)> _buildCourse(List<Place> attractions, List<Place> foods) {
    final stops = <(String, Place)>[];
    if (attractions.isEmpty && foods.isEmpty) return stops;
    final anchor = attractions.isNotEmpty
        ? attractions[_rng.nextInt(attractions.length)]
        : foods[_rng.nextInt(foods.length)];
    double dist(Place p) =>
        Geolocator.distanceBetween(anchor.latitude, anchor.longitude, p.latitude, p.longitude);
    final nearA = [...attractions]..sort((a, b) => dist(a).compareTo(dist(b)));
    final nearF = [...foods]..sort((a, b) => dist(a).compareTo(dist(b)));
    final used = <String>{};
    String key(Place p) => p.fsqId ?? p.name;
    void add(String slot, Place? p) {
      if (p != null && used.add(key(p))) stops.add((slot, p));
    }

    add('오전', anchor);
    add('점심', nearF.isNotEmpty ? nearF.first : null);
    add('오후', nearA.where((p) => !used.contains(key(p))).firstOrNull);
    add('저녁', nearF.where((p) => !used.contains(key(p))).firstOrNull);
    return stops;
  }

  void _showCourse(List<(String, Place)> initial) {
    var stops = initial;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final theme = Theme.of(ctx);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🗺️ 하루 코스',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  for (final (slot, p) in stops)
                    InkWell(
                      onTap: () => openInGoogleMaps(lat: p.latitude, lng: p.longitude, directions: true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(slot,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (p.category != null)
                                    Text(p.category!,
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                                ],
                              ),
                            ),
                            Icon(Icons.directions, size: 20, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _addCourse(stops),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('전체 일정에 담기'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setSheet(() => stops = _buildCourse(
                                _recoCache['attraction'] ?? const [],
                                _recoCache['food'] ?? const [],
                              ));
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addCourse(List<(String, Place)> stops) async {
    Navigator.of(context).pop(); // 시트 닫기
    for (final (_, p) in stops) {
      await widget.notifier.createTodo(
        title: p.name,
        priority: TodoPriority.medium,
        tripId: widget.trip.id,
        latitude: p.latitude,
        longitude: p.longitude,
        placeName: p.name,
      );
    }
    if (!mounted) return;
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('하루 코스 ${stops.length}곳을 일정에 담았어요')),
    );
  }

  // 목적지 날씨 가로 스트립(여행 기간, 예보 범위 내).
  Widget _weatherStrip() {
    final w = _weather;
    if (w == null || w.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: w.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = w[i];
          return Container(
            width: 74,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_dayFmt.format(d.date),
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(d.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text('${d.tMax.round()}° / ${d.tMin.round()}°',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
      ),
    );
  }

  // 여행 전체 지도(구글맵): 위치가 있는 일정을 핀으로. 인라인에서도 확대/이동 되고, 전체화면 버튼 제공.
  Widget _tripMap(List<Todo> located) {
    final markers = <Marker>{
      for (final t in located)
        Marker(
          markerId: MarkerId(t.id),
          position: LatLng(t.latitude!, t.longitude!),
          infoWindow: InfoWindow(title: t.placeName ?? t.title),
          onTap: () => _showPlace(t),
        ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(located.first.latitude!, located.first.longitude!),
                  zoom: 12,
                ),
                markers: markers,
                onMapCreated: (controller) => _fitBounds(controller, located),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                // 리스트 안에서도 지도가 드래그/줌 제스처를 잡도록(스크롤에 안 먹힘).
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: '전체화면 지도',
                    onPressed: () => _openMap(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 핀이 여러 개면 다 보이게 카메라 맞춤(지도 레이아웃 후 호출).
  void _fitBounds(GoogleMapController controller, List<Todo> located) {
    if (located.length < 2) return;
    var minLat = located.first.latitude!, maxLat = minLat;
    var minLng = located.first.longitude!, maxLng = minLng;
    for (final t in located) {
      minLat = t.latitude! < minLat ? t.latitude! : minLat;
      maxLat = t.latitude! > maxLat ? t.latitude! : maxLat;
      minLng = t.longitude! < minLng ? t.longitude! : minLng;
      maxLng = t.longitude! > maxLng ? t.longitude! : maxLng;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
    });
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cover.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(badge,
                style: TextStyle(color: cover, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Text(sub, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _itemCard(Todo todo) {
    final theme = Theme.of(context);
    final when = todo.startAt ?? todo.dueAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: InkWell(
          // 탭 = 지도(장소 있을 때), 없으면 수정. 수정은 우측 연필로.
          onTap: () => todo.latitude != null ? _openMap(focusId: todo.id) : _editItem(todo),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 시간 배지
                SizedBox(
                  width: 46,
                  child: Text(
                    when != null ? _timeFmt.format(when.toLocal()) : '—',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(width: 1, height: 34, color: theme.dividerColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: todo.completed ? TextDecoration.lineThrough : null,
                          color: todo.completed ? theme.colorScheme.outline : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (todo.placeName != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                todo.placeName!,
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (todo.completed)
                  const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: '수정',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editItem(todo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Text('🗓️', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('아직 일정이 없어요',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('아래 + 버튼으로 첫 일정을 추가해 보세요.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
