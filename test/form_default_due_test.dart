import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/widgets/todo_form_dialog.dart';

void main() {
  group('resolveDefaultDue (시작 시각 → 마감 기본값)', () {
    final start = DateTime(2026, 7, 14, 14, 0);

    test('마감이 없으면 시작 +1시간', () {
      expect(resolveDefaultDue(start, null), DateTime(2026, 7, 14, 15, 0));
    });

    test('마감이 시작보다 앞이면 시작 +1시간으로 덮음', () {
      final due = DateTime(2026, 7, 14, 0, 0); // 생성 기본값(자정) 등
      expect(resolveDefaultDue(start, due), DateTime(2026, 7, 14, 15, 0));
    });

    test('마감이 시작과 같으면 시작 +1시간', () {
      expect(resolveDefaultDue(start, start), DateTime(2026, 7, 14, 15, 0));
    });

    test('마감이 이미 시작보다 늦으면 그대로 유지', () {
      final due = DateTime(2026, 7, 14, 20, 0);
      expect(resolveDefaultDue(start, due), due);
    });
  });
}
