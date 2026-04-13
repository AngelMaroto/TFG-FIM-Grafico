// lib/presentation/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../../presentation/pages/splash_page.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/settings_page.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
}
