import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../state/todo_notifier.dart';

class TodoFormDialog extends StatefulWidget {
  final Todo? todo;
  final TodoNotifier notifier;
  final DateTime? initialDueAt;

  const TodoFormDialog({
    super.key,
    this.todo,
    required this.notifier,
    this.initialDueAt,
  });

  @override
  State<TodoFormDialog> createState() => _TodoFormDialogState();
}

class _TodoFormDialogState extends State<TodoFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _assigneeCtrl;
  DateTime? _dueAt;
  late TodoPriority _priority;
  bool _submitting = false;
  String? _generalError;
  String? _titleError;
  String? _descError;
  String? _noteError;
  String? _dueAtError;
  String? _priorityError;
  String? _assigneeError;

  bool get _isEdit => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.todo?.title ?? '');
    _descCtrl = TextEditingController(text: widget.todo?.description ?? '');
    _noteCtrl = TextEditingController(text: widget.todo?.note ?? '');
    _assigneeCtrl = TextEditingController(text: widget.todo?.assignee ?? '');
    _dueAt = widget.todo?.dueAt ?? widget.initialDueAt;
    _priority = widget.todo?.priority ?? TodoPriority.medium;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    _assigneeCtrl.dispose();
    super.dispose();
  }

  String _normalizeTitle(String value) {
    // Trim unicode whitespace including full-width spaces (　)
    return value.replaceAll(RegExp(r'^[\s　]+|[\s　]+$'), '');
  }

  bool _validateLocally() {
    final normalizedTitle = _normalizeTitle(_titleCtrl.text);
    String? titleErr;
    if (normalizedTitle.isEmpty) {
      titleErr = '제목을 입력해주세요.';
    } else if (normalizedTitle.length > 100) {
      titleErr = '제목은 100자 이하로 입력해주세요.';
    }

    String? descErr;
    if (_descCtrl.text.length > 1000) {
      descErr = '간단 설명은 1,000자 이하로 입력해주세요.';
    }

    String? noteErr;
    if (_noteCtrl.text.length > 1000) {
      noteErr = '메모는 1,000자 이하로 입력해주세요.';
    }

    setState(() {
      _titleError = titleErr;
      _descError = descErr;
      _noteError = noteErr;
    });

    return titleErr == null && descErr == null && noteErr == null;
  }

  Future<void> _submit() async {
    if (!_validateLocally()) return;
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _generalError = null;
      _titleError = null;
      _descError = null;
      _noteError = null;
      _dueAtError = null;
      _priorityError = null;
      _assigneeError = null;
    });

    final normalizedTitle = _normalizeTitle(_titleCtrl.text);
    final desc = _descCtrl.text.isNotEmpty ? _descCtrl.text : null;
    final note = _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null;
    final assignee = _assigneeCtrl.text.trim().isNotEmpty
        ? _assigneeCtrl.text.trim()
        : null;
    final dueAtStr = _dueAt?.toUtc().toIso8601String();

    String? errorMsg;
    String? titleErr;
    String? descErr;
    String? noteErr;
    String? dueErr;
    String? priorityErr;
    String? assigneeErr;

    if (_isEdit) {
      final todo = widget.todo!;
      final (_, apiEx, msg) = await widget.notifier.updateTodo(
        id: todo.id,
        title: normalizedTitle,
        priority: _priority,
        description: desc,
        note: note,
        dueAt: dueAtStr,
        assignee: assignee,
        clearDescription: desc == null,
        clearNote: note == null,
        clearDueAt: _dueAt == null,
        clearAssignee: assignee == null,
      );
      if (msg != null) {
        errorMsg = msg;
        if (apiEx != null) {
          titleErr = apiEx.error.fields?['title'];
          descErr = apiEx.error.fields?['description'];
          noteErr = apiEx.error.fields?['note'];
          dueErr = apiEx.error.fields?['dueAt'];
          priorityErr = apiEx.error.fields?['priority'];
          assigneeErr = apiEx.error.fields?['assignee'];
          if (titleErr != null ||
              descErr != null ||
              noteErr != null ||
              dueErr != null ||
              priorityErr != null ||
              assigneeErr != null) {
            errorMsg = null;
          }
        }
      }
    } else {
      errorMsg = await widget.notifier.createTodo(
        title: normalizedTitle,
        priority: _priority,
        description: desc,
        note: note,
        dueAt: dueAtStr,
        assignee: assignee,
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (errorMsg == null &&
        titleErr == null &&
        descErr == null &&
        noteErr == null &&
        dueErr == null &&
        priorityErr == null &&
        assigneeErr == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _generalError = errorMsg;
        _titleError = titleErr;
        _descError = descErr;
        _noteError = noteErr;
        _dueAtError = dueErr;
        _priorityError = priorityErr;
        _assigneeError = assigneeErr;
      });
    }
  }

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt != null
          ? TimeOfDay.fromDateTime(_dueAt!)
          : TimeOfDay.now(),
    );
    if (!mounted || time == null) return;

    setState(() {
      _dueAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
      _dueAtError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_isEdit ? 'Todo 수정' : 'Todo 등록'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: '제목 *',
                errorText: _titleError,
                counterText: '${_titleCtrl.text.length}/100',
              ),
              maxLength: 110,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: '간단 설명',
                errorText: _descError,
                counterText: '${_descCtrl.text.length}/1000',
              ),
              maxLines: 3,
              maxLength: 1010,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: '메모(상세 설명)',
                errorText: _noteError,
                counterText: '${_noteCtrl.text.length}/1000',
              ),
              minLines: 3,
              maxLines: 6,
              maxLength: 1010,
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('우선순위', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<TodoPriority>(
              segments: TodoPriority.values
                  .map(
                    (priority) => ButtonSegment<TodoPriority>(
                      value: priority,
                      label: Text(priority.label),
                    ),
                  )
                  .toList(),
              selected: {_priority},
              onSelectionChanged: _submitting
                  ? null
                  : (selected) {
                      setState(() {
                        _priority = selected.first;
                        _priorityError = null;
                      });
                    },
            ),
            if (_priorityError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _priorityError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _assigneeCtrl,
              decoration: InputDecoration(
                labelText: '담당자',
                hintText: '담당자 이름 (선택)',
                errorText: _assigneeError,
                counterText: '${_assigneeCtrl.text.length}/50',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
              ),
              maxLength: 60,
              enabled: !_submitting,
              onChanged: (_) => setState(() {
                _assigneeError = null;
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dueAt != null
                        ? '마감일: ${DateFormat('yyyy-MM-dd HH:mm').format(_dueAt!.toLocal())}'
                        : '마감일 없음',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (_dueAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: '마감일 제거',
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _dueAt = null),
                  ),
                TextButton(
                  onPressed: _submitting ? null : _pickDueAt,
                  child: Text(_dueAt != null ? '변경' : '선택'),
                ),
              ],
            ),
            if (_dueAtError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _dueAtError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            if (_generalError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _generalError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}
