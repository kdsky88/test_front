import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/widgets/todo_form_dialog.dart';

void main() {
  group('resolveDueForStart (시작 바꾸면 마감도 이동)', () {
    final start = DateTime(2026, 7, 14, 14, 0);

    test('이전 시작 없고 마감도 없으면 시작 +1시간', () {
      expect(resolveDueForStart(start, null, null), DateTime(2026, 7, 14, 15, 0));
    });

    test('첫 선택(이전=마감=자정, 간격 0) → 시작 +1시간으로 보정', () {
      final midnight = DateTime(2026, 7, 14, 0, 0);
      expect(
        resolveDueForStart(start, midnight, midnight),
        DateTime(2026, 7, 14, 15, 0),
      );
    });

    test('간격 유지: 시작 +2시간 이동하면 마감도 +2시간', () {
      final oldStart = DateTime(2026, 7, 14, 14, 0);
      final due = DateTime(2026, 7, 14, 15, 0); // 간격 1시간
      final newStart = DateTime(2026, 7, 14, 16, 0);
      expect(
        resolveDueForStart(newStart, oldStart, due),
        DateTime(2026, 7, 14, 17, 0), // 간격 1시간 유지
      );
    });

    test('간격 유지: 시작을 앞당기면 마감도 앞당겨짐', () {
      final oldStart = DateTime(2026, 7, 14, 16, 0);
      final due = DateTime(2026, 7, 14, 20, 0); // 간격 4시간
      final newStart = DateTime(2026, 7, 14, 10, 0);
      expect(
        resolveDueForStart(newStart, oldStart, due),
        DateTime(2026, 7, 14, 14, 0), // 간격 4시간 유지
      );
    });

    test('이동 결과가 시작 이후가 아니면 시작 +1시간으로 보정', () {
      final oldStart = DateTime(2026, 7, 14, 14, 0);
      final due = DateTime(2026, 7, 14, 14, 0); // 간격 0
      final newStart = DateTime(2026, 7, 14, 18, 0);
      expect(
        resolveDueForStart(newStart, oldStart, due),
        DateTime(2026, 7, 14, 19, 0),
      );
    });
  });
}
