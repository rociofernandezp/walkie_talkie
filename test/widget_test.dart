import 'package:flutter_test/flutter_test.dart';
import 'package:walkie_talkie/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const WalkieTalkieApp());

    expect(find.text('Hablar'), findsOneWidget);
  });
}

