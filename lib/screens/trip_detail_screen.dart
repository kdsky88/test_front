import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/trip_api.dart';
import '../state/todo_notifier.dart';
import '../widgets/todo_form_dialog.dart';

final _dateFmt = DateFormat('yyyy.MM.dd');
final _itemFmt = DateFormat('M/d(E) HH:mm', 'ko');

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
    // 달력에서 쓰는 리치 폼 재사용: 여행 고정 + 날짜는 여행 기간으로 제한.
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => TodoFormDialog(notifier: widget.notifier, lockedTrip: widget.trip),
    );
    if (added == true) _load();
  }

  String get _rangeLabel {
    final t = widget.trip;
    if (t.startDate == null && t.endDate == null) return '기간 미정';
    final start = t.startDate == null ? '?' : _dateFmt.format(t.startDate!);
    final end = t.endDate == null ? '?' : _dateFmt.format(t.endDate!);
    return t.startDate != null && t.endDate == null ? start : '$start ~ $end';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.trip.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const Divider(height: 1),
          Expanded(child: RefreshIndicator(onRefresh: _load, child: _buildBody())),
        ],
      ),
    );
  }

  Widget _header() {
    final t = widget.trip;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [if (t.destination != null) t.destination!, _rangeLabel].join('  ·  '),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
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
          Center(child: OutlinedButton(onPressed: _load, child: const Text('다시 시도'))),
        ],
      );
    }
    final todos = _todos ?? const [];
    if (todos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.event_note_outlined, size: 52, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('아직 일정이 없어요. 일정을 추가해 보세요.')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: todos.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) => _itemTile(todos[i]),
    );
  }

  Widget _itemTile(Todo todo) {
    final when = todo.startAt ?? todo.dueAt;
    return ListTile(
      leading: Icon(
        todo.completed ? Icons.check_circle : Icons.radio_button_unchecked,
        color: todo.completed ? Colors.green : Theme.of(context).colorScheme.outline,
      ),
      title: Text(
        todo.title,
        style: TextStyle(
          decoration: todo.completed ? TextDecoration.lineThrough : null,
          color: todo.completed ? Theme.of(context).colorScheme.outline : null,
        ),
      ),
      subtitle: (when == null && todo.placeName == null)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (when != null) Text(_itemFmt.format(when.toLocal())),
                if (todo.placeName != null)
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 13),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(todo.placeName!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
