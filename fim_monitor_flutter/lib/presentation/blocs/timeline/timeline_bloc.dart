// lib/presentation/blocs/timeline/timeline_bloc.dart
//
// FIX DE RENDIMIENTO v2:
//   • _buildSnapshots se ejecuta en un Isolate separado (compute()) para no
//     bloquear el UI thread. Con muchas alertas o eventos WebSocket rápidos,
//     la versión anterior congelaba la interfaz 100-400ms por cada llamada.
//   • _onLiveAlert usa un throttle de 500ms: si llegan múltiples alertas
//     WebSocket seguidas (ráfaga), solo recalcula snapshots una vez.
//     Evita el crash al recibir muchos eventos WebSocket en poco tiempo.
//   • _sub se cancela con await antes de reasignar en _onLoad.
//
import 'dart:async';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/alert_model.dart';
import '../../../domain/repositories/fim_repository.dart';
import '../../../core/constants/app_constants.dart';

// ── Modelo de snapshot ────────────────────────────────────────────────────────

class GraphSnapshot {
  final DateTime timestamp;
  final String label;
  final Map<String, String?> nodeStates;

  const GraphSnapshot({
    required this.timestamp,
    required this.label,
    required this.nodeStates,
  });
}

// ── Función top-level para compute() ─────────────────────────────────────────
//
// IMPORTANTE: compute() requiere una función top-level (no un método estático
// dentro de una clase), porque se ejecuta en un Isolate separado y no puede
// capturar referencias al heap del Isolate principal.

List<GraphSnapshot> _buildSnapshotsIsolate(List<AlertModel> alerts) {
  if (alerts.isEmpty) return [];

  final sorted = [...alerts];
  sorted.sort((a, b) {
    final da = _parseDate(a.fechaEjecucion);
    final db = _parseDate(b.fechaEjecucion);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });

  final grupos = <String, List<AlertModel>>{};
  for (final a in sorted) {
    final key =
        a.scanId != null ? 'scan_${a.scanId}' : _bucketKey(a.fechaEjecucion);
    grupos.putIfAbsent(key, () => []).add(a);
  }

  final snapshots = <GraphSnapshot>[];
  final estadoAcumulado = <String, String?>{};

  for (final entry in grupos.entries) {
    final items = entry.value;
    final timestamp = _parseDate(items.first.fechaEjecucion) ?? DateTime.now();

    for (final a in items) {
      if (a.rutaArchivo != null) {
        estadoAcumulado[a.rutaArchivo!] = a.tipoCambio;
      }
    }

    final scanNum = snapshots.length + 1;
    final fechaStr = _formatSnapshotDate(timestamp);
    final label = 'Scan #$scanNum · $fechaStr';

    snapshots.add(GraphSnapshot(
      timestamp: timestamp,
      label: label,
      nodeStates: Map.unmodifiable(Map<String, String?>.from(estadoAcumulado)),
    ));
  }

  return snapshots;
}

