// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MomentApp());

    // Verify that the app title is displayed
    expect(find.text('拾光记'), findsOneWidget);
  });
}
