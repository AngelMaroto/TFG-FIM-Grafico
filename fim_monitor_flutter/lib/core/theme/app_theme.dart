// lib/core/theme/app_theme.dart
// v4 — paleta light slate (GitHub / Linear style)
//
// FimColors.light:
//   Fondo general : slate-50  #F8FAFC
//   Surface       : white     #FFFFFF
//   surfaceVariant: slate-100 #F1F5F9
//   Border        : slate-200 #E2E8F0
//   Texto primario: slate-900 #0F172A
//   Texto secundario: slate-500 #64748B
//   Acento / accent : sky-600  #0284C7
//   Primary (green) : green-600 #16A34A
//
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ThemeExtension
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class FimColors extends ThemeExtension<FimColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceCard;
  final Color border;
  final Color primary;
  final Color primaryDim;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color headerBg;
  final Color headerBorder;
  final Color filterBarBg;
  final Color itemBg;
  final Color itemBgExpanded;
  final Color itemBorder;
  final Color itemBorderExpanded;
  final Color timelineRailBg;
  final Color timelineRailBorder;
  final Color eventNew;
  final Color eventModified;
  final Color eventDeleted;
  final Color eventClean;
  final Color eventPerms;
  final Color severityHigh;
  final Color severityMedium;
  final Color severityLow;
  final Color accent;
  final Color dotsBg;

  const FimColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceCard,
    required this.border,
    required this.primary,
    required this.primaryDim,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.headerBg,
    required this.headerBorder,
    required this.filterBarBg,
    required this.itemBg,
    required this.itemBgExpanded,
    required this.itemBorder,
    required this.itemBorderExpanded,
    required this.timelineRailBg,
    required this.timelineRailBorder,
    required this.eventNew,
    required this.eventModified,
    required this.eventDeleted,
    required this.eventClean,
    required this.eventPerms,
    required this.severityHigh,
    required this.severityMedium,
    required this.severityLow,
    required this.accent,
    required this.dotsBg,
  });

  // ── DARK (sin cambios) ────────────────────────────────────────────────────
  static const dark = FimColors(
    background: Color(0xFF0D0F14),
    surface: Color(0xFF161922),
    surfaceVariant: Color(0xFF1E2230),
    surfaceCard: Color(0xFF0F1520),
    border: Color(0xFF2A2F3E),
    primary: Color(0xFF00E676),
    primaryDim: Color(0xFF00C853),
    onPrimary: Color(0xFF0D0F14),
    textPrimary: Color(0xFFE8EAF0),
    textSecondary: Color(0xFF8B92A8),
    textDisabled: Color(0xFF454D63),
    headerBg: Color(0xFF13192A),
    headerBorder: Color(0xFF1E2940),
    filterBarBg: Color(0xFF161922),
    itemBg: Color(0xFF0F1520),
    itemBgExpanded: Color(0xFF141C2E),
    itemBorder: Color(0xFF1A2540),
    itemBorderExpanded: Color(0xFF1A2540),
    timelineRailBg: Color(0xFF0A0F1A),
    timelineRailBorder: Color(0xFF1E2940),
    eventNew: Color(0xFF29B6F6),
    eventModified: Color(0xFFFFB300),
    eventDeleted: Color(0xFFEF5350),
    eventClean: Color(0xFF00E676),
    eventPerms: Color(0xFFAB47BC),
    severityHigh: Color(0xFFEF5350),
    severityMedium: Color(0xFFFFB300),
    severityLow: Color(0xFF29B6F6),
    accent: Color(0xFF00D4FF),
    dotsBg: Color(0xFF4B5563),
  );

  // ── LIGHT — Slate azulado frío ────────────────────────────────────────────
  static const light = FimColors(
    background: Color(0xFFF8FAFC), // slate-50
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F5F9), // slate-100
    surfaceCard: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0), // slate-200
    primary: Color(0xFF16A34A), // green-600
    primaryDim: Color(0xFF15803D), // green-700
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A), // slate-900
    textSecondary: Color(0xFF64748B), // slate-500
    textDisabled: Color(0xFF94A3B8), // slate-400
    headerBg: Color(0xFFFFFFFF),
    headerBorder: Color(0xFFE2E8F0), // slate-200
    filterBarBg: Color(0xFFF8FAFC), // slate-50
    itemBg: Color(0xFFFFFFFF),
    itemBgExpanded: Color(0xFFF1F5F9), // slate-100
    itemBorder: Color(0xFFE2E8F0), // slate-200
    itemBorderExpanded: Color(0xFFCBD5E1), // slate-300
    timelineRailBg: Color(0xFFFFFFFF),
    timelineRailBorder: Color(0xFFE2E8F0),
    eventNew: Color(0xFF0284C7), // sky-600
    eventModified: Color(0xFFD97706), // amber-600
    eventDeleted: Color(0xFFDC2626), // red-600
    eventClean: Color(0xFF16A34A), // green-600
    eventPerms: Color(0xFF7C3AED), // violet-600
    severityHigh: Color(0xFFDC2626), // red-600
    severityMedium: Color(0xFFD97706), // amber-600
    severityLow: Color(0xFF0284C7), // sky-600
    accent: Color(0xFF0284C7), // sky-600
    dotsBg: Color(0xFFCBD5E1), // slate-300
  );

  @override
  FimColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? surfaceCard,
    Color? border,
    Color? primary,
    Color? primaryDim,
    Color? onPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? headerBg,
    Color? headerBorder,
    Color? filterBarBg,
    Color? itemBg,
    Color? itemBgExpanded,
    Color? itemBorder,
    Color? itemBorderExpanded,
    Color? timelineRailBg,
    Color? timelineRailBorder,
    Color? eventNew,
    Color? eventModified,
    Color? eventDeleted,
    Color? eventClean,
    Color? eventPerms,
    Color? severityHigh,
    Color? severityMedium,
    Color? severityLow,
    Color? accent,
    Color? dotsBg,
  }) =>
      FimColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        surfaceCard: surfaceCard ?? this.surfaceCard,
        border: border ?? this.border,
        primary: primary ?? this.primary,
        primaryDim: primaryDim ?? this.primaryDim,
        onPrimary: onPrimary ?? this.onPrimary,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textDisabled: textDisabled ?? this.textDisabled,
        headerBg: headerBg ?? this.headerBg,
        headerBorder: headerBorder ?? this.headerBorder,
        filterBarBg: filterBarBg ?? this.filterBarBg,
        itemBg: itemBg ?? this.itemBg,
        itemBgExpanded: itemBgExpanded ?? this.itemBgExpanded,
        itemBorder: itemBorder ?? this.itemBorder,
        itemBorderExpanded: itemBorderExpanded ?? this.itemBorderExpanded,
        timelineRailBg: timelineRailBg ?? this.timelineRailBg,
        timelineRailBorder: timelineRailBorder ?? this.timelineRailBorder,
        eventNew: eventNew ?? this.eventNew,
        eventModified: eventModified ?? this.eventModified,
        eventDeleted: eventDeleted ?? this.eventDeleted,
        eventClean: eventClean ?? this.eventClean,
        eventPerms: eventPerms ?? this.eventPerms,
        severityHigh: severityHigh ?? this.severityHigh,
        severityMedium: severityMedium ?? this.severityMedium,
        severityLow: severityLow ?? this.severityLow,
        accent: accent ?? this.accent,
        dotsBg: dotsBg ?? this.dotsBg,
      );

  @override
  FimColors lerp(FimColors? other, double t) {
    if (other == null) return this;
    return FimColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDim: Color.lerp(primaryDim, other.primaryDim, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      headerBg: Color.lerp(headerBg, other.headerBg, t)!,
      headerBorder: Color.lerp(headerBorder, other.headerBorder, t)!,
      filterBarBg: Color.lerp(filterBarBg, other.filterBarBg, t)!,
      itemBg: Color.lerp(itemBg, other.itemBg, t)!,
      itemBgExpanded: Color.lerp(itemBgExpanded, other.itemBgExpanded, t)!,
      itemBorder: Color.lerp(itemBorder, other.itemBorder, t)!,
      itemBorderExpanded:
          Color.lerp(itemBorderExpanded, other.itemBorderExpanded, t)!,
      timelineRailBg: Color.lerp(timelineRailBg, other.timelineRailBg, t)!,
      timelineRailBorder:
          Color.lerp(timelineRailBorder, other.timelineRailBorder, t)!,
      eventNew: Color.lerp(eventNew, other.eventNew, t)!,
      eventModified: Color.lerp(eventModified, other.eventModified, t)!,
      eventDeleted: Color.lerp(eventDeleted, other.eventDeleted, t)!,
      eventClean: Color.lerp(eventClean, other.eventClean, t)!,
      eventPerms: Color.lerp(eventPerms, other.eventPerms, t)!,
      severityHigh: Color.lerp(severityHigh, other.severityHigh, t)!,
      severityMedium: Color.lerp(severityMedium, other.severityMedium, t)!,
      severityLow: Color.lerp(severityLow, other.severityLow, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      dotsBg: Color.lerp(dotsBg, other.dotsBg, t)!,
    );
  }
}

