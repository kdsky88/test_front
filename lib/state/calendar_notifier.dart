import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/todo_api.dart';

enum CalendarStatus { idle, loading, error }

class CalendarNotifier extends ChangeNotifier {
  late int _year;
  late int _month;
  late DateTime _selectedDate;
  Map<String, List<Todo>> _calendarData = {};
  CalendarStatus _status = CalendarStatus.idle;
  String? _error;
  int _seq = 0;

  final Set<String> _processingIds = {};
  final Map<String, String> _itemErrors = {};

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

  List<Todo> get selectedDateTodos => _calendarData[_dateKey(_selectedDate)] ?? [];

  bool hasTodos(DateTime date) => (_calendarData[_dateKey(date)]?.isNotEmpty ?? false);

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

  Future<void> loadCalendar() async {
    _status = CalendarStatus.loading;
    _error = null;
    notifyListeners();

    final seq = ++_seq;
    try {
      final data = await TodoApi.getCalendar(year: _year, month: _month);
      if (seq != _seq) return;
      _calendarData = data;
      _status = CalendarStatus.idle;
      notifyListeners();
    } on ApiException catch (e) {
      if (seq != _seq) return;
      _status = CalendarStatus.error;
      _error = e.error.message;
      notifyListeners();
    } catch (_) {
      if (seq != _seq) return;
      _status = CalendarStatus.error;
      _error = '서버에 연결할 수 없습니다. 다시 시도해주세요.';
      notifyListeners();
    }
  }

  Future<void> prevMonth() async {
    if (_month == 1) {
      _year -= 1;
      _month = 12;
    } else {
      _month -= 1;
    }
    _selectedDate = DateTime(_year, _month, 1);
    await loadCalendar();
  }

  Future<void> nextMonth() async {
    if (_month == 12) {
      _year += 1;
      _month = 1;
    } else {
      _month += 1;
    }
    _selectedDate = DateTime(_year, _month, 1);
    await loadCalendar();
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
        e.key: e.value.map((t) => t.id == id ? updated : t).toList(),
    };
  }

  void _removeTodo(String id) {
    _calendarData = {
      for (final e in _calendarData.entries)
        e.key: e.value.where((t) => t.id != id).toList(),
    };
  }
}
