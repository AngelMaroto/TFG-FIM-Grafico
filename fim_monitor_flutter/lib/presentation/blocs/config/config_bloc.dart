// lib/presentation/blocs/config/config_bloc.dart
//
// Gestiona las reglas de monitorización (Config_Rules).
// GET /api/config/rules  → carga inicial
// POST /api/config/rules → crear regla
// PUT  /api/config/rules/{id} → editar severidad
// DELETE /api/config/rules/{id} → eliminar
//
import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import '../../../data/models/config_rule_model.dart';
import '../../../core/constants/app_constants.dart';

// ── Eventos ───────────────────────────────────────────────────────────────────

abstract class ConfigEvent extends Equatable {
  const ConfigEvent();
  @override
  List<Object?> get props => [];
}

class ConfigLoadRequested extends ConfigEvent {
  const ConfigLoadRequested();
}

class ConfigRuleAdded extends ConfigEvent {
  final String ruta;
  final String nivelSeveridad;
  const ConfigRuleAdded({required this.ruta, required this.nivelSeveridad});
  @override
  List<Object?> get props => [ruta, nivelSeveridad];
}

class ConfigRuleUpdated extends ConfigEvent {
  final int id;
  final String nivelSeveridad;
  const ConfigRuleUpdated({required this.id, required this.nivelSeveridad});
  @override
  List<Object?> get props => [id, nivelSeveridad];
}

class ConfigRuleDeleted extends ConfigEvent {
  final int id;
  const ConfigRuleDeleted(this.id);
  @override
  List<Object?> get props => [id];
}

// ── Estados ───────────────────────────────────────────────────────────────────

abstract class ConfigState extends Equatable {
  const ConfigState();
  @override
  List<Object?> get props => [];
}

class ConfigInitial extends ConfigState {}

class ConfigLoading extends ConfigState {}

class ConfigLoaded extends ConfigState {
  final List<ConfigRuleModel> rules;
  final String? errorMessage; // null = sin error

  const ConfigLoaded({required this.rules, this.errorMessage});

  ConfigLoaded copyWith({
    List<ConfigRuleModel>? rules,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ConfigLoaded(
        rules: rules ?? this.rules,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [rules, errorMessage];
}

class ConfigError extends ConfigState {
  final String message;
  const ConfigError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class ConfigBloc extends Bloc<ConfigEvent, ConfigState> {
  final http.Client _httpClient;
  final String _baseUrl;

  ConfigBloc({required http.Client httpClient, required String baseUrl})
      : _httpClient = httpClient,
        _baseUrl = baseUrl,
        super(ConfigInitial()) {
    on<ConfigLoadRequested>(_onLoad);
    on<ConfigRuleAdded>(_onAdd);
    on<ConfigRuleUpdated>(_onUpdate);
    on<ConfigRuleDeleted>(_onDelete);
  }

  String get _endpoint => '$_baseUrl${AppConstants.configEndpoint}';

  // ── Carga inicial ─────────────────────────────────────────────────────────

  Future<void> _onLoad(
      ConfigLoadRequested event, Emitter<ConfigState> emit) async {
    emit(ConfigLoading());
    try {
      final response = await _httpClient.get(Uri.parse(_endpoint), headers: {
        'Accept': 'application/json'
      }).timeout(AppConstants.httpTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body) as List;
        final rules = body
            .map((e) => ConfigRuleModel.fromJson(e as Map<String, dynamic>))
            .toList();
        emit(ConfigLoaded(rules: rules));
      } else {
        emit(ConfigError('Error ${response.statusCode} al cargar reglas'));
      }
    } catch (e) {
      emit(ConfigError('No se pudo conectar con el backend'));
    }
  }

  // ── Crear regla ───────────────────────────────────────────────────────────

  Future<void> _onAdd(ConfigRuleAdded event, Emitter<ConfigState> emit) async {
    final current = state;
    if (current is! ConfigLoaded) return;

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'ruta': event.ruta,
              'nivelSeveridad': event.nivelSeveridad,
            }),
          )
          .timeout(AppConstants.httpTimeout);

      if (response.statusCode == 201) {
        final newRule = ConfigRuleModel.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        emit(current.copyWith(
          rules: [...current.rules, newRule],
          clearError: true,
        ));
      } else if (response.statusCode == 409) {
        // Duplicado
        emit(current.copyWith(
            errorMessage: 'Ya existe una regla para "${event.ruta}"'));
      } else {
        emit(current.copyWith(
            errorMessage: 'Error ${response.statusCode} al crear regla'));
      }
    } catch (e) {
      emit(current.copyWith(errorMessage: 'Sin conexión con el backend'));
    }
  }

  // ── Actualizar severidad ──────────────────────────────────────────────────

  Future<void> _onUpdate(
      ConfigRuleUpdated event, Emitter<ConfigState> emit) async {
    final current = state;
    if (current is! ConfigLoaded) return;

    try {
      final response = await _httpClient
          .put(
            Uri.parse('$_endpoint/${event.id}'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'nivelSeveridad': event.nivelSeveridad}),
          )
          .timeout(AppConstants.httpTimeout);

      if (response.statusCode == 200) {
        final updated = ConfigRuleModel.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        final newRules =
            current.rules.map((r) => r.id == event.id ? updated : r).toList();
        emit(current.copyWith(rules: newRules, clearError: true));
      } else {
        emit(current.copyWith(
            errorMessage: 'Error ${response.statusCode} al actualizar'));
      }
    } catch (e) {
      emit(current.copyWith(errorMessage: 'Sin conexión con el backend'));
    }
  }

  // ── Eliminar regla ────────────────────────────────────────────────────────

  Future<void> _onDelete(
      ConfigRuleDeleted event, Emitter<ConfigState> emit) async {
    final current = state;
    if (current is! ConfigLoaded) return;

    try {
      final response = await _httpClient
          .delete(Uri.parse('$_endpoint/${event.id}'))
          .timeout(AppConstants.httpTimeout);

      if (response.statusCode == 204) {
        final newRules = current.rules.where((r) => r.id != event.id).toList();
        emit(current.copyWith(rules: newRules, clearError: true));
      } else {
        emit(current.copyWith(
            errorMessage: 'Error ${response.statusCode} al eliminar'));
      }
    } catch (e) {
      emit(current.copyWith(errorMessage: 'Sin conexión con el backend'));
    }
  }
}
