// lib/presentation/blocs/timeline/timeline_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/alert_model.dart';
import '../../../domain/repositories/fim_repository.dart';
import '../../../core/constants/app_constants.dart';

// ── Modelo de snapshot para el grafo temporal ─────────────────────────────────
// Representa el estado del sistema de archivos en un instante concreto,
// reconstruido aplicando todos los eventos hasta esa fecha.
class GraphSnapshot {
  final DateTime timestamp;
  final String label; // ej. "Scan #3 · 24/04 14:32"
  // Mapa rutaArchivo → tipoCambio del último evento que afecta a ese fichero
  // hasta este instante. null = fichero limpio/sin cambios.
  final Map<String, String?> nodeStates;

  const GraphSnapshot({
    required this.timestamp,
    required this.label,
    required this.nodeStates,
  });
}

// ── Eventos ──────────────────────────────────────────────────────────────────
abstract class TimelineEvent extends Equatable {
  const TimelineEvent();
  @override
  List<Object?> get props => [];
}

class TimelineLoadRequested extends TimelineEvent {
  final String? tipo;
  final String? ruta;
  final String? desde;
  final String? hasta;
  const TimelineLoadRequested({this.tipo, this.ruta, this.desde, this.hasta});
  @override
  List<Object?> get props => [tipo, ruta, desde, hasta];
}

class TimelineLoadMore extends TimelineEvent {}

/// El usuario arrastró el slider temporal al índice [snapshotIndex].
class TimelineSnapshotChanged extends TimelineEvent {
  final int snapshotIndex;
  const TimelineSnapshotChanged(this.snapshotIndex);
  @override
  List<Object?> get props => [snapshotIndex];
}

class _TimelineLiveAlert extends TimelineEvent {
  final AlertModel alert;
  const _TimelineLiveAlert(this.alert);
  @override
  List<Object?> get props => [alert];
}

// ── Estados ──────────────────────────────────────────────────────────────────
abstract class TimelineState extends Equatable {
  const TimelineState();
  @override
  List<Object?> get props => [];
}

class TimelineInitial extends TimelineState {}

class TimelineLoading extends TimelineState {}

class TimelineLoaded extends TimelineState {
  final List<AlertModel> alerts;
  final bool hasMore;
  final int offset;

  /// Snapshots ordenados cronológicamente para el slider temporal.
  /// Calculados una sola vez al cargar; el último es el estado "en vivo".
  final List<GraphSnapshot> snapshots;

  /// Índice activo en [snapshots]. -1 = en vivo (último).
  final int activeSnapshotIndex;

  const TimelineLoaded({
    required this.alerts,
    required this.hasMore,
    required this.offset,
    required this.snapshots,
    required this.activeSnapshotIndex,
  });

  TimelineLoaded copyWith({
    List<AlertModel>? alerts,
    bool? hasMore,
    int? offset,
    List<GraphSnapshot>? snapshots,
    int? activeSnapshotIndex,
  }) =>
      TimelineLoaded(
        alerts: alerts ?? this.alerts,
        hasMore: hasMore ?? this.hasMore,
        offset: offset ?? this.offset,
        snapshots: snapshots ?? this.snapshots,
        activeSnapshotIndex: activeSnapshotIndex ?? this.activeSnapshotIndex,
      );

  /// El snapshot actualmente seleccionado (puede ser el live).
  GraphSnapshot? get activeSnapshot => snapshots.isEmpty
      ? null
      : snapshots[activeSnapshotIndex.clamp(0, snapshots.length - 1)];

  /// true cuando el slider está en el último snapshot (estado actual).
  bool get isLive => activeSnapshotIndex == snapshots.length - 1;

  @override
  List<Object?> get props =>
      [alerts, hasMore, offset, snapshots, activeSnapshotIndex];
}

class TimelineError extends TimelineState {
  final String message;
  const TimelineError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────
class TimelineBloc extends Bloc<TimelineEvent, TimelineState> {
  final FimRepository _repo;
  StreamSubscription<AlertModel>? _sub;

  String? _tipo, _ruta, _desde, _hasta;

  TimelineBloc(this._repo) : super(TimelineInitial()) {
    on<TimelineLoadRequested>(_onLoad);
    on<TimelineLoadMore>(_onLoadMore);
    on<TimelineSnapshotChanged>(_onSnapshotChanged);
    on<_TimelineLiveAlert>(_onLiveAlert);
  }

