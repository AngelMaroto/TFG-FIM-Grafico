// lib/presentation/blocs/graph/graph_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/alert_model.dart';
import '../../../domain/repositories/fim_repository.dart';

// ── Eventos ──────────────────────────────────────────────────────────────────
abstract class GraphEvent extends Equatable {
  const GraphEvent();
  @override
  List<Object?> get props => [];
}

class GraphLoadRequested extends GraphEvent {
  final String? filterTipo;
  final String? filterRuta;
  const GraphLoadRequested({this.filterTipo, this.filterRuta});
  @override
  List<Object?> get props => [filterTipo, filterRuta];
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

// ── Estados ──────────────────────────────────────────────────────────────────
abstract class GraphState extends Equatable {
  const GraphState();
  @override
  List<Object?> get props => [];
}

class GraphInitial extends GraphState {}

class GraphLoading extends GraphState {}

class GraphLoaded extends GraphState {
  final Map<String, AlertModel> nodeMap;
  final String? selectedRuta;
  final String? filterTipo;
  final String? filterRuta;
  final String? filterSeveridad;
  final String? searchQuery;

  const GraphLoaded({
    required this.nodeMap,
    this.selectedRuta,
    this.filterTipo,
    this.filterRuta,
    this.filterSeveridad,
    this.searchQuery,
  });

  GraphLoaded copyWith({
    Map<String, AlertModel>? nodeMap,
    String? selectedRuta,
    Object? filterTipo = _sentinel,
    Object? filterRuta = _sentinel,
    Object? filterSeveridad = _sentinel,
    Object? searchQuery = _sentinel,
    bool clearSelection = false,
  }) =>
      GraphLoaded(
        nodeMap: nodeMap ?? this.nodeMap,
        selectedRuta:
            clearSelection ? null : (selectedRuta ?? this.selectedRuta),
        filterTipo:
            filterTipo == _sentinel ? this.filterTipo : filterTipo as String?,
        filterRuta:
            filterRuta == _sentinel ? this.filterRuta : filterRuta as String?,
        filterSeveridad: filterSeveridad == _sentinel
            ? this.filterSeveridad
            : filterSeveridad as String?,
        searchQuery: searchQuery == _sentinel
            ? this.searchQuery
            : searchQuery as String?,
      );

  static const _sentinel = Object();

  @override
  List<Object?> get props => [
        nodeMap,
        selectedRuta,
        filterTipo,
        filterRuta,
        filterSeveridad,
        searchQuery
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
  }

  Future<void> _onLoad(
      GraphLoadRequested event, Emitter<GraphState> emit) async {
    // Cancelar suscripción previa antes de emitir loading
    await _liveAlertSub?.cancel();
    _liveAlertSub = null;
    emit(GraphLoading());
    try {
      final alerts = await _repo.fetchAlerts(
        tipo: event.filterTipo,
        ruta: event.filterRuta,
        limit: 500,
      );

      // Construir el mapa: para cada ruta conservar la alerta más reciente
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

      emit(GraphLoaded(
        nodeMap: nodeMap,
        filterTipo: event.filterTipo,
        filterRuta: event.filterRuta,
      ));

      // Suscribirse a alertas en tiempo real
      await _liveAlertSub?.cancel();
      _liveAlertSub = _repo.liveAlerts.listen(
        (alert) => add(_GraphLiveAlertReceived(alert)),
      );
    } catch (e) {
      emit(GraphError(e.toString()));
    }
  }

  void _onFilterChanged(GraphFilterChanged event, Emitter<GraphState> emit) {
    final current = state;
    if (current is GraphLoaded) {
      // Severidad y búsqueda: solo actualizar estado, sin HTTP
      if (event.tipo == current.filterTipo &&
          event.ruta == current.filterRuta) {
        emit(current.copyWith(
          filterSeveridad: event.severidad,
          searchQuery: event.searchQuery,
        ));
        return;
      }
    }
    // Cambio de tipo/ruta: sí relanzar HTTP
    add(GraphLoadRequested(
      filterTipo: event.tipo,
      filterRuta: event.ruta,
    ));
  }

  void _onLiveAlert(_GraphLiveAlertReceived event, Emitter<GraphState> emit) {
    final current = state;
    if (current is! GraphLoaded) return;
    if (event.alert.rutaArchivo == null) return;

    final updated = Map<String, AlertModel>.from(current.nodeMap);
    updated[event.alert.rutaArchivo!] = event.alert;
    emit(current.copyWith(nodeMap: updated));
  }

  void _onNodeSelected(GraphNodeSelected event, Emitter<GraphState> emit) {
    final current = state;
    if (current is! GraphLoaded) return;
    emit(current.copyWith(selectedRuta: event.ruta));
  }

  @override
  Future<void> close() {
    _liveAlertSub?.cancel();
    return super.close();
  }
}
