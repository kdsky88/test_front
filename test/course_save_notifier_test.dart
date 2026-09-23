import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/state/course_save_notifier.dart';

void main() {
  test(
    'partial save reports actual count; retry excludes successful items',
    () async {
      final calls = <int>[];
      var fail = true;
      final state = CourseSaveNotifier(3, (i) async {
        calls.add(i);
        return i == 1 && fail ? '저장 실패' : null;
      });
      addTearDown(state.dispose);
      await state.run();
      expect(state.saved, {0, 2});
      expect(state.errors.keys, [1]);
      fail = false;
      await state.run();
      expect(calls, [0, 1, 2, 1]);
      expect(state.saved.length, 3);
      expect(state.errors, isEmpty);
    },
  );

  test('double submission starts only one write', () async {
    final pending = Completer<String?>();
    var calls = 0;
    final state = CourseSaveNotifier(1, (_) {
      calls++;
      return pending.future;
    });
    addTearDown(state.dispose);
    final first = state.run();
    await state.run();
    expect(calls, 1);
    pending.complete(null);
    await first;
    expect(state.saved.length, 1);
  });

  test('unexpected error ends loading without claiming success', () async {
    final state = CourseSaveNotifier(
      1,
      (_) async => throw Exception('offline'),
    );
    addTearDown(state.dispose);
    await state.run();
    expect(state.busy, isFalse);
    expect(state.saved, isEmpty);
    expect(state.errors, hasLength(1));
  });
}
