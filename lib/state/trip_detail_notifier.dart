import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/trip_api.dart';

class TripDetailNotifier extends ChangeNotifier {
  TripDetailNotifier(
    this.tripId, {
    Future<List<Todo>> Function(String)? fetch,
    Future<List<Todo>> Function(String)? cached,
  }) : _fetch = fetch ?? TripApi.getTripTodos,
       _cached = cached ?? TripApi.cachedTripTodos;
  final String tripId;
  final Future<List<Todo>> Function(String) _fetch;
  final Future<List<Todo>> Function(String) _cached;
  List<Todo>? todos;
  bool loading = true;
  bool offline = false;
  String? error;
  int _sequence = 0;
  bool _disposed = false;

  Future<void> load() async {
    if (_disposed) return;
    final sequence = ++_sequence;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _fetch(tripId);
      if (_disposed || sequence != _sequence) return;
      todos = result;
      offline = false;
    } on ApiException catch (e) {
      if (_disposed || sequence != _sequence) return;
      error = e.error.message;
    } catch (_) {
      try {
        final result = await _cached(tripId);
        if (_disposed || sequence != _sequence) return;
        if (result.isEmpty) {
          error = '서버에 연결할 수 없습니다.';
        } else {
          todos = result;
          offline = true;
        }
      } catch (_) {
        if (_disposed || sequence != _sequence) return;
        error = '저장된 일정을 불러올 수 없습니다.';
      }
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    super.dispose();
  }
}
