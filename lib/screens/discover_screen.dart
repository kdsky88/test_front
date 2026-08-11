import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/place.dart';
import '../models/todo.dart'; // ApiException, TodoPriority
import '../models/trip.dart';
import '../services/places_api.dart';
import '../services/todo_api.dart';
import '../services/trip_api.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/fade_slide_in.dart';

/// 발견 탭 — 지역을 입력하면 관광지/맛집을 추천. (P유형: 일정·시간 강제 없이 둘러보고 담기)
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _regionController = TextEditingController();
  String _type = 'attraction'; // 'attraction' | 'food'
  bool _loading = false;
  String? _error;
  List<Place>? _results;
  String _lastQuery = '';

  @override
  void dispose() {
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final region = _regionController.text.trim();
    if (region.isEmpty) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = region;
    });
    try {
      final places = await PlacesApi.recommend(region: region, type: _type);
      if (!mounted) return;
      setState(() {
        _results = places;
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

  void _onTypeChanged(String type) {
    if (type == _type) return;
    HapticFeedback.selectionClick();
    setState(() => _type = type);
    // 이미 검색한 지역이 있으면 카테고리만 바꿔 바로 재검색.
    if (_regionController.text.trim().isNotEmpty) _search();
  }

  // 담기: 여행을 고르면(또는 없이) 기존 Todo로 저장. 시간(dueAt) 없이 장소만.
  Future<void> _savePlace(Place place) async {
    HapticFeedback.mediumImpact();
    List<Trip> trips;
    try {
      trips = await TripApi.getTrips();
    } catch (_) {
      trips = const [];
    }
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                "'${place.name}' 담기",
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in trips)
                    ListTile(
                      leading: const Icon(Icons.luggage_outlined),
                      title: Text(t.title),
                      subtitle: t.destination != null ? Text(t.destination!) : null,
                      onTap: () => Navigator.pop(ctx, t.id),
                    ),
                  ListTile(
                    leading: const Icon(Icons.inbox_outlined),
                    title: const Text('여행 없이 담기'),
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return; // 취소(시트 닫음)
    final tripId = choice.isEmpty ? null : choice;
    try {
      await TodoApi.createTodo(
        title: place.name,
        priority: TodoPriority.medium,
        tripId: tripId,
        latitude: place.latitude,
        longitude: place.longitude,
        placeName: place.name,
        note: _noteFor(place),
      );
      if (!mounted) return;
      final where = tripId == null
          ? '보관함'
          : trips.firstWhere((t) => t.id == tripId).title;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$where에 담았어요')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('담기에 실패했어요')));
    }
  }

  static String? _noteFor(Place p) {
    final parts = [p.category, p.address].where((s) => s != null && s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('발견')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _regionController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: '지역을 입력하세요 (예: 부산, 도쿄)',
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'attraction',
                      label: Text('관광지'),
                      icon: Icon(Icons.photo_camera_outlined),
                    ),
                    ButtonSegment(
                      value: 'food',
                      label: Text('맛집'),
                      icon: Icon(Icons.restaurant_outlined),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => _onTypeChanged(s.first),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        emoji: '⚠️',
        title: '추천을 불러오지 못했어요',
        subtitle: _error,
        action: FilledButton.icon(
          onPressed: _search,
          icon: const Icon(Icons.refresh),
          label: const Text('다시 시도'),
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const EmptyState(
        emoji: '🧭',
        title: '어디로 떠나볼까요?',
        subtitle: '지역을 입력하면 관광지와 맛집을 추천해드려요.\n일정·시간은 나중에 정해도 괜찮아요.',
      );
    }
    if (results.isEmpty) {
      return EmptyState(
        emoji: '🔍',
        title: '"$_lastQuery" 결과가 없어요',
        subtitle: '다른 지역명으로 검색해보세요.',
      );
    }
    return FadeSlideIn(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: results.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _PlaceCard(
          place: results[i],
          onSave: () => _savePlace(results[i]),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onSave});
  final Place place;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = AppTheme.coverFor(place.name);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cover.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                AppTheme.emojiFor(place.name),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (place.category != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.category!,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (place.address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (place.distanceLabel != null)
                  Text(
                    place.distanceLabel!,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  ),
                IconButton(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: '담기',
                  color: scheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
