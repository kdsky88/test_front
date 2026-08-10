import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/todo_api.dart';

enum CalendarStatus { idle, loading, error }

List<Todo> sortCalendarTodosByPriority(Iterable<Todo> todos) {
  final indexedTodos = todos.indexed.toList();
  indexedTodos.sort((a, b) {
    // 완료 항목은 항상 아래로
    final completedOrder = (a.$2.completed ? 1 : 0).compareTo(
      b.$2.completed ? 1 : 0,
    );
    if (completedOrder != 0) return completedOrder;
    final priorityOrder = a.$2.priority.index.compareTo(b.$2.priority.index);
    return priorityOrder != 0 ? priorityOrder : a.$1.compareTo(b.$1);
  });
  return indexedTodos.map((entry) => entry.$2).toList();
}

class CalendarNotifier extends ChangeNotifier {
  late int _year;
  late int _month;
  late DateTime _selectedDate;
  Map<String, List<Todo>> _calendarData = {};
  CalendarStatus _status = CalendarStatus.idle;
  String? _error;
  int _seq = 0;

  // 방문한 달의 데이터 캐시: 넘길 때 즉시 표시 + 백그라운드로 갱신(스피너·깜빡임 방지).
  final Map<String, Map<String, List<Todo>>> _monthCache = {};
  String get _monthKey => '$_year-$_month';

  // 백그라운드(silent) 로딩 중 여부 — 첫 방문 달 상단 얇은 인디케이터용.
  bool _bgLoading = false;
  bool get backgroundLoading => _bgLoading;

  // 최근 월 이동 방향(+1 다음, -1 이전) — 그리드 슬라이드 애니메이션 방향.
  int _lastDelta = 1;
  int get lastMonthDelta => _lastDelta;

  final Set<String> _processingIds = {};
  final Map<String, String> _itemErrors = {};

  // Called after a successful server mutation so the app shell can refresh the
  // other view immediately (after the change is persisted — avoids races).
  void Function()? onMutated;

