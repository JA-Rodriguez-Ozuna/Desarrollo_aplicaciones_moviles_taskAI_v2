import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_ai/main.dart';

void main() {
  testWidgets('TaskAI app renders without crash', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TaskAIApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('TaskAI'), findsOneWidget);
  });
}
