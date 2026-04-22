import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/moment_provider.dart';
import 'screens/home_screen.dart';
import 'screens/add_moment_screen.dart';
import 'screens/moment_detail_screen.dart';
import 'screens/edit_moment_screen.dart';
import 'screens/login_screen.dart';
import 'sqflite_platform.dart';
import 'widgets/liquid_glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSqfliteForPlatform();
  runApp(const MomentApp());
}

class MomentApp extends StatelessWidget {
  const MomentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..initialize(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MomentProvider>(
          create: (_) => MomentProvider(),
          update: (_, auth, moments) {
            final provider = moments ?? MomentProvider();
            provider.bindUser(auth.user?.id);
            return provider;
          },
        ),
      ],
      child: const _AppWithRouter(),
    );
  }
}

class _AppWithRouter extends StatelessWidget {
  const _AppWithRouter();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kLiquidGlassAccent,
        brightness: Brightness.light,
      ).copyWith(
        primary: kLiquidGlassAccent,
        secondary: const Color(0xFF89A8FF),
        surface: Colors.white.withOpacity(0.18),
        surfaceContainerHighest: Colors.white.withOpacity(0.24),
        onSurface: kLiquidGlassInk,
      ),
    );

    return MaterialApp.router(
      title: '拾光记',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        textTheme: base.textTheme.apply(
          bodyColor: kLiquidGlassInk,
          displayColor: kLiquidGlassInk,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: kLiquidGlassInk,
          titleTextStyle: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: kLiquidGlassInk,
            letterSpacing: -0.8,
          ),
        ),
        cardColor: Colors.white.withOpacity(0.2),
        cardTheme: CardTheme(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white.withOpacity(0.2),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.42)),
          ),
        ),
        dividerColor: Colors.white.withOpacity(0.42),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.2),
          hintStyle: const TextStyle(color: kLiquidGlassMuted),
          labelStyle: const TextStyle(color: kLiquidGlassMuted),
          prefixIconColor: kLiquidGlassMuted,
          suffixIconColor: kLiquidGlassMuted,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.42)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: kLiquidGlassAccent, width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: kLiquidGlassAccent,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kLiquidGlassAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kLiquidGlassInk,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            side: BorderSide(color: Colors.white.withOpacity(0.46)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kLiquidGlassAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kLiquidGlassInk.withOpacity(0.88),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.white.withOpacity(0.22),
          modalBackgroundColor: Colors.white.withOpacity(0.22),
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white.withOpacity(0.92),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withOpacity(0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withOpacity(0.42)),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kLiquidGlassAccent,
        ),
      ),
      routerConfig: _router,
      builder: (context, child) {
        // 等待认证状态初始化完成
        if (!authProvider.isInitialized) {
          return const Scaffold(
            body: LiquidGlassBackground(
              child: Center(
                child: LiquidGlassCard(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        '正在唤醒你的时光',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }

  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authProvider = context.read<AuthProvider>();
      final isLoggedIn = authProvider.isLoggedIn;
      final isLoggingIn = state.matchedLocation == '/login';

      // 未登录且不在登录页，重定向到登录页
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 已登录且在登录页，重定向到首页
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      // 登录页
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // 首页（需登录）
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      // 添加记录页
      GoRoute(
        path: '/add',
        name: 'add',
        builder: (context, state) => const AddMomentScreen(),
      ),
      // 记录详情页
      GoRoute(
        path: '/detail/:id',
        name: 'detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MomentDetailScreen(recordId: id);
        },
      ),
      // 编辑记录页
      GoRoute(
        path: '/edit/:id',
        name: 'edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditMomentScreen(recordId: id);
        },
      ),
    ],
  );
}