  CalendarNotifier() {
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  int get year => _year;
  int get month => _month;
  DateTime get selectedDate => _selectedDate;
  CalendarStatus get status => _status;
  String? get error => _error;

  List<Todo> get selectedDateTodos =>
      _calendarData[_dateKey(_selectedDate)] ?? [];

  /// 날짜키(yyyy-MM-dd) → 그 날짜에 걸치는 할 일 목록 (멀티데이 막대 계산용).
  Map<String, List<Todo>> get calendarData => _calendarData;

  bool hasTodos(DateTime date) =>
      (_calendarData[_dateKey(date)]?.isNotEmpty ?? false);

  bool isProcessing(String id) => _processingIds.contains(id);
  String? itemError(String id) => _itemErrors[id];

  void clearItemError(String id) {
    _itemErrors.remove(id);
    notifyListeners();
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  /// [silent] keeps the existing grid on screen during the reload (no loading
  /// state), used for background refresh when the calendar tab is shown.
  Future<void> loadCalendar({bool silent = false}) async {
    if (silent) {
      _bgLoading = true;
    } else {
      _status = CalendarStatus.loading;
      _error = null;
    }
    notifyListeners();

    final seq = ++_seq;
    try {
      final data = await TodoApi.getCalendar(year: _year, month: _month);
      if (seq != _seq) return;
      _calendarData = {
        for (final entry in data.entries)
          entry.key: sortCalendarTodosByPriority(entry.value),
      };
      _monthCache[_monthKey] = _calendarData;
      _status = CalendarStatus.idle;
      _bgLoading = false;
      _error = null;
      notifyListeners();
    } on ApiException catch (e) {
      if (seq != _seq) return;
      _bgLoading = false;
      if (silent) {
        notifyListeners(); // 인디케이터만 내림(기존 데이터 유지)
        return;
      }
      _status = CalendarStatus.error;
      _error = e.error.message;
      notifyListeners();
    } catch (error) {
      if (seq != _seq) return;
      _bgLoading = false;
      if (silent) {
        notifyListeners();
        return;
      }
      _status = CalendarStatus.error;
      _error = _dataErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> prevMonth() => _changeMonth(-1);

  Future<void> nextMonth() => _changeMonth(1);

  Future<void> _changeMonth(int delta) async {
    _lastDelta = delta;
    final m = _month + delta;
    if (m < 1) {
      _year -= 1;
      _month = 12;
    } else if (m > 12) {
      _year += 1;
      _month = 1;
    } else {
      _month = m;
    }
    // 오늘이 있는 달로 오면 오늘 자동 선택, 그 외 달은 1일 선택.
    final now = DateTime.now();
    _selectedDate = (_year == now.year && _month == now.month)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(_year, _month, 1);
    // 캐시가 있으면 즉시 막대 표시, 없으면 빈 그리드 → 새 달이 스피너 없이 바로 뜸.
    _calendarData = _monthCache[_monthKey] ?? {};
    _status = CalendarStatus.idle;
    notifyListeners();
    await loadCalendar(silent: true); // 뒤에서 조용히 최신화
  }

  Future<void> toggleComplete(String id) async {
    if (_processingIds.contains(id)) return;

    final dateKey = _findDateKeyForId(id);
    if (dateKey == null) return;
    final todo = _calendarData[dateKey]!.firstWhere((t) => t.id == id);
    final newCompleted = !todo.completed;

    _processingIds.add(id);
    _itemErrors.remove(id);
    notifyListeners();

    try {
      final updated = await TodoApi.updateTodo(id: id, completed: newCompleted);
      _processingIds.remove(id);
      _replaceTodo(id, updated);
      onMutated?.call();
      notifyListeners();
    } on ApiException catch (e) {
      _processingIds.remove(id);
      _itemErrors[id] = e.error.message;
      notifyListeners();
    } catch (_) {
      _processingIds.remove(id);
      _itemErrors[id] = '완료 상태를 변경할 수 없습니다.';
      notifyListeners();
    }
  }

  Future<bool> deleteTodo(String id) async {
    if (_processingIds.contains(id)) return false;

    _processingIds.add(id);
    _itemErrors.remove(id);
    notifyListeners();

    try {
      await TodoApi.deleteTodo(id);
      _processingIds.remove(id);
      _removeTodo(id);
      onMutated?.call();
      await loadCalendar();
      return true;
    } on ApiException catch (e) {
      _processingIds.remove(id);
      if (e.error.code == 'TODO_NOT_FOUND') {
        await loadCalendar();
        return true;
      }
      _itemErrors[id] = e.error.message;
      notifyListeners();
      return false;
    } catch (_) {
      _processingIds.remove(id);
      _itemErrors[id] = '삭제할 수 없습니다. 다시 시도해주세요.';
      notifyListeners();
      return false;
    }
  }

  String? _findDateKeyForId(String id) {
    for (final entry in _calendarData.entries) {
      if (entry.value.any((t) => t.id == id)) return entry.key;
    }
    return null;
  }

  void _replaceTodo(String id, Todo updated) {
    _calendarData = {
      for (final e in _calendarData.entries)
        e.key: sortCalendarTodosByPriority(
          e.value.map((t) => t.id == id ? updated : t),
        ),
    };
    _monthCache[_monthKey] = _calendarData;
  }

  void _removeTodo(String id) {
    _calendarData = {
      for (final e in _calendarData.entries)
        e.key: e.value.where((t) => t.id != id).toList(),
    };
    _monthCache[_monthKey] = _calendarData;
  }

  String _dataErrorMessage(Object error) {
    if (error is FormatException || error is TypeError) {
      return '응답 데이터가 올바르지 않습니다. 다시 시도해주세요.';
    }
    return '서버에 연결할 수 없습니다. 다시 시도해주세요.';
  }
}
