import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    // App opens on the calendar tab; both tabs exist in the bottom nav.
    expect(find.text('달력'), findsWidgets); // AppBar title + nav label
    expect(find.text('목록'), findsOneWidget); // nav label
  });
}