  Future<void> _onLoad(
      TimelineLoadRequested event, Emitter<TimelineState> emit) async {
    emit(TimelineLoading());
    _tipo = event.tipo;
    _ruta = event.ruta;
    _desde = event.desde;
    _hasta = event.hasta;

    try {
      final alerts = await _repo.fetchAlerts(
        tipo: _tipo,
        ruta: _ruta,
        desde: _desde,
        hasta: _hasta,
        limit: AppConstants.defaultPageSize,
        offset: 0,
      );

      // Construir snapshots una sola vez — O(n) sobre la lista de alertas
      final snapshots = _buildSnapshots(alerts);

      emit(TimelineLoaded(
        alerts: alerts,
        hasMore: alerts.length >= AppConstants.defaultPageSize,
        offset: alerts.length,
        snapshots: snapshots,
        activeSnapshotIndex: snapshots.isEmpty ? 0 : snapshots.length - 1,
      ));

      await _sub?.cancel();
      _sub = _repo.liveAlerts.listen((a) => add(_TimelineLiveAlert(a)));
    } catch (e) {
      emit(TimelineError(e.toString()));
    }
  }

  Future<void> _onLoadMore(
      TimelineLoadMore event, Emitter<TimelineState> emit) async {
    final current = state;
    if (current is! TimelineLoaded || !current.hasMore) return;

    try {
      final more = await _repo.fetchAlerts(
        tipo: _tipo,
        ruta: _ruta,
        desde: _desde,
        hasta: _hasta,
        limit: AppConstants.defaultPageSize,
        offset: current.offset,
      );
      final allAlerts = [...current.alerts, ...more];
      emit(current.copyWith(
        alerts: allAlerts,
        hasMore: more.length >= AppConstants.defaultPageSize,
        offset: current.offset + more.length,
        // Reconstruir snapshots con los datos nuevos
        snapshots: _buildSnapshots(allAlerts),
      ));
    } catch (_) {/* mantener estado actual */}
  }

  void _onSnapshotChanged(
      TimelineSnapshotChanged event, Emitter<TimelineState> emit) {
    final current = state;
    if (current is! TimelineLoaded) return;
    // Solo cambia el índice — NO recalcula nada costoso
    emit(current.copyWith(activeSnapshotIndex: event.snapshotIndex));
  }

  void _onLiveAlert(_TimelineLiveAlert event, Emitter<TimelineState> emit) {
    final current = state;
    if (current is! TimelineLoaded) return;
    final allAlerts = [event.alert, ...current.alerts];
    emit(current.copyWith(
      alerts: allAlerts,
      snapshots: _buildSnapshots(allAlerts),
      // Mantener el índice activo — si el usuario está en live, sigue en live
      activeSnapshotIndex: current.isLive
          ? _buildSnapshots(allAlerts).length - 1
          : current.activeSnapshotIndex,
    ));
  }

  /// Construye la lista de GraphSnapshot agrupando alertas por fecha de escaneo.
  ///
  /// Lógica: ordena las alertas cronológicamente, agrupa por día+hora (o por
  /// scanId si está disponible), y para cada grupo acumula el estado de todos
  /// los ficheros vistos hasta ese punto.
  ///
  /// El resultado es una lista ordenada donde snapshots[i].nodeStates contiene
  /// el estado de TODOS los ficheros conocidos hasta el i-ésimo escaneo.
  static List<GraphSnapshot> _buildSnapshots(List<AlertModel> alerts) {
    if (alerts.isEmpty) return [];

    // 1. Ordenar cronológicamente (las alertas llegan más reciente primero)
    final sorted = [...alerts];
    sorted.sort((a, b) {
      final da = _parseDate(a.fechaEjecucion);
      final db = _parseDate(b.fechaEjecucion);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    // 2. Agrupar por scan (scanId o por bucket de 1 minuto si no hay scanId)
    final grupos = <String, List<AlertModel>>{};
    for (final a in sorted) {
      final key =
          a.scanId != null ? 'scan_${a.scanId}' : _bucketKey(a.fechaEjecucion);
      grupos.putIfAbsent(key, () => []).add(a);
    }

    // 3. Construir snapshots acumulativos
    final snapshots = <GraphSnapshot>[];
    final estadoAcumulado = <String, String?>{};

    for (final entry in grupos.entries) {
      final items = entry.value;
      final timestamp =
          _parseDate(items.first.fechaEjecucion) ?? DateTime.now();

      // Aplicar los cambios de este grupo al estado acumulado
      for (final a in items) {
        if (a.rutaArchivo != null) {
          // DELETED pone el nodo en rojo pero lo mantenemos en el mapa
          // para que el grafo muestre que existía y fue eliminado
          estadoAcumulado[a.rutaArchivo!] = a.tipoCambio;
        }
      }

      // Calcular label
      final scanNum = snapshots.length + 1;
      final fechaStr = _formatSnapshotDate(timestamp);
      final label = 'Scan #$scanNum · $fechaStr';

      snapshots.add(GraphSnapshot(
        timestamp: timestamp,
        label: label,
        // Snapshot INMUTABLE: copia del estado hasta este instante
        nodeStates:
            Map.unmodifiable(Map<String, String?>.from(estadoAcumulado)),
      ));
    }

    return snapshots;
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Agrupa alertas sin scanId en buckets de 1 minuto
  static String _bucketKey(String? raw) {
    final dt = _parseDate(raw);
    if (dt == null) return 'unknown';
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        '_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _formatSnapshotDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
