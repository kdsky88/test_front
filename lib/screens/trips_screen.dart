import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/trip_api.dart';
import '../state/todo_notifier.dart';
import '../theme.dart';
import '../widgets/travel_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/offline_banner.dart';
import '../widgets/trip_form_dialog.dart';
import 'nearby_screen.dart';
import 'trip_detail_screen.dart';

final _dateFmt = DateFormat('yyyy.MM.dd');

String _rangeLabel(Trip t) {
  if (t.startDate == null && t.endDate == null) return '기간 미정';
  final start = t.startDate == null ? '?' : _dateFmt.format(t.startDate!);
  final end = t.endDate == null ? '?' : _dateFmt.format(t.endDate!);
  return t.startDate != null && t.endDate == null ? start : '$start ~ $end';
}

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, required this.notifier, this.fetchTrips});

  final TodoNotifier notifier;
  final Future<List<Trip>> Function()? fetchTrips;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip>? _trips;
  bool _loading = true;
  bool _offline = false; // 캐시로 표시 중(네트워크 실패)
  String? _error;
  DateTime? _lastSynced;

  void _sortRecent(List<Trip> trips) {
    // 최근 여행(시작일 늦은 순)이 위로, 날짜 없는 건 맨 뒤.
    trips.sort((a, b) {
      if (a.startDate == null) return b.startDate == null ? 0 : 1;
      if (b.startDate == null) return -1;
      return b.startDate!.compareTo(a.startDate!);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = (await (widget.fetchTrips ?? TripApi.getTrips)()).toList();
      _sortRecent(trips);
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
        _offline = false;
        _lastSynced = DateTime.now();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.error.message;
        _loading = false;
      });
    } catch (_) {
      // 네트워크 실패: 마지막으로 받은 목록이 있으면 오프라인 모드로 보여준다.
      List<Trip> cached = const [];
      DateTime? savedAt;
      try {
        cached = await TripApi.cachedTrips();
        savedAt = await TripApi.cachedTripsSavedAt();
      } catch (_) {}
      if (!mounted) return;
      _offline = true;
      _lastSynced = savedAt;
      if (!mounted) return;
      if (cached.isNotEmpty || savedAt != null) {
        _sortRecent(cached);
        setState(() {
          _trips = cached;
          _loading = false;
          _offline = true;
        });
      } else {
        setState(() {
          _error = '서버에 연결할 수 없습니다.';
          _loading = false;
        });
      }
    }
  }

  bool _requireConnection() {
    if (!_offline) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('지금은 저장된 여행만 볼 수 있어요. 다시 연결한 뒤 이용해주세요.')),
    );
    return false;
  }

  Future<void> _openCreate() async {
    if (!_requireConnection()) return;
    final created = await showDialog<Trip>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TripFormDialog(),
    );
    if (created != null && mounted) {
      HapticFeedback.mediumImpact();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TripDetailScreen(trip: created, notifier: widget.notifier),
        ),
      );
      if (mounted) _load();
    }
  }

  Future<void> _openEdit(Trip trip) async {
    if (!_requireConnection()) return;
    final saved = await showDialog<Trip>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TripFormDialog(existing: trip),
    );
    if (saved != null && mounted) {
      HapticFeedback.mediumImpact();
      _load();
    }
  }

  Future<void> _confirmDelete(Trip trip) async {
    if (!_requireConnection()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 삭제'),
        content: Text(
          "'${trip.title}'을(를) 삭제할까요? 여행과 이 여행의 경비 기록이 함께 삭제되며 복구할 수 없습니다. 일정 항목은 할 일 목록에 남고 여행 연결만 해제됩니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      HapticFeedback.heavyImpact();
      await TripApi.deleteTrip(trip.id);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제에 실패했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 여행'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '내 주변',
            onPressed: () {
              if (!_requireConnection()) return;
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const NearbyScreen()));
            },
            icon: const Icon(Icons.near_me_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('새 여행'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    // 첫 로딩만 전체 스피너. 재로딩은 기존 목록을 유지(깜빡임 방지).
    if (_loading && _trips == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          if (_offline)
            OfflineBanner(
              lastSynced: _lastSynced,
              onRetry: _load,
              retrying: _loading,
            ),
          const SizedBox(height: 120),
          Center(child: Text(_error!)),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ),
        ],
      );
    }
    final trips = _trips ?? const [];
    if (trips.isEmpty) {
      return EmptyState(
        emoji: '🧳',
        icon: Icons.luggage_outlined,
        title: '아직 여행이 없어요',
        subtitle: _offline
            ? '저장된 여행이 없어요. 다시 연결해 새 여행을 만들어보세요.'
            : '목적지만 정하면 관광지·맛집 추천부터 하루 코스까지 채워드려요.',
        action: FilledButton.icon(
          onPressed: _offline ? _load : _openCreate,
          icon: const Icon(Icons.add),
          label: Text(_offline ? '다시 연결' : '새 여행 만들기'),
        ),
      );
    }
    return Column(
      children: [
        if (_offline)
          OfflineBanner(
            lastSynced: _lastSynced,
            onRetry: _load,
            retrying: _loading,
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              final rows = (trips.length / columns).ceil();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
                itemCount: rows + 1,
                itemBuilder: (context, row) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: row == 0
                        ? _listHeading(trips.length)
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  var column = 0;
                                  column < columns;
                                  column++
                                ) ...[
                                  if (column > 0) const SizedBox(width: 20),
                                  Expanded(
                                    child:
                                        (row - 1) * columns + column <
                                            trips.length
                                        ? FadeSlideIn(
                                            delay: Duration(
                                              milliseconds: ((row - 1) * 45)
                                                  .clamp(0, 200),
                                            ),
                                            child: _tripCard(
                                              trips[(row - 1) * columns +
                                                  column],
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _listHeading(int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '목적지만 정해도 좋아요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text('다음 여행을 펼쳐보세요', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('나의 여행', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripCard(Trip trip) => TravelCard(
    title: trip.title,
    destination: trip.destination?.trim().isNotEmpty == true
        ? trip.destination!
        : '어디든, 가볍게',
    imageDestination: trip.destination,
    dateLabel: _rangeLabel(trip),
    cover: AppTheme.coverFor(trip.id),
    status: trip.dDayLabel ?? '날짜 미정',
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(trip: trip, notifier: widget.notifier),
      ),
    ),
    onEdit: () => _openEdit(trip),
    onDelete: () => _confirmDelete(trip),
  );
}
