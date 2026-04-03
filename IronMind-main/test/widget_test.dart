import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/main.dart';

void main() {
  testWidgets('shows the IronMind launch screen', (WidgetTester tester) async {
    await tester.pumpWidget(const IronMindApp());

    expect(find.text('IRONMIND'), findsOneWidget);
  });
}
