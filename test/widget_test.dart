import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    expect(find.text('Todo List'), findsOneWidget);
  });
}
