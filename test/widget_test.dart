import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moment/main.dart';
import 'package:moment/sqflite_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initSqfliteForPlatform();
  });

  testWidgets('App starts on login screen when no session exists',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MomentApp());
    await tester.pumpAndSettle();

    expect(find.text('拾光记'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