// ── Extension helper ─────────────────────────────────────────────────────────
extension FimThemeX on BuildContext {
  FimColors get fimColors => Theme.of(this).extension<FimColors>()!;
}

// ── AppColors — backward-compat (paleta oscura estática) ─────────────────────
class AppColors {
  AppColors._();
  static const Color background = Color(0xFF0D0F14);
  static const Color surface = Color(0xFF161922);
  static const Color surfaceVariant = Color(0xFF1E2230);
  static const Color border = Color(0xFF2A2F3E);
  static const Color primary = Color(0xFF00E676);
  static const Color primaryDim = Color(0xFF00C853);
  static const Color onPrimary = Color(0xFF0D0F14);
  static const Color textPrimary = Color(0xFFE8EAF0);
  static const Color textSecondary = Color(0xFF8B92A8);
  static const Color textDisabled = Color(0xFF454D63);
  static const Color eventNew = Color(0xFF29B6F6);
  static const Color eventModified = Color(0xFFFFB300);
  static const Color eventDeleted = Color(0xFFEF5350);
  static const Color eventClean = Color(0xFF00E676);
  static const Color eventPerms = Color(0xFFAB47BC);
  static const Color severityHigh = Color(0xFFEF5350);
  static const Color severityMedium = Color(0xFFFFB300);
  static const Color severityLow = Color(0xFF29B6F6);
}

