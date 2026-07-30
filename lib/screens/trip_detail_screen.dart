import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../services/todo_api.dart';
import '../services/trip_api.dart';
import 'location_picker_screen.dart';

final _dateFmt = DateFormat('yyyy.MM.dd');
final _itemFmt = DateFormat('M/d(E) HH:mm', 'ko');

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.trip});

  final Trip trip;

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
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddItemDialog(trip: widget.trip),
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

/// 이 여행에 일정 항목 추가(제목 + 선택적 일시). tripId를 고정해 생성.
class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({required this.trip});

  final Trip trip;

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _titleController = TextEditingController();
  DateTime? _when;
  double? _lat;
  double? _lng;
  String? _placeName;
  bool _submitting = false;
  String? _error;

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
          initialName: _placeName,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lat = result.lat;
      _lng = result.lng;
      _placeName = result.name;
      // 장소만 정하고 제목이 비어 있으면 장소명으로 채워줌.
      if (_titleController.text.trim().isEmpty && result.name != null) {
        _titleController.text = result.name!;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final base = widget.trip.startDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when ?? base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when ?? DateTime(base.year, base.month, base.day, 9)),
    );
    if (!mounted) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time?.hour ?? 9, time?.minute ?? 0);
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '일정 이름을 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await TodoApi.createTodo(
        title: title,
        priority: TodoPriority.medium,
        tripId: widget.trip.id,
        dueAt: _when?.toUtc().toIso8601String(),
        latitude: _lat,
        longitude: _lng,
        placeName: _placeName,
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
      title: const Text('일정 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '일정 이름',
              hintText: '예: 성산일출봉',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickWhen,
            icon: const Icon(Icons.schedule),
            label: Text(_when == null ? '일시 (선택)' : _itemFmt.format(_when!)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.place_outlined),
            label: Text(
              _lat == null ? '장소 (선택)' : (_placeName ?? '지정한 위치'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
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
              : const Text('추가'),
        ),
      ],
    );
  }
}
