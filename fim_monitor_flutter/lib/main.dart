// lib/main.dart
import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const FimMonitorApp());
}

class FimMonitorApp extends StatelessWidget {
  const FimMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FIM Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
    );
  }
}
