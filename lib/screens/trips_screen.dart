import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/trip_api.dart';
import '../state/todo_notifier.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/fade_slide_in.dart';
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
  const TripsScreen({super.key, required this.onLogout, required this.notifier});

  final VoidCallback onLogout;
  final TodoNotifier notifier;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip>? _trips;
  bool _loading = true;
  String? _error;

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
      final trips = await TripApi.getTrips();
      if (!mounted) return;
      setState(() {
        _trips = trips;
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
          IconButton(
            tooltip: '로그아웃',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
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
    if (_loading) return const Center(child: CircularProgressIndicator());
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
      return const EmptyState(
        emoji: '🧳',
        title: '아직 여행이 없어요',
        subtitle: '아래 + 버튼으로 첫 여행을 계획해 보세요.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: trips.length,
      itemBuilder: (context, i) => FadeSlideIn(
        delay: Duration(milliseconds: (i * 45).clamp(0, 300)),
        child: _tripCard(trips[i]),
      ),
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
              // 컬러 커버: 이모지 + D-day + 메뉴
              Container(
                height: 92,
                color: cover,
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
                      child: InkWell(
                        onTap: () => _confirmDelete(trip),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
                        ),
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

/// 새 여행 만들기 다이얼로그. 성공 시 pop(true).
class _TripFormDialog extends StatefulWidget {
  const _TripFormDialog();

  @override
  State<_TripFormDialog> createState() => _TripFormDialogState();
}

class _TripFormDialogState extends State<_TripFormDialog> {
  final _titleController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _submitting = false;
  String? _error;

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

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '여행 이름을 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await TripApi.createTrip(
        title: title,
        destination: _destinationController.text.trim(),
        startDate: _start == null ? null : _apiDateFmt.format(_start!),
        endDate: _end == null ? null : _apiDateFmt.format(_end!),
      );
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
      title: const Text('새 여행'),
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
              decoration: const InputDecoration(
                labelText: '목적지 (선택)',
                hintText: '예: 제주',
                border: OutlineInputBorder(),
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
              : const Text('만들기'),
        ),
      ],
    );
  }
}
