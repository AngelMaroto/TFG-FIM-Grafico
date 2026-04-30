// lib/presentation/blocs/graph/graph_bloc.dart
//
// FIX: todos los filtros (tipo, severidad, búsqueda, ruta) son LOCALES.
// Ningún filtro dispara HTTP ni GraphLoading. Solo GraphLoadRequested
// hace HTTP (arranque y reconexión). El widget filtra sobre nodeMap completo.
//
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/alert_model.dart';
import '../../../domain/repositories/fim_repository.dart';

// ── Eventos ───────────────────────────────────────────────────────────────────

abstract class GraphEvent extends Equatable {
  const GraphEvent();
  @override
  List<Object?> get props => [];
}

class GraphLoadRequested extends GraphEvent {
  const GraphLoadRequested();
}

class GraphFilterChanged extends GraphEvent {
  final String? tipo;
  final String? ruta;
  final String? severidad;
  final String? searchQuery;
  const GraphFilterChanged(
      {this.tipo, this.ruta, this.severidad, this.searchQuery});
  @override
  List<Object?> get props => [tipo, ruta, severidad, searchQuery];
}

class _GraphLiveAlertReceived extends GraphEvent {
  final AlertModel alert;
  const _GraphLiveAlertReceived(this.alert);
  @override
  List<Object?> get props => [alert];
}

class GraphNodeSelected extends GraphEvent {
  final String ruta;
  const GraphNodeSelected(this.ruta);
  @override
  List<Object?> get props => [ruta];
}

class GraphSnapshotApplied extends GraphEvent {
  final Map<String, String?>? snapshotStates;
  const GraphSnapshotApplied(this.snapshotStates);
  @override
  List<Object?> get props => [snapshotStates];
}

// ── Estados ───────────────────────────────────────────────────────────────────

abstract class GraphState extends Equatable {
  const GraphState();
  @override
  List<Object?> get props => [];
}

class GraphInitial extends GraphState {}

class GraphLoading extends GraphState {}

class GraphLoaded extends GraphState {
  // nodeMap COMPLETO — el widget aplica filtros localmente sobre este mapa
  final Map<String, AlertModel> nodeMap;
  final String? selectedRuta;
  final String? filterTipo;
  final String? filterRuta;
  final String? filterSeveridad;
  final String? searchQuery;
  final Map<String, String?>? snapshotOverride;

  const GraphLoaded({
    required this.nodeMap,
    this.selectedRuta,
    this.filterTipo,
    this.filterRuta,
    this.filterSeveridad,
    this.searchQuery,
    this.snapshotOverride,
  });

  GraphLoaded copyWith({
    Map<String, AlertModel>? nodeMap,
    String? selectedRuta,
    Object? filterTipo = _s,
    Object? filterRuta = _s,
    Object? filterSeveridad = _s,
    Object? searchQuery = _s,
    Object? snapshotOverride = _s,
    bool clearSelection = false,
  }) =>
      GraphLoaded(
        nodeMap: nodeMap ?? this.nodeMap,
        selectedRuta:
            clearSelection ? null : (selectedRuta ?? this.selectedRuta),
        filterTipo: filterTipo == _s ? this.filterTipo : filterTipo as String?,
        filterRuta: filterRuta == _s ? this.filterRuta : filterRuta as String?,
        filterSeveridad: filterSeveridad == _s
            ? this.filterSeveridad
            : filterSeveridad as String?,
        searchQuery:
            searchQuery == _s ? this.searchQuery : searchQuery as String?,
        snapshotOverride: snapshotOverride == _s
            ? this.snapshotOverride
            : snapshotOverride as Map<String, String?>?,
      );

  static const _s = Object();

  @override
  List<Object?> get props => [
        nodeMap,
        selectedRuta,
        filterTipo,
        filterRuta,
        filterSeveridad,
        searchQuery,
        snapshotOverride,
      ];
}

class GraphError extends GraphState {
  final String message;
  const GraphError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class GraphBloc extends Bloc<GraphEvent, GraphState> {
  final FimRepository _repo;
  StreamSubscription<AlertModel>? _liveAlertSub;

  GraphBloc(this._repo) : super(GraphInitial()) {
    on<GraphLoadRequested>(_onLoad);
    on<GraphFilterChanged>(_onFilterChanged);
    on<_GraphLiveAlertReceived>(_onLiveAlert);
    on<GraphNodeSelected>(_onNodeSelected);
    on<GraphSnapshotApplied>(_onSnapshotApplied);
  }

  Future<void> _onLoad(
      GraphLoadRequested event, Emitter<GraphState> emit) async {
    await _liveAlertSub?.cancel();
    _liveAlertSub = null;
    emit(GraphLoading());
    try {
      // Carga TODO sin filtros — filtrado local en el widget
      final alerts = await _repo.fetchAlerts(limit: 500);

      final nodeMap = <String, AlertModel>{};
      for (final a in alerts) {
        if (a.rutaArchivo == null) continue;
        final existing = nodeMap[a.rutaArchivo!];
        if (existing == null ||
            (a.fechaEjecucion ?? '').compareTo(existing.fechaEjecucion ?? '') >
                0) {
          nodeMap[a.rutaArchivo!] = a;
        }
      }

      emit(GraphLoaded(nodeMap: nodeMap));

      _liveAlertSub = _repo.liveAlerts.listen(
        (alert) => add(_GraphLiveAlertReceived(alert)),
      );
    } catch (e) {
      emit(GraphError(e.toString()));
    }
  }

  // Filtros → solo emit, CERO HTTP
  void _onFilterChanged(GraphFilterChanged event, Emitter<GraphState> emit) {
    final current = state;
    if (current is! GraphLoaded) return;
    emit(current.copyWith(
      filterTipo: event.tipo,
      filterRuta: event.ruta,
      filterSeveridad: event.severidad,
      searchQuery: event.searchQuery,
    ));
  }

  void _onLiveAlert(_GraphLiveAlertReceived event, Emitter<GraphState> emit) {
    final current = state;
    if (current is! GraphLoaded) return;
    if (event.alert.rutaArchivo == null) return;
    final updated = Map<String, AlertModel>.from(current.nodeMap);
    updated[event.alert.rutaArchivo!] = event.alert;
    emit(current.copyWith(nodeMap: updated, snapshotOverride: null));
  }

  void _onNodeSelected(GraphNodeSelected event, Emitter<GraphState> emit) {
    final current = state;
    if (current is! GraphLoaded) return;
    emit(current.copyWith(selectedRuta: event.ruta));
  }

  void _onSnapshotApplied(
      GraphSnapshotApplied event, Emitter<GraphState> emit) {
    final current = state;
    if (current is! GraphLoaded) return;
    emit(current.copyWith(snapshotOverride: event.snapshotStates));
  }

  @override
  Future<void> close() {
    _liveAlertSub?.cancel();
    return super.close();
  }
}
