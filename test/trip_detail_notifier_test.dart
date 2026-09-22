import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/models/todo.dart';
import 'package:test_front/state/trip_detail_notifier.dart';

void main() {
  test('older request cannot overwrite the latest result', () async {
    final first = Completer<List<Todo>>();
    var calls = 0;
    final state = TripDetailNotifier(
      'trip',
      fetch: (_) => ++calls == 1 ? first.future : Future.value([]),
    );
    addTearDown(state.dispose);
    final old = state.load();
    await state.load();
    first.completeError(Exception('old failed'));
    await old;
    expect(state.error, isNull);
    expect(state.todos, isEmpty);
    expect(state.loading, isFalse);
  });
  test('corrupt cache ends loading with a visible error', () async {
    final state = TripDetailNotifier(
      'trip',
      fetch: (_) async => throw Exception('offline'),
      cached: (_) async => throw const FormatException('corrupt'),
    );
    addTearDown(state.dispose);
    await state.load();
    expect(state.loading, isFalse);
    expect(state.error, isNotNull);
  });
  test('finishing request after dispose does not notify', () async {
    final pending = Completer<List<Todo>>();
    final state = TripDetailNotifier('trip', fetch: (_) => pending.future);
    final load = state.load();
    state.dispose();
    pending.complete([]);
    await load;
  });
}
