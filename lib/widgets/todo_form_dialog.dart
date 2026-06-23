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
  late final TextEditingController _noteCtrl;
  late final TextEditingController _tagCtrl;
  DateTime? _startAt;
  DateTime? _dueAt;
  late TodoPriority _priority;
  bool _submitting = false;
  String? _generalError;
  String? _titleError;
  String? _noteError;
  String? _startAtError;
  String? _dueAtError;
  String? _priorityError;

  // Create mode: locally collected tags
  final List<String> _localTags = [];

  // Edit mode: server-synced tags (immediate apply)
  late List<String> _editTags;
  bool _tagProcessing = false;
  String? _tagError;

  bool get _isEdit => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.todo?.title ?? '');
    _noteCtrl = TextEditingController(text: widget.todo?.note ?? '');
    _tagCtrl = TextEditingController();
    _startAt = widget.todo?.startAt;
    _dueAt = widget.todo?.dueAt ?? widget.initialDueAt;
    _priority = widget.todo?.priority ?? TodoPriority.medium;
    _editTags = List.of(widget.todo?.tags ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  String _normalizeTitle(String value) {
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

    String? noteErr;
    if (_noteCtrl.text.length > 1000) {
      noteErr = '메모는 1,000자 이하로 입력해주세요.';
    }

    String? startErr;
    if (_startAt != null && _dueAt != null && _startAt!.isAfter(_dueAt!)) {
      startErr = '시작일은 마감일보다 늦을 수 없습니다.';
    }

    setState(() {
      _titleError = titleErr;
      _noteError = noteErr;
      _startAtError = startErr;
    });

    return titleErr == null && noteErr == null && startErr == null;
  }

  Future<void> _submit() async {
    if (!_validateLocally()) return;
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _generalError = null;
      _titleError = null;
      _noteError = null;
      _startAtError = null;
      _dueAtError = null;
      _priorityError = null;
    });

    final normalizedTitle = _normalizeTitle(_titleCtrl.text);
    final note = _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null;
    final startAtStr = _startAt?.toUtc().toIso8601String();
    final dueAtStr = _dueAt?.toUtc().toIso8601String();

    String? errorMsg;
    String? titleErr;
    String? noteErr;
    String? startErr;
    String? dueErr;
    String? priorityErr;

    if (_isEdit) {
      final todo = widget.todo!;
      final (_, apiEx, msg) = await widget.notifier.updateTodo(
        id: todo.id,
        title: normalizedTitle,
        priority: _priority,
        note: note,
        startAt: startAtStr,
        dueAt: dueAtStr,
        clearNote: note == null,
        clearStartAt: _startAt == null,
        clearDueAt: _dueAt == null,
      );
      if (msg != null) {
        errorMsg = msg;
        if (apiEx != null) {
          titleErr = apiEx.error.fields?['title'];
          noteErr = apiEx.error.fields?['note'];
          startErr = apiEx.error.fields?['startAt'];
          dueErr = apiEx.error.fields?['dueAt'];
          priorityErr = apiEx.error.fields?['priority'];
          if (titleErr != null ||
              noteErr != null ||
              startErr != null ||
              dueErr != null ||
              priorityErr != null) {
            errorMsg = null;
          }
        }
      }
    } else {
      errorMsg = await widget.notifier.createTodo(
        title: normalizedTitle,
        priority: _priority,
        note: note,
        startAt: startAtStr,
        dueAt: dueAtStr,
        tags: List.of(_localTags),
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (errorMsg == null &&
        titleErr == null &&
        noteErr == null &&
        startErr == null &&
        dueErr == null &&
        priorityErr == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _generalError = errorMsg;
        _titleError = titleErr;
        _noteError = noteErr;
        _startAtError = startErr;
        _dueAtError = dueErr;
        _priorityError = priorityErr;
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
      _startAtError = null;
    });
  }

  Future<void> _pickStartAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startAt ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _startAt != null
          ? TimeOfDay.fromDateTime(_startAt!)
          : TimeOfDay.now(),
    );
    if (!mounted || time == null) return;

    setState(() {
      _startAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
      _startAtError = null;
    });
  }

  void _addLocalTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty) return;
    if (tag.length > 20) {
      setState(() => _tagError = '태그는 20자 이하로 입력해주세요.');
      return;
    }
    if (_localTags.contains(tag)) {
      setState(() => _tagError = '이미 추가된 태그입니다.');
      return;
    }
    if (_localTags.length >= 10) {
      setState(() => _tagError = '태그는 최대 10개까지 추가할 수 있습니다.');
      return;
    }
    setState(() {
      _localTags.add(tag);
      _tagCtrl.clear();
      _tagError = null;
    });
  }

  Future<void> _addEditTag() async {
    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty) return;
    if (tag.length > 20) {
      setState(() => _tagError = '태그는 20자 이하로 입력해주세요.');
      return;
    }
    if (_tagProcessing) return;

    setState(() {
      _tagProcessing = true;
      _tagError = null;
    });

    final (updated, error) = await widget.notifier.addTagToTodo(
      widget.todo!.id,
      tag,
    );

    if (!mounted) return;
    setState(() {
      _tagProcessing = false;
      if (updated != null) {
        _editTags = List.of(updated.tags);
        _tagCtrl.clear();
        _tagError = null;
      } else {
        _tagError = error;
      }
    });
  }

  Future<void> _removeEditTag(String tag) async {
    if (_tagProcessing) return;

    setState(() {
      _tagProcessing = true;
      _tagError = null;
    });

    final (updated, error) = await widget.notifier.removeTagFromTodo(
      widget.todo!.id,
      tag,
    );

    if (!mounted) return;
    setState(() {
      _tagProcessing = false;
      if (updated != null) {
        _editTags = List.of(updated.tags);
        _tagError = null;
      } else {
        _tagError = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTags = _isEdit ? _editTags : _localTags;
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _startAt != null
                        ? '시작일: ${DateFormat('yyyy-MM-dd HH:mm').format(_startAt!.toLocal())}'
                        : '시작일 없음',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (_startAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: '시작일 제거',
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _startAt = null;
                            _startAtError = null;
                          }),
                  ),
                TextButton(
                  onPressed: _submitting ? null : _pickStartAt,
                  child: Text(_startAt != null ? '변경' : '선택'),
                ),
              ],
            ),
            if (_startAtError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _startAtError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
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
                        : () => setState(() {
                            _dueAt = null;
                            _startAtError = null;
                          }),
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
            const SizedBox(height: 8),
            Text('태그', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    decoration: InputDecoration(
                      hintText: '태그 입력 (최대 20자)',
                      errorText: _tagError,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                    maxLength: 20,
                    enabled: !_submitting && !_tagProcessing,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        _isEdit ? _addEditTag() : _addLocalTag(),
                    onChanged: (_) => setState(() => _tagError = null),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: _tagProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : (_isEdit ? _addEditTag : _addLocalTag),
                          child: const Text('추가'),
                        ),
                ),
              ],
            ),
            if (currentTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: currentTags
                    .map(
                      (tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: _submitting || _tagProcessing
                            ? null
                            : () => _isEdit
                                ? _removeEditTag(tag)
                                : setState(() => _localTags.remove(tag)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    )
                    .toList(),
              ),
            ],
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
