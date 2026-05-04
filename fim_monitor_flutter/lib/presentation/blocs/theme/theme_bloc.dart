// lib/presentation/blocs/theme/theme_bloc.dart
//
// Gestiona el tema (oscuro/claro) de la aplicación.
// Persiste la preferencia en SharedPreferences.
// Usado en main.dart con BlocProvider global.
//
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'app_theme_dark';

// ── Eventos ───────────────────────────────────────────────────────────────────

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();
  @override
  List<Object?> get props => [];
}

class ThemeLoaded extends ThemeEvent {
  const ThemeLoaded();
}

class ThemeToggled extends ThemeEvent {
  const ThemeToggled();
}

class ThemeSet extends ThemeEvent {
  final bool isDark;
  const ThemeSet(this.isDark);
  @override
  List<Object?> get props => [isDark];
}

// ── Estado ────────────────────────────────────────────────────────────────────

class ThemeState extends Equatable {
  final bool isDark;
  const ThemeState({required this.isDark});

  @override
  List<Object?> get props => [isDark];
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeState(isDark: true)) {
    on<ThemeLoaded>(_onLoaded);
    on<ThemeToggled>(_onToggled);
    on<ThemeSet>(_onSet);
  }

  Future<void> _onLoaded(ThemeLoaded event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    // Por defecto oscuro (la app siempre fue oscura)
    final isDark = prefs.getBool(_kThemeKey) ?? true;
    emit(ThemeState(isDark: isDark));
  }

  Future<void> _onToggled(ThemeToggled event, Emitter<ThemeState> emit) async {
    final isDark = !state.isDark;
    emit(ThemeState(isDark: isDark));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kThemeKey, isDark);
  }

  Future<void> _onSet(ThemeSet event, Emitter<ThemeState> emit) async {
    emit(ThemeState(isDark: event.isDark));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kThemeKey, event.isDark);
  }
}