// ── AppTextStyles ─────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();
  static const String monoFont = 'JetBrains Mono';
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

// ── AppTheme ──────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, fim: FimColors.dark);
  static ThemeData get light =>
      _build(brightness: Brightness.light, fim: FimColors.light);
  static ThemeData forBrightness(bool isDark) => isDark ? dark : light;

  static ThemeData _build({
    required Brightness brightness,
    required FimColors fim,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: fim.background,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: fim.primary,
              onPrimary: fim.onPrimary,
              surface: fim.surface,
              onSurface: fim.textPrimary,
              surfaceContainerHighest: fim.surfaceVariant,
              outline: fim.border,
              error: fim.eventDeleted,
            )
          : ColorScheme.light(
              primary: fim.primary,
              onPrimary: fim.onPrimary,
              surface: fim.surface,
              onSurface: fim.textPrimary,
              surfaceContainerHighest: fim.surfaceVariant,
              outline: fim.border,
              error: fim.eventDeleted,
            ),
      extensions: [fim],
      cardTheme: CardThemeData(
        color: fim.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: fim.border),
        ),
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: fim.border, thickness: 1),
      iconTheme: IconThemeData(color: fim.textSecondary, size: 16),
      textTheme: TextTheme(
        displayLarge:
            AppTextStyles.displayLarge.copyWith(color: fim.textPrimary),
        titleMedium: AppTextStyles.titleMedium.copyWith(color: fim.textPrimary),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: fim.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: fim.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTextStyles.displayLarge
            .copyWith(color: fim.textPrimary, fontSize: 16),
        iconTheme: IconThemeData(color: fim.textSecondary),
        shape: Border(bottom: BorderSide(color: fim.border)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fim.surfaceVariant,
        labelStyle: AppTextStyles.bodySmall.copyWith(color: fim.textSecondary),
        side: BorderSide(color: fim.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? fim.primary : fim.textDisabled,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? fim.primary.withOpacity(0.3)
              : fim.surfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fim.surfaceVariant,
        hintStyle: AppTextStyles.bodySmall.copyWith(color: fim.textDisabled),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: fim.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: fim.accent, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: fim.border),
        ),
      ),
    );
  }
}

// ── Helpers de color ──────────────────────────────────────────────────────────

Color eventColor(String tipo) {
  switch (tipo.toUpperCase()) {
    case 'NEW':
      return AppColors.eventNew;
    case 'MODIFIED':
      return AppColors.eventModified;
    case 'DELETED':
      return AppColors.eventDeleted;
    case 'PERMISSIONS':
      return AppColors.eventPerms;
    default:
      return AppColors.eventClean;
  }
}

Color eventColorFrom(String tipo, FimColors c) {
  switch (tipo.toUpperCase()) {
    case 'NEW':
      return c.eventNew;
    case 'MODIFIED':
      return c.eventModified;
    case 'DELETED':
      return c.eventDeleted;
    case 'PERMISSIONS':
      return c.eventPerms;
    default:
      return c.eventClean;
  }
}

Color severityColor(String severidad) {
  switch (severidad.toUpperCase()) {
    case 'ALTA':
      return AppColors.severityHigh;
    case 'MEDIA':
      return AppColors.severityMedium;
    case 'BAJA':
      return AppColors.severityLow;
    default:
      return AppColors.textDisabled;
  }
}

Color severityColorFrom(String severidad, FimColors c) {
  switch (severidad.toUpperCase()) {
    case 'ALTA':
      return c.severityHigh;
    case 'MEDIA':
      return c.severityMedium;
    case 'BAJA':
      return c.severityLow;
    default:
      return c.textDisabled;
  }
}
