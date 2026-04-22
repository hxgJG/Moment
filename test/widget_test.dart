import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moment/main.dart';
import 'package:moment/providers/auth_provider.dart';
import 'package:moment/screens/login_screen.dart';
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
    expect(find.textContaining('auth-ui'), findsNothing);
  });

  testWidgets('Login screen toggles nickname field in register mode',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('昵称'), findsNothing);

    await tester.tap(find.text('注册').first);
    await tester.pumpAndSettle();
    expect(find.text('昵称'), findsOneWidget);

    await tester.tap(find.text('登录').first);
    await tester.pumpAndSettle();
    expect(find.text('昵称'), findsNothing);
  });
}
