// lib/presentation/pages/splash_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Pantalla de inicio: verifica conexión con el backend antes de entrar.
/// Por ahora navega directamente a /home (implementación completa en siguiente fase).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security, size: 64, color: AppColors.primary),
            const SizedBox(height: 24),
            Text('FIM Monitor',
                style: AppTextStyles.displayLarge.copyWith(fontSize: 32)),
            const SizedBox(height: 8),
            Text('Auditoría de Sistemas Linux',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 48),
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
