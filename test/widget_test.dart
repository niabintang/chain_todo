import 'package:flutter_test/flutter_test.dart';
import 'package:chain_todo/main.dart';

void main() {
  testWidgets('ChainTodoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChainTodoApp());
    expect(find.text('ChainTodo'), findsOneWidget);
  });
}
