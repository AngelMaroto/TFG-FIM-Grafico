// lib/presentation/blocs/connection/connection_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/datasources/fim_websocket_datasource.dart';

// ── Eventos ──────────────────────────────────────────────────────────────────
abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();
  @override List<Object?> get props => [];
}
class ConnectRequested    extends ConnectionEvent {}
class DisconnectRequested extends ConnectionEvent {}
class _StateChanged extends ConnectionEvent {
  final WsConnectionState state;
  const _StateChanged(this.state);
  @override List<Object?> get props => [state];
}

// ── Estados ──────────────────────────────────────────────────────────────────
abstract class ConnectionState extends Equatable {
  const ConnectionState();
  @override List<Object?> get props => [];
}
class ConnectionInitial      extends ConnectionState {}
class ConnectionConnecting   extends ConnectionState {}
class ConnectionConnected    extends ConnectionState {}
class ConnectionDisconnected extends ConnectionState {}
class ConnectionError        extends ConnectionState {}

// ── BLoC ─────────────────────────────────────────────────────────────────────
class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  final FimWebSocketDatasource _ws;
  StreamSubscription<WsConnectionState>? _sub;

  ConnectionBloc(this._ws) : super(ConnectionInitial()) {
    on<ConnectRequested>(_onConnect);
    on<DisconnectRequested>(_onDisconnect);
    on<_StateChanged>(_onStateChanged);
  }

  Future<void> _onConnect(
      ConnectRequested event, Emitter<ConnectionState> emit) async {
    emit(ConnectionConnecting());
    _sub = _ws.connectionStream.listen(
      (s) => add(_StateChanged(s)),
    );
    await _ws.connect();
  }

  void _onDisconnect(
      DisconnectRequested event, Emitter<ConnectionState> emit) {
    _sub?.cancel();
    _ws.disconnect();
    emit(ConnectionDisconnected());
  }

  void _onStateChanged(
      _StateChanged event, Emitter<ConnectionState> emit) {
    switch (event.state) {
      case WsConnectionState.connecting:   emit(ConnectionConnecting());   break;
      case WsConnectionState.connected:    emit(ConnectionConnected());    break;
      case WsConnectionState.disconnected: emit(ConnectionDisconnected()); break;
      case WsConnectionState.error:        emit(ConnectionError());        break;
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
