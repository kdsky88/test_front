import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_front/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TodoApp());
    // 첫 실행 안내 통과 → 로그인 화면.
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsWidgets);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('회원가입으로 이동'), findsOneWidget);
  });
}
