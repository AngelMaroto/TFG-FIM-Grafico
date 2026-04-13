// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

// ── Paleta ──────────────────────────────────────────────────────────────────
// Tema oscuro inspirado en terminales de seguridad: fondo casi negro,
// acentos en verde "matrix", tipografía monoespaciada para rutas de ficheros.

class AppColors {
  AppColors._();

  // Fondos
  static const Color background     = Color(0xFF0D0F14);
  static const Color surface        = Color(0xFF161922);
  static const Color surfaceVariant = Color(0xFF1E2230);
  static const Color border         = Color(0xFF2A2F3E);

  // Primario: verde terminal
  static const Color primary        = Color(0xFF00E676);
  static const Color primaryDim     = Color(0xFF00C853);
  static const Color onPrimary      = Color(0xFF0D0F14);

  // Texto
  static const Color textPrimary    = Color(0xFFE8EAF0);
  static const Color textSecondary  = Color(0xFF8B92A8);
  static const Color textDisabled   = Color(0xFF454D63);

  // ── Colores de eventos FIM (según memoria: RF-08) ────────────────────────
  static const Color eventNew       = Color(0xFF29B6F6);  // Azul  → NEW
  static const Color eventModified  = Color(0xFFFFB300);  // Ámbar → MODIFIED
  static const Color eventDeleted   = Color(0xFFEF5350);  // Rojo  → DELETED
  static const Color eventClean     = Color(0xFF00E676);  // Verde → sin cambios
  static const Color eventPerms     = Color(0xFFAB47BC);  // Morado→ PERMISSIONS

  // Severidades
  static const Color severityHigh   = Color(0xFFEF5350);
  static const Color severityMedium = Color(0xFFFFB300);
  static const Color severityLow    = Color(0xFF29B6F6);
}

class AppTextStyles {
  AppTextStyles._();

  // Fuente monoespaciada para rutas y hashes
  static const String monoFont    = 'JetBrains Mono';
  // Fuente principal UI
  static const String displayFont = 'Syne';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFont,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: displayFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: monoFont,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle path = TextStyle(
    fontFamily: monoFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle hash = TextStyle(
    fontFamily: monoFont,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textDisabled,
    letterSpacing: 0.5,
  );
}

// ── ThemeData ────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary:         AppColors.primary,
      onPrimary:       AppColors.onPrimary,
      surface:         AppColors.surface,
      onSurface:       AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      outline:         AppColors.border,
      error:           AppColors.eventDeleted,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 16),
    textTheme: const TextTheme(
      displayLarge:  AppTextStyles.displayLarge,
      titleMedium:   AppTextStyles.titleMedium,
      bodySmall:     AppTextStyles.bodySmall,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:  AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: AppTextStyles.displayLarge,
      iconTheme: IconThemeData(color: AppColors.textSecondary),
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: AppTextStyles.bodySmall,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    ),
  );
}

// ── Helper: color por tipo de evento ────────────────────────────────────────
Color eventColor(String tipo) {
  switch (tipo.toUpperCase()) {
    case 'NEW':         return AppColors.eventNew;
    case 'MODIFIED':    return AppColors.eventModified;
    case 'DELETED':     return AppColors.eventDeleted;
    case 'PERMISSIONS': return AppColors.eventPerms;
    default:            return AppColors.eventClean;
  }
}

Color severityColor(String severidad) {
  switch (severidad.toUpperCase()) {
    case 'ALTA':  return AppColors.severityHigh;
    case 'MEDIA': return AppColors.severityMedium;
    case 'BAJA':  return AppColors.severityLow;
    default:      return AppColors.textDisabled;
  }
}
