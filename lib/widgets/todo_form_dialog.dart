import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/todo.dart';
import '../models/trip.dart';
import '../screens/location_picker_screen.dart';
import '../services/trip_api.dart';
import '../state/todo_notifier.dart';

/// 시작 시각이 바뀌면 마감도 함께 이동시킬 값.
/// 이전 시작·마감이 있으면 그 간격만큼 마감을 평행 이동(같이 움직임),
/// 없으면 시작+1시간. 결과가 시작 이후가 아니면 시작+1시간으로 보정.
DateTime resolveDueForStart(
  DateTime newStart,
  DateTime? oldStart,
  DateTime? currentDue,
) {
  DateTime due;
  if (oldStart != null && currentDue != null) {
    due = currentDue.add(newStart.difference(oldStart)); // 간격 유지 평행 이동
  } else if (currentDue != null) {
    due = currentDue;
  } else {
    due = newStart.add(const Duration(hours: 1));
  }
  if (!due.isAfter(newStart)) {
    due = newStart.add(const Duration(hours: 1));
  }
  return due;
}

class TodoFormDialog extends StatefulWidget {
  final Todo? todo;
  final TodoNotifier notifier;
  final DateTime? initialDueAt;

  /// 여행 상세에서 열 때: 이 여행으로 고정(드롭다운 잠금) + 날짜를 여행 기간으로 제한.
  final Trip? lockedTrip;

  const TodoFormDialog({
    super.key,
    this.todo,
    required this.notifier,
    this.initialDueAt,
    this.lockedTrip,
  });

  @override
  State<TodoFormDialog> createState() => _TodoFormDialogState();
}

