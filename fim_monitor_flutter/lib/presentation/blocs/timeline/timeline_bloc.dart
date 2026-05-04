// lib/presentation/blocs/timeline/timeline_bloc.dart
//
// FIX DE MEMORIA v3:
//   • _onAppPaused: cancela _liveThrottle y limpia _pendingLiveAlerts.
//     Evita que compute() siga lanzando Isolates en background.
//   • _onAppResumed: reestablece la suscripción a liveAlerts si
//     el estado era TimelineLoaded (sin recargar HTTP).
//   • WidgetsBindingObserver integrado — misma estrategia que ConnectionBloc.
//   • _buildSnapshotsIsolate y helpers top-level sin cambios.
//
import 'dart:async';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/widgets.dart';
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

List<GraphSnapshot> _buildSnapshotsIsolate(List<AlertModel> alerts) {
  if (alerts.isEmpty) return [];

  final sorted = [...alerts]..sort((a, b) {
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
  final acumulado = <String, String?>{};

  for (final entry in grupos.entries) {
    final items = entry.value;
    final timestamp = _parseDate(items.first.fechaEjecucion) ?? DateTime.now();

    for (final a in items) {
      if (a.rutaArchivo != null) acumulado[a.rutaArchivo!] = a.tipoCambio;
    }

    snapshots.add(GraphSnapshot(
      timestamp: timestamp,
      label:
          'Scan #${snapshots.length + 1} · ${_formatSnapshotDate(timestamp)}',
      nodeStates: Map.unmodifiable(Map<String, String?>.from(acumulado)),
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

String _formatSnapshotDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

// ── Eventos ───────────────────────────────────────────────────────────────────

abstract class TimelineEvent extends Equatable {
  const TimelineEvent();
  @override
  List<Object?> get props => [];
}

class TimelineLoadRequested extends TimelineEvent {
  final String? tipo, ruta, desde, hasta;
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

class _TimelineLiveAlert extends TimelineEvent {
  final AlertModel alert;
  const _TimelineLiveAlert(this.alert);
  @override
  List<Object?> get props => [alert.id];
}

class _TimelineFlushLiveAlerts extends TimelineEvent {
  const _TimelineFlushLiveAlerts();
}

class _TimelineAppPaused extends TimelineEvent {
  const _TimelineAppPaused();
}

class _TimelineAppResumed extends TimelineEvent {
  const _TimelineAppResumed();
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

class TimelineBloc extends Bloc<TimelineEvent, TimelineState>
    with WidgetsBindingObserver {
  final FimRepository _repo;
  StreamSubscription<AlertModel>? _sub;

  String? _tipo, _ruta, _desde, _hasta;

  final List<AlertModel> _pendingLiveAlerts = [];
  Timer? _liveThrottle;

  TimelineBloc(this._repo) : super(TimelineInitial()) {
    on<TimelineLoadRequested>(_onLoad);
    on<TimelineLoadMore>(_onLoadMore);
    on<TimelineSnapshotChanged>(_onSnapshotChanged);
    on<_TimelineLiveAlert>(_onLiveAlertReceived);
    on<_TimelineFlushLiveAlerts>(_onFlushLiveAlerts);
    on<_TimelineAppPaused>(_onAppPaused);
    on<_TimelineAppResumed>(_onAppResumed);

    WidgetsBinding.instance.addObserver(this);
  }

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        add(const _TimelineAppPaused());
        break;
      case AppLifecycleState.resumed:
        add(const _TimelineAppResumed());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onAppPaused(_TimelineAppPaused event, Emitter<TimelineState> emit) {
    // Cancelar throttle y vaciar el buffer de alertas pendientes.
    // Esto evita que compute() se siga llamando desde Isolates en background.
    _liveThrottle?.cancel();
    _liveThrottle = null;
    _pendingLiveAlerts.clear();

    // Cancelar suscripción a liveAlerts — el datasource ya no emite
    // cuando el WS está desconectado, pero por seguridad cancelamos.
    _sub?.cancel();
    _sub = null;
  }

  void _onAppResumed(_TimelineAppResumed event, Emitter<TimelineState> emit) {
    // Si hay datos cargados, reanudar la suscripción a liveAlerts
    // sin recargar HTTP (los datos históricos siguen en memoria).
    if (state is TimelineLoaded && _sub == null) {
      _sub = _repo.liveAlerts.listen((a) => add(_TimelineLiveAlert(a)));
    }
  }

  // ── Carga inicial ─────────────────────────────────────────────────────────

  Future<void> _onLoad(
      TimelineLoadRequested event, Emitter<TimelineState> emit) async {
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
      final alerts = await _repo.fetchAlerts(
        tipo: _tipo,
        ruta: _ruta,
        desde: _desde,
        hasta: _hasta,
        limit: 500,
        offset: 0,
      );
      final snapshots = await compute(_buildSnapshotsIsolate, alerts);

      emit(TimelineLoaded(
        alerts: alerts,
        hasMore: false,
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
      final snapshots = await compute(_buildSnapshotsIsolate, allAlerts);
      emit(current.copyWith(
        alerts: allAlerts,
        hasMore: more.length >= AppConstants.defaultPageSize,
        offset: current.offset + more.length,
        snapshots: snapshots,
      ));
    } catch (_) {}
  }

  void _onSnapshotChanged(
      TimelineSnapshotChanged event, Emitter<TimelineState> emit) {
    final current = state;
    if (current is! TimelineLoaded) return;
    emit(current.copyWith(activeSnapshotIndex: event.snapshotIndex));
  }

  void _onLiveAlertReceived(
      _TimelineLiveAlert event, Emitter<TimelineState> emit) {
    _pendingLiveAlerts.add(event.alert);
    if (_liveThrottle?.isActive ?? false) return;
    _liveThrottle = Timer(const Duration(milliseconds: 500), () {
      add(const _TimelineFlushLiveAlerts());
    });
  }

  Future<void> _onFlushLiveAlerts(
      _TimelineFlushLiveAlerts event, Emitter<TimelineState> emit) async {
    final current = state;
    if (current is! TimelineLoaded || _pendingLiveAlerts.isEmpty) return;

    final batch = List<AlertModel>.from(_pendingLiveAlerts);
    _pendingLiveAlerts.clear();

    final allAlerts = [...batch, ...current.alerts];
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
    WidgetsBinding.instance.removeObserver(this);
    _liveThrottle?.cancel();
    _sub?.cancel();
    return super.close();
  }
}
