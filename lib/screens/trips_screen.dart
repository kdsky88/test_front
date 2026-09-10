import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/trip_api.dart';
import '../state/todo_notifier.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/offline_banner.dart';
import 'location_picker_screen.dart';
import 'nearby_screen.dart';
import 'trip_detail_screen.dart';

final _dateFmt = DateFormat('yyyy.MM.dd');
final _apiDateFmt = DateFormat('yyyy-MM-dd');

String _rangeLabel(Trip t) {
  if (t.startDate == null && t.endDate == null) return '기간 미정';
  final start = t.startDate == null ? '?' : _dateFmt.format(t.startDate!);
  final end = t.endDate == null ? '?' : _dateFmt.format(t.endDate!);
  return t.startDate != null && t.endDate == null ? start : '$start ~ $end';
}

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, required this.notifier});

  final TodoNotifier notifier;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip>? _trips;
  bool _loading = true;
  bool _offline = false; // 캐시로 표시 중(네트워크 실패)
  String? _error;

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
      final trips = await TripApi.getTrips().then((t) => t.toList());
      _sortRecent(trips);
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
        _offline = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.error.message;
        _loading = false;
      });
    } catch (_) {
      // 네트워크 실패: 마지막으로 받은 목록이 있으면 오프라인 모드로 보여준다.
      final cached = await TripApi.cachedTrips();
      if (!mounted) return;
      if (cached.isNotEmpty) {
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

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _TripFormDialog(),
    );
    if (created == true) {
      HapticFeedback.mediumImpact();
      _load();
    }
  }

  Future<void> _openEdit(Trip trip) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TripFormDialog(existing: trip),
    );
    if (saved == true) {
      HapticFeedback.mediumImpact();
      _load();
    }
  }

  Future<void> _confirmDelete(Trip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 삭제'),
        content: Text("'${trip.title}'을(를) 삭제할까요? 일정 항목은 남고 연결만 해제됩니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('여행'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '내 주변',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NearbyScreen()),
            ),
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
    if (_loading && _trips == null) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
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
        title: '아직 여행이 없어요',
        subtitle: '목적지만 정하면 관광지·맛집 추천부터 하루 코스까지 채워드려요.',
        action: FilledButton.icon(
          onPressed: _openCreate,
          icon: const Icon(Icons.add),
          label: const Text('새 여행 만들기'),
        ),
      );
    }
    return Column(
      children: [
        if (_offline) const OfflineBanner(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: trips.length,
            itemBuilder: (context, i) => FadeSlideIn(
              delay: Duration(milliseconds: (i * 45).clamp(0, 300)),
              child: _tripCard(trips[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tripCard(Trip trip) {
    final theme = Theme.of(context);
    final dday = trip.dDayLabel;
    final cover = AppTheme.coverFor(trip.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TripDetailScreen(trip: trip, notifier: widget.notifier),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 커버: 목적지 사진(있으면) + 이모지 + D-day + 메뉴
              SizedBox(
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(destination: trip.destination, fallback: cover),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Stack(
                        children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(AppTheme.emojiFor(trip.id), style: const TextStyle(fontSize: 40)),
                    ),
                    if (dday != null)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            dday,
                            style: TextStyle(
                              color: cover,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: PopupMenuButton<String>(
                        tooltip: '옵션',
                        onSelected: (v) {
                          if (v == 'edit') _openEdit(trip);
                          if (v == 'delete') _confirmDelete(trip);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('수정'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('삭제'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 15, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (trip.destination != null) trip.destination!,
                              _rangeLabel(trip),
                            ].join('  ·  '),
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 여행 만들기/수정 다이얼로그. 성공 시 pop(true). existing=null이면 생성.
class _TripFormDialog extends StatefulWidget {
  const _TripFormDialog({this.existing});

  final Trip? existing;

  @override
  State<_TripFormDialog> createState() => _TripFormDialogState();
}

class _TripFormDialogState extends State<_TripFormDialog> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _destinationController =
      TextEditingController(text: widget.existing?.destination ?? '');
  late DateTime? _start = widget.existing?.startDate;
  late DateTime? _end = widget.existing?.endDate;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_start ?? now) : (_end ?? _start ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _pickDestination() async {
    final current = _destinationController.text.trim();
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialQuery: current.isEmpty ? null : current,
        ),
      ),
    );
    if (result?.name == null || !mounted) return;
    setState(() => _destinationController.text = result!.name!);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '여행 이름을 입력해주세요.');
      return;
    }
    if (_start == null || _end == null) {
      setState(() => _error = '여행 기간(시작일·종료일)을 선택해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final destination = _destinationController.text.trim();
      final startDate = _apiDateFmt.format(_start!);
      final endDate = _apiDateFmt.format(_end!);
      if (_isEdit) {
        await TripApi.updateTrip(
          widget.existing!.id,
          title: title,
          destination: destination,
          startDate: startDate,
          endDate: endDate,
        );
      } else {
        await TripApi.createTrip(
          title: title,
          destination: destination,
          startDate: startDate,
          endDate: endDate,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.error.message;
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = '저장에 실패했습니다.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? '여행 수정' : '새 여행'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '여행 이름',
                hintText: '예: 제주도 3박 4일',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: '목적지 (선택)',
                hintText: '예: 제주',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: '지도에서 검색',
                  onPressed: _pickDestination,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(_start == null ? '시작일' : _dateFmt.format(_start!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(_end == null ? '종료일' : _dateFmt.format(_end!)),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? '저장' : '만들기'),
        ),
      ],
    );
  }
}