class _TodoFormDialogState extends State<TodoFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _tagCtrl;
  late final TextEditingController _subtaskCtrl;
  late final TextEditingController _assignedToCtrl;
  DateTime? _startAt;
  DateTime? _dueAt;
  late TodoPriority _priority;
  late TodoRecurrence _recurrence;
  List<Trip>? _trips; // null=로딩 중, []=없음/로드 실패
  String? _selectedTripId;
  double? _lat;
  double? _lng;
  String? _placeName;
  bool _locationCleared = false;
  bool _submitting = false;
  String? _generalError;
  String? _titleError;
  String? _noteError;
  String? _startAtError;
  String? _dueAtError;
  String? _priorityError;
  String? _recurrenceError;

  // Create mode: locally collected tags
  final List<String> _localTags = [];

  // Edit mode: server-synced tags (immediate apply)
  late List<String> _editTags;
  bool _tagProcessing = false;
  String? _tagError;

  // 하위 항목은 로컬로 편집하고 저장 시 통째로 반영(태그와 달리 개별 API 없음).
  late List<Subtask> _subtasks;
  String? _subtaskError;

  bool get _isEdit => widget.todo != null;

  // 여행 기간으로 날짜를 제한할지(여행 고정 + 시작·종료일이 모두 있을 때만).
  bool get _dateConstrained =>
      widget.lockedTrip?.startDate != null && widget.lockedTrip?.endDate != null;

  DateTime get _pickerFirstDate {
    if (!_dateConstrained) return DateTime(2000);
    final s = widget.lockedTrip!.startDate!;
    return DateTime(s.year, s.month, s.day); // 그 날 00:00
  }

  DateTime get _pickerLastDate {
    if (!_dateConstrained) return DateTime(2100);
    final e = widget.lockedTrip!.endDate!;
    return DateTime(e.year, e.month, e.day, 23, 59, 59); // 그 날 끝까지 허용
  }

  DateTime _clampToRange(DateTime d) {
    if (d.isBefore(_pickerFirstDate)) return _pickerFirstDate;
    if (d.isAfter(_pickerLastDate)) return _pickerLastDate;
    return d;
  }

  // 값이 없을 때 피커 기본: 제약 있으면 여행 시작일, 없으면 오늘.
  DateTime get _defaultPickDate => _dateConstrained ? _pickerFirstDate : DateTime.now();

  // 장소 UI를 보일 때: 여행에 추가 중이거나, 이미 위치가 있는 항목을 편집할 때.
  bool get _showLocation => widget.lockedTrip != null || widget.todo?.latitude != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.todo?.title ?? '');
    _noteCtrl = TextEditingController(text: widget.todo?.note ?? '');
    _tagCtrl = TextEditingController();
    _subtaskCtrl = TextEditingController();
    _assignedToCtrl = TextEditingController(
      text: widget.todo?.assignedToEmail ?? '',
    );
    _subtasks = List.of(widget.todo?.subtasks ?? const []);
    if (widget.todo != null) {
      // 수정: 기존 값 유지
      _startAt = widget.todo!.startAt;
      _dueAt = widget.todo!.dueAt;
    } else if (_dateConstrained) {
      // 여행에 추가: 달력에서 고른 날짜(initialDueAt) 09시, 없으면 여행 시작일. 범위로 클램프.
      final picked = widget.initialDueAt ?? widget.lockedTrip!.startDate!;
      final base = _clampToRange(DateTime(picked.year, picked.month, picked.day, 9));
      _startAt = base;
      _dueAt = base;
    } else {
      // 생성: 달력에서 왔으면 그 날짜, 아니면 오늘로 시작일·마감일 기본 채움
      final base = widget.initialDueAt ?? DateTime.now();
      _startAt = base;
      _dueAt = base;
    }
    // 여행 항목 신규 생성은 마감일 없음(필드도 숨김).
    if (widget.lockedTrip != null && widget.todo == null) _dueAt = null;
    _priority = widget.todo?.priority ?? TodoPriority.medium;
    _recurrence = widget.todo?.recurrence ?? TodoRecurrence.none;
    _editTags = List.of(widget.todo?.tags ?? []);
    // 여행 고정이면 그 여행으로, 아니면 기존 항목의 여행.
    _selectedTripId = widget.lockedTrip?.id ?? widget.todo?.tripId;
    // 장소는 편집 시 좌표 유실 방지를 위해 기존 값에서 시드.
    _lat = widget.todo?.latitude;
    _lng = widget.todo?.longitude;
    _placeName = widget.todo?.placeName;
    if (widget.lockedTrip == null) _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await TripApi.getTrips();
      if (mounted) setState(() => _trips = trips);
    } catch (_) {
      // 여행 목록 로드 실패 시 '여행 없음'만 선택 가능(기존 연결은 유지).
      if (mounted) setState(() => _trips = const []);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _tagCtrl.dispose();
    _subtaskCtrl.dispose();
    _assignedToCtrl.dispose();
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

    String? recurErr;
    if (_recurrence != TodoRecurrence.none && _dueAt == null) {
      recurErr = '반복 일정은 마감일이 필요합니다.';
    }

    setState(() {
      _titleError = titleErr;
      _noteError = noteErr;
      _startAtError = startErr;
      _recurrenceError = recurErr;
    });

    return titleErr == null &&
        noteErr == null &&
        startErr == null &&
        recurErr == null;
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
      _recurrenceError = null;
    });

    final normalizedTitle = _normalizeTitle(_titleCtrl.text);
    final note = _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null;
    final startAtStr = _startAt?.toUtc().toIso8601String();
    final dueAtStr = _dueAt?.toUtc().toIso8601String();
    final assignedEmail = _assignedToCtrl.text.trim();

    String? errorMsg;
    String? titleErr;
    String? noteErr;
    String? startErr;
    String? dueErr;
    String? priorityErr;
    String? recurErr;

    if (_isEdit) {
      final todo = widget.todo!;
      final (_, apiEx, msg) = await widget.notifier.updateTodo(
        id: todo.id,
        title: normalizedTitle,
        priority: _priority,
        note: note,
        startAt: startAtStr,
        dueAt: dueAtStr,
        recurrence: _recurrence.apiValue,
        assignedToEmail: assignedEmail.isEmpty ? null : assignedEmail,
        tripId: _selectedTripId,
        subtasks: List.of(_subtasks),
        clearNote: note == null,
        clearStartAt: _startAt == null,
        clearDueAt: _dueAt == null,
        clearAssignedTo: assignedEmail.isEmpty,
        clearTrip: _selectedTripId == null,
        latitude: _lat,
        longitude: _lng,
        placeName: _placeName,
        clearLocation: _locationCleared,
      );
      if (msg != null) {
        errorMsg = msg;
        if (apiEx != null) {
          titleErr = apiEx.error.fields?['title'];
          noteErr = apiEx.error.fields?['note'];
          startErr = apiEx.error.fields?['startAt'];
          dueErr = apiEx.error.fields?['dueAt'];
          priorityErr = apiEx.error.fields?['priority'];
          recurErr = apiEx.error.fields?['recurrence'];
          if (titleErr != null ||
              noteErr != null ||
              startErr != null ||
              dueErr != null ||
              priorityErr != null ||
              recurErr != null) {
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
        recurrence: _recurrence.apiValue,
        assignedToEmail: assignedEmail.isEmpty ? null : assignedEmail,
        tripId: _selectedTripId,
        latitude: _lat,
        longitude: _lng,
        placeName: _placeName,
        tags: List.of(_localTags),
        subtasks: List.of(_subtasks),
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (errorMsg == null &&
        titleErr == null &&
        noteErr == null &&
        startErr == null &&
        dueErr == null &&
        priorityErr == null &&
        recurErr == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _generalError = errorMsg;
        _titleError = titleErr;
        _noteError = noteErr;
        _startAtError = startErr;
        _dueAtError = dueErr;
        _priorityError = priorityErr;
        _recurrenceError = recurErr;
      });
    }
  }

  Future<void> _pickDueAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampToRange(_dueAt ?? _defaultPickDate),
      firstDate: _pickerFirstDate,
      lastDate: _pickerLastDate,
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampToRange(_startAt ?? _defaultPickDate),
      firstDate: _pickerFirstDate,
      lastDate: _pickerLastDate,
    );
    if (!mounted || picked == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _startAt != null
          ? TimeOfDay.fromDateTime(_startAt!)
          : TimeOfDay.now(),
    );
    if (!mounted || time == null) return;

    final newStart = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
    // 시작을 바꾸면 마감도 같은 간격을 유지하며 따라 이동(여행 범위 밖이면 클램프).
    final newDue = _clampToRange(resolveDueForStart(newStart, _startAt, _dueAt));
    setState(() {
      _startAt = newStart;
      if (widget.lockedTrip == null) _dueAt = newDue; // 여행 항목은 마감일 없음
      _startAtError = null;
      _dueAtError = null;
    });
  }

  void _addSubtask() {
    final title = _subtaskCtrl.text.trim();
    if (title.isEmpty) return;
    if (title.length > 100) {
      setState(() => _subtaskError = '하위 항목은 100자 이하로 입력해주세요.');
      return;
    }
    if (_subtasks.length >= 50) {
      setState(() => _subtaskError = '하위 항목은 최대 50개까지 추가할 수 있습니다.');
      return;
    }
    setState(() {
      _subtasks.add(Subtask(title: title));
      _subtaskCtrl.clear();
      _subtaskError = null;
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

  Widget _buildLocationField() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _submitting ? null : _pickLocation,
            icon: const Icon(Icons.place_outlined, size: 20),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _lat == null ? '지도에서 선택' : (_placeName ?? '지정한 위치'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (_lat != null)
          IconButton(
            tooltip: '장소 제거',
            icon: const Icon(Icons.clear, size: 18),
            onPressed: _submitting ? null : _clearLocation,
          ),
      ],
    );
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
          initialName: _placeName,
          // 위치가 아직 없고 여행 목적지가 있으면 그 지역 추천을 자동으로 띄운다.
          initialQuery: (_lat == null && _lng == null) ? widget.lockedTrip?.destination : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lat = result.lat;
      _lng = result.lng;
      _placeName = result.name;
      _locationCleared = false;
    });
  }

  void _clearLocation() {
    setState(() {
      _lat = null;
      _lng = null;
      _placeName = null;
      _locationCleared = true; // 편집 시 서버 위치 해제
    });
  }

  Widget _buildTripDropdown(ThemeData theme) {
    // 여행 상세에서 열었으면 그 여행으로 고정(읽기 전용).
    if (widget.lockedTrip != null) {
      return InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.luggage, size: 20),
        ),
        child: Text(widget.lockedTrip!.title, overflow: TextOverflow.ellipsis),
      );
    }
    final trips = _trips ?? const <Trip>[];
    final ids = trips.map((t) => t.id).toSet();
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('여행 없음')),
      ...trips.map(
        (t) => DropdownMenuItem(
          value: t.id,
          child: Text(t.title, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
    // 편집 중인 항목의 여행이 아직/못 불러온 목록에 없으면 현재 값을 표시용으로 추가(드롭다운 값 보장).
    if (_selectedTripId != null && !ids.contains(_selectedTripId)) {
      items.add(DropdownMenuItem(
        value: _selectedTripId,
        child: Text(widget.todo?.tripTitle ?? '(선택된 여행)', overflow: TextOverflow.ellipsis),
      ));
    }
    return DropdownButtonFormField<String?>(
      initialValue: _selectedTripId,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.luggage_outlined, size: 20),
        hintText: _trips == null ? '불러오는 중…' : null,
      ),
      items: items,
      onChanged: (_submitting || _trips == null)
          ? null
          : (value) => setState(() => _selectedTripId = value),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _submitting ? null : onPick,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: errorText,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.event_outlined, size: 20),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: '$label 제거',
                  onPressed: _submitting ? null : onClear,
                )
              : const Icon(Icons.chevron_right, size: 20),
        ),
        child: Text(
          value != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal())
              : '선택 안 함',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: value != null
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTags = _isEdit ? _editTags : _localTags;
    // 여행 컨텍스트에서는 마감일·반복·여행 선택을 숨김(불필요).
    final inTrip = widget.lockedTrip != null;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '할 일 수정' : '할 일 등록')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('제목 *', style: labelStyle),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: '할 일 제목',
                  errorText: _titleError,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                maxLength: 110,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Text('메모(상세 설명)', style: labelStyle),
              const SizedBox(height: 6),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  hintText: '메모를 입력하세요',
                  errorText: _noteError,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                minLines: 3,
                maxLines: 6,
                maxLength: 1010,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Text('우선순위', style: labelStyle),
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
              const SizedBox(height: 14),
              Text('시작일', style: labelStyle),
              const SizedBox(height: 6),
              _buildDateField(
                label: '시작일',
                value: _startAt,
                onPick: _pickStartAt,
                onClear: () => setState(() {
                  _startAt = null;
                  _startAtError = null;
                }),
                errorText: _startAtError,
              ),
              if (!inTrip) ...[
                const SizedBox(height: 14),
                Text('마감일', style: labelStyle),
                const SizedBox(height: 6),
                _buildDateField(
                  label: '마감일',
                  value: _dueAt,
                  onPick: _pickDueAt,
                  onClear: () => setState(() {
                    _dueAt = null;
                    _startAtError = null;
                  }),
                  errorText: _dueAtError,
                ),
                const SizedBox(height: 14),
                Text('반복', style: labelStyle),
                const SizedBox(height: 6),
                SegmentedButton<TodoRecurrence>(
                  segments: TodoRecurrence.values
                      .map(
                        (r) => ButtonSegment<TodoRecurrence>(
                          value: r,
                          label: Text(r.shortLabel),
                        ),
                      )
                      .toList(),
                  selected: {_recurrence},
                  onSelectionChanged: _submitting
                      ? null
                      : (selected) {
                          setState(() {
                            _recurrence = selected.first;
                            _recurrenceError = null;
                          });
                        },
                ),
                if (_recurrenceError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _recurrenceError!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
              if (!inTrip) ...[
                const SizedBox(height: 14),
                Text('담당자 (공유)', style: labelStyle),
                const SizedBox(height: 6),
                TextField(
                  controller: _assignedToCtrl,
                  enabled: !_submitting,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: '가입된 사용자 이메일 (비우면 미지정)',
                    helperText: '이 사람의 목록에도 표시되고 완료할 수 있어요',
                    prefixIcon: Icon(Icons.person_add_alt, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                Text('여행', style: labelStyle),
                const SizedBox(height: 6),
                _buildTripDropdown(theme),
              ],
              const SizedBox(height: 14),
              if (_showLocation) ...[
                Text('장소', style: labelStyle),
                const SizedBox(height: 6),
                _buildLocationField(),
                const SizedBox(height: 14),
              ],
              Text('태그', style: labelStyle),
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
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: _submitting || _tagProcessing
                              ? null
                              : () => _isEdit
                                    ? _removeEditTag(tag)
                                    : setState(() => _localTags.remove(tag)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              Text('하위 항목 (체크리스트)', style: labelStyle),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskCtrl,
                      decoration: InputDecoration(
                        hintText: '하위 항목 입력 (최대 100자)',
                        errorText: _subtaskError,
                        isDense: true,
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                      maxLength: 100,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addSubtask(),
                      onChanged: (_) => setState(() => _subtaskError = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _addSubtask,
                      child: const Text('추가'),
                    ),
                  ),
                ],
              ),
              if (_subtasks.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...List.generate(_subtasks.length, (i) {
                  final sub = _subtasks[i];
                  return Row(
                    children: [
                      Checkbox(
                        value: sub.done,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: _submitting
                            ? null
                            : (v) => setState(
                                () => _subtasks[i] = sub.copyWith(done: v),
                              ),
                      ),
                      Expanded(
                        child: Text(
                          sub.title,
                          style: TextStyle(
                            decoration: sub.done
                                ? TextDecoration.lineThrough
                                : null,
                            color: sub.done
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: '삭제',
                        visualDensity: VisualDensity.compact,
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _subtasks.removeAt(i)),
                      ),
                    ],
                  );
                }),
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
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ),
    );
  }
}
