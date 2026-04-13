// lib/presentation/blocs/timeline/timeline_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/alert_model.dart';
import '../../../domain/repositories/fim_repository.dart';
import '../../../core/constants/app_constants.dart';

// ── Eventos ──────────────────────────────────────────────────────────────────
abstract class TimelineEvent extends Equatable {
  const TimelineEvent();
  @override List<Object?> get props => [];
}

class TimelineLoadRequested extends TimelineEvent {
  final String? tipo;
  final String? ruta;
  final String? desde;
  final String? hasta;
  const TimelineLoadRequested({this.tipo, this.ruta, this.desde, this.hasta});
  @override List<Object?> get props => [tipo, ruta, desde, hasta];
}

class TimelineLoadMore extends TimelineEvent {}

class _TimelineLiveAlert extends TimelineEvent {
  final AlertModel alert;
  const _TimelineLiveAlert(this.alert);
  @override List<Object?> get props => [alert];
}

// ── Estados ──────────────────────────────────────────────────────────────────
abstract class TimelineState extends Equatable {
  const TimelineState();
  @override List<Object?> get props => [];
}

class TimelineInitial extends TimelineState {}
class TimelineLoading  extends TimelineState {}

class TimelineLoaded extends TimelineState {
  final List<AlertModel> alerts;
  final bool hasMore;
  final int  offset;

  const TimelineLoaded({
    required this.alerts,
    required this.hasMore,
    required this.offset,
  });

  TimelineLoaded copyWith({
    List<AlertModel>? alerts,
    bool? hasMore,
    int?  offset,
  }) =>
      TimelineLoaded(
        alerts:  alerts  ?? this.alerts,
        hasMore: hasMore ?? this.hasMore,
        offset:  offset  ?? this.offset,
      );

  @override
  List<Object?> get props => [alerts, hasMore, offset];
}

class TimelineError extends TimelineState {
  final String message;
  const TimelineError(this.message);
  @override List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────
class TimelineBloc extends Bloc<TimelineEvent, TimelineState> {
  final FimRepository _repo;
  StreamSubscription<AlertModel>? _sub;

  // Filtros actuales
  String? _tipo, _ruta, _desde, _hasta;

  TimelineBloc(this._repo) : super(TimelineInitial()) {
    on<TimelineLoadRequested>(_onLoad);
    on<TimelineLoadMore>(_onLoadMore);
    on<_TimelineLiveAlert>(_onLiveAlert);
  }

  Future<void> _onLoad(
      TimelineLoadRequested event, Emitter<TimelineState> emit) async {
    emit(TimelineLoading());
    _tipo  = event.tipo;
    _ruta  = event.ruta;
    _desde = event.desde;
    _hasta = event.hasta;

    try {
      final alerts = await _repo.fetchAlerts(
        tipo: _tipo, ruta: _ruta, desde: _desde, hasta: _hasta,
        limit: AppConstants.defaultPageSize, offset: 0,
      );
      emit(TimelineLoaded(
        alerts:  alerts,
        hasMore: alerts.length >= AppConstants.defaultPageSize,
        offset:  alerts.length,
      ));

      await _sub?.cancel();
      _sub = _repo.liveAlerts.listen(
        (a) => add(_TimelineLiveAlert(a)),
      );
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
        tipo: _tipo, ruta: _ruta, desde: _desde, hasta: _hasta,
        limit: AppConstants.defaultPageSize, offset: current.offset,
      );
      emit(current.copyWith(
        alerts:  [...current.alerts, ...more],
        hasMore: more.length >= AppConstants.defaultPageSize,
        offset:  current.offset + more.length,
      ));
    } catch (_) {/* mantener estado actual, no lanzar error de paginación */}
  }

  void _onLiveAlert(
      _TimelineLiveAlert event, Emitter<TimelineState> emit) {
    final current = state;
    if (current is! TimelineLoaded) return;
    // Insertar al principio (más reciente arriba)
    emit(current.copyWith(alerts: [event.alert, ...current.alerts]));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