DateTime? _parseDate(String? raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

String _bucketKey(String? raw) {
  final dt = _parseDate(raw);
  if (dt == null) return 'unknown';
  return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
      '_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
}

String _formatSnapshotDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Eventos ───────────────────────────────────────────────────────────────────

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

class TimelineSnapshotChanged extends TimelineEvent {
  final int snapshotIndex;
  const TimelineSnapshotChanged(this.snapshotIndex);
  @override
  List<Object?> get props => [snapshotIndex];
}

// Evento interno — las alertas live se acumulan en _pendingLiveAlerts
// y se procesan en batch cada 500ms (throttle).
class _TimelineLiveAlert extends TimelineEvent {
  final AlertModel alert;
  const _TimelineLiveAlert(this.alert);
  @override
  List<Object?> get props => [alert.id];
}

// Evento interno disparado por el timer de throttle
class _TimelineFlushLiveAlerts extends TimelineEvent {
  const _TimelineFlushLiveAlerts();
}

// ── Estados ───────────────────────────────────────────────────────────────────

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
  final List<GraphSnapshot> snapshots;
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

  GraphSnapshot? get activeSnapshot => snapshots.isEmpty
      ? null
      : snapshots[activeSnapshotIndex.clamp(0, snapshots.length - 1)];

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

// ── BLoC ──────────────────────────────────────────────────────────────────────

class TimelineBloc extends Bloc<TimelineEvent, TimelineState> {
  final FimRepository _repo;
  StreamSubscription<AlertModel>? _sub;

  String? _tipo, _ruta, _desde, _hasta;

  // FIX: throttle de alertas live — acumuladas aquí, procesadas en batch.
  final List<AlertModel> _pendingLiveAlerts = [];
  Timer? _liveThrottle;

  TimelineBloc(this._repo) : super(TimelineInitial()) {
    on<TimelineLoadRequested>(_onLoad);
    on<TimelineLoadMore>(_onLoadMore);
    on<TimelineSnapshotChanged>(_onSnapshotChanged);
    on<_TimelineLiveAlert>(_onLiveAlertReceived);
    on<_TimelineFlushLiveAlerts>(_onFlushLiveAlerts);
  }

  Future<void> _onLoad(
      TimelineLoadRequested event, Emitter<TimelineState> emit) async {
    // FIX: cancelar suscripción y throttle antes de reasignar
    _liveThrottle?.cancel();
    _pendingLiveAlerts.clear();
    await _sub?.cancel();
    _sub = null;

    emit(TimelineLoading());
    _tipo = event.tipo;
    _ruta = event.ruta;
    _desde = event.desde;
    _hasta = event.hasta;

    try {
      // Cargar hasta 500 eventos de una vez — scroll infinito desactivado.
      // Con la paginación del backend esto es eficiente y evita el problema
      // de eventos aparentemente duplicados al hacer scroll.
      final alerts = await _repo.fetchAlerts(
        tipo: _tipo,
        ruta: _ruta,
        desde: _desde,
        hasta: _hasta,
        limit: 500,
        offset: 0,
      );

      // FIX: compute() ejecuta _buildSnapshotsIsolate en un Isolate separado.
      // No bloquea el UI thread aunque haya 1000+ alertas.
      final snapshots = await compute(_buildSnapshotsIsolate, alerts);

      emit(TimelineLoaded(
        alerts: alerts,
        hasMore: false, // scroll infinito desactivado
        offset: alerts.length,
        snapshots: snapshots,
        activeSnapshotIndex: snapshots.isEmpty ? 0 : snapshots.length - 1,
      ));

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

      // FIX: también en compute para no bloquear al paginar
      final snapshots = await compute(_buildSnapshotsIsolate, allAlerts);

      emit(current.copyWith(
        alerts: allAlerts,
        hasMore: more.length >= AppConstants.defaultPageSize,
        offset: current.offset + more.length,
        snapshots: snapshots,
      ));
    } catch (_) {/* mantener estado actual */}
  }

  void _onSnapshotChanged(
      TimelineSnapshotChanged event, Emitter<TimelineState> emit) {
    final current = state;
    if (current is! TimelineLoaded) return;
    emit(current.copyWith(activeSnapshotIndex: event.snapshotIndex));
  }

  // FIX: no procesar inmediatamente — acumular en buffer y activar timer.
  void _onLiveAlertReceived(
      _TimelineLiveAlert event, Emitter<TimelineState> emit) {
    _pendingLiveAlerts.add(event.alert);

    // Si ya hay un timer corriendo, dejar que expire (throttle).
    if (_liveThrottle?.isActive ?? false) return;

    // Timer de 500ms: agrupa ráfagas de alertas WebSocket en un solo recálculo.
    _liveThrottle = Timer(const Duration(milliseconds: 500), () {
      add(const _TimelineFlushLiveAlerts());
    });
  }

  // FIX: procesa el batch de alertas acumuladas en compute()
  Future<void> _onFlushLiveAlerts(
      _TimelineFlushLiveAlerts event, Emitter<TimelineState> emit) async {
    final current = state;
    if (current is! TimelineLoaded || _pendingLiveAlerts.isEmpty) return;

    final batch = List<AlertModel>.from(_pendingLiveAlerts);
    _pendingLiveAlerts.clear();

    final allAlerts = [...batch, ...current.alerts];

    // compute() — no bloquea UI aunque lleguen muchas alertas de golpe
    final snapshots = await compute(_buildSnapshotsIsolate, allAlerts);

    emit(current.copyWith(
      alerts: allAlerts,
      snapshots: snapshots,
      activeSnapshotIndex:
          current.isLive ? snapshots.length - 1 : current.activeSnapshotIndex,
    ));
  }

  @override
  Future<void> close() {
    _liveThrottle?.cancel();
    _sub?.cancel();
    return super.close();
  }
}
