// lib/presentation/blocs/connection/connection_bloc.dart
//
// FIX DE MEMORIA v3: AppLifecycleObserver integrado
//
//   • Cuando la app va a background (paused/hidden/inactive):
//     → disconnect() en el datasource (para el STOMP, libera el socket)
//     → cancela el timer de reconexión
//     → emite ConnectionDisconnected (el badge WS desaparece)
//
//   • Cuando la app vuelve a foreground (resumed):
//     → reconnect automático (si estaba conectado antes de pausar)
//
//   • Backoff exponencial para reconexión tras error:
//     3s → 6s → 12s → 24s → 48s → 60s (máximo)
//
//   • El datasource ya no tiene reconexión propia — este BLoC es el
//     único responsable de la política de reconexión.
//
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/datasources/fim_websocket_datasource.dart';

// ── Eventos ──────────────────────────────────────────────────────────────────

abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();
  @override
  List<Object?> get props => [];
}

class ConnectRequested extends ConnectionEvent {}

class DisconnectRequested extends ConnectionEvent {}

class _StateChanged extends ConnectionEvent {
  final WsConnectionState state;
  const _StateChanged(this.state);
  @override
  List<Object?> get props => [state];
}

class _AutoReconnect extends ConnectionEvent {
  const _AutoReconnect();
}

class _AppResumed extends ConnectionEvent {
  const _AppResumed();
}

class _AppPaused extends ConnectionEvent {
  const _AppPaused();
}

// ── Estados ──────────────────────────────────────────────────────────────────

abstract class ConnectionState extends Equatable {
  const ConnectionState();
  @override
  List<Object?> get props => [];
}

class ConnectionInitial extends ConnectionState {}

class ConnectionConnecting extends ConnectionState {}

class ConnectionConnected extends ConnectionState {}

class ConnectionDisconnected extends ConnectionState {}

class ConnectionError extends ConnectionState {}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState>
    with WidgetsBindingObserver {
  final FimWebSocketDatasource _ws;
  StreamSubscription<WsConnectionState>? _sub;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  bool _inBackground = false;
  bool _wasConnected = false; // para reconectar al volver a foreground

  ConnectionBloc(this._ws) : super(ConnectionInitial()) {
    on<ConnectRequested>(_onConnect);
    on<DisconnectRequested>(_onDisconnect);
    on<_StateChanged>(_onStateChanged);
    on<_AutoReconnect>(_onAutoReconnect);
    on<_AppResumed>(_onAppResumed);
    on<_AppPaused>(_onAppPaused);

    // Registrar como observer del ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Ciclo de vida de la app ───────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        add(const _AppResumed());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        add(const _AppPaused());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onAppPaused(_AppPaused event, Emitter<ConnectionState> emit) {
    if (_inBackground) return;
    _inBackground = true;
    _wasConnected = state is ConnectionConnected;

    // Cancelar timer de reconexión — no hay que reconectar en background
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _retryCount = 0;

    // Desconectar el WS — libera el socket y para el tráfico de red
    _sub?.cancel();
    _sub = null;
    _ws.disconnect();

    emit(ConnectionDisconnected());
  }

  void _onAppResumed(_AppResumed event, Emitter<ConnectionState> emit) {
    if (!_inBackground) return;
    _inBackground = false;

    // Solo reconectar si estaba conectado antes de ir a background
    if (_wasConnected) {
      add(ConnectRequested());
    }
  }

  // ── Conexión manual ───────────────────────────────────────────────────────

  Future<void> _onConnect(
      ConnectRequested event, Emitter<ConnectionState> emit) async {
    _reconnectTimer?.cancel();
    _retryCount = 0;

    emit(ConnectionConnecting());
    await _sub?.cancel();
    _sub = _ws.connectionStream.listen((s) => add(_StateChanged(s)));
    await _ws.connect();
  }

  void _onDisconnect(DisconnectRequested event, Emitter<ConnectionState> emit) {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    _ws.disconnect();
    emit(ConnectionDisconnected());
  }

  // ── Cambios de estado WS ──────────────────────────────────────────────────

  void _onStateChanged(_StateChanged event, Emitter<ConnectionState> emit) {
    // Ignorar eventos si estamos en background — evita rebuildeos innecesarios
    if (_inBackground) return;

    switch (event.state) {
      case WsConnectionState.connecting:
        emit(ConnectionConnecting());
        break;
      case WsConnectionState.connected:
        _reconnectTimer?.cancel();
        _retryCount = 0;
        emit(ConnectionConnected());
        break;
      case WsConnectionState.disconnected:
        emit(ConnectionDisconnected());
        break;
      case WsConnectionState.error:
        emit(ConnectionError());
        _scheduleReconnect();
        break;
    }
  }

  Future<void> _onAutoReconnect(
      _AutoReconnect event, Emitter<ConnectionState> emit) async {
    // No reconectar si estamos en background o ya conectados
    if (_inBackground) return;
    if (state is ConnectionConnected || state is ConnectionConnecting) return;

    emit(ConnectionConnecting());
    await _sub?.cancel();
    _sub = _ws.connectionStream.listen((s) => add(_StateChanged(s)));
    await _ws.connect();
  }

  void _scheduleReconnect() {
    if (_inBackground) return;
    _reconnectTimer?.cancel();
    // Backoff: 3 → 6 → 12 → 24 → 48 → 60 → 60…
    final delaySec = (3 * (1 << _retryCount.clamp(0, 4))).clamp(3, 60);
    _retryCount++;
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_inBackground) add(const _AutoReconnect());
    });
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _sub?.cancel();
    return super.close();
  }
}
