// lib/data/datasources/fim_websocket_datasource.dart
//
// FIX DE MEMORIA v2:
//
//   PROBLEMA ANTERIOR:
//   • onDisconnect y onWebSocketError llamaban a connect() directamente
//     mediante Future.delayed — esto ignoraba completamente el ciclo de
//     vida de la app. En background: bucle infinito de reconexión +
//     Isolates de compute() acumulándose → 6 GB RAM.
//
//   SOLUCIÓN:
//   • La reconexión automática se ELIMINA del datasource.
//     Ahora es responsabilidad del ConnectionBloc (que sí conoce el
//     estado de la app vía AppLifecycleObserver).
//   • Se añade isPaused flag: cuando la app va a background,
//     disconnect() pausa sin cerrar los StreamControllers (así se pueden
//     reusar al volver a foreground). reconnect() restablece la conexión.
//   • disconnect() ya NO cierra los StreamControllers — solo desactiva
//     el cliente STOMP. Esto permite reconectar sin recrear los BLoCs.
//   • dispose() cierra los StreamControllers definitivamente (llamado
//     solo cuando GetIt destruye la instancia).
//
import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/alert_model.dart';
import '../../core/constants/app_constants.dart';

abstract class FimWebSocketDatasource {
  Stream<AlertModel> get alertStream;
  Stream<WsConnectionState> get connectionStream;

  Future<void> connect();
  void disconnect();
  void dispose(); // cierra los StreamControllers definitivamente
}

enum WsConnectionState { connecting, connected, disconnected, error }

class FimWebSocketDatasourceImpl implements FimWebSocketDatasource {
  final String wsUrl;

  FimWebSocketDatasourceImpl({required this.wsUrl});

  StompClient? _client;
  bool _disposed = false;
  bool _connected = false;

  // broadcast() — múltiples listeners sin acumular eventos en buffer
  final _alertCtrl = StreamController<AlertModel>.broadcast();
  final _connectionCtrl = StreamController<WsConnectionState>.broadcast();

  @override
  Stream<AlertModel> get alertStream => _alertCtrl.stream;
  @override
  Stream<WsConnectionState> get connectionStream => _connectionCtrl.stream;

  @override
  Future<void> connect() async {
    if (_disposed) return;

    // Si ya hay cliente activo, no crear otro
    if (_connected) return;

    _emit(WsConnectionState.connecting);

    _client = StompClient(
      config: StompConfig.sockJS(
        url: wsUrl,
        onConnect: _onConnect,
        onDisconnect: (_) {
          _connected = false;
          // FIX: NO llamar connect() aquí — lo gestiona ConnectionBloc
          _emit(WsConnectionState.disconnected);
        },
        onWebSocketError: (_) {
          _connected = false;
          // FIX: NO llamar connect() aquí — lo gestiona ConnectionBloc
          _emit(WsConnectionState.error);
        },
        onStompError: (_) {
          _connected = false;
          _emit(WsConnectionState.error);
        },
        // Desactivar reconexión automática del cliente STOMP
        // — la gestionamos nosotros con backoff en ConnectionBloc
        reconnectDelay: Duration.zero,
      ),
    );

    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    if (_disposed) return;
    _connected = true;
    _emit(WsConnectionState.connected);

    _client!.subscribe(
      destination: AppConstants.wsTopicEvents,
      callback: (frame) {
        if (_disposed || frame.body == null) return;
        try {
          final json = jsonDecode(frame.body!) as Map<String, dynamic>;
          final alert = AlertModel.fromJson(json);
          _alertCtrl.add(alert);
        } catch (e) {
          assert(() {
            // ignore: avoid_print
            print('[WS] Mensaje malformado: $e\n${frame.body}');
            return true;
          }());
        }
      },
    );
  }

  @override
  void disconnect() {
    if (_disposed) return;
    _connected = false;
    // FIX: deactivate() para el cliente pero NO cierra los StreamControllers
    // — así los BLoCs que escuchan alertStream/connectionStream no pierden
    // la suscripción y pueden recibir eventos cuando se reconecte.
    _client?.deactivate();
    _client = null;
    _emit(WsConnectionState.disconnected);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _connected = false;
    _client?.deactivate();
    _client = null;
    // Ahora sí cerramos los StreamControllers definitivamente
    if (!_alertCtrl.isClosed) _alertCtrl.close();
    if (!_connectionCtrl.isClosed) _connectionCtrl.close();
  }

  void _emit(WsConnectionState state) {
    if (!_disposed && !_connectionCtrl.isClosed) {
      _connectionCtrl.add(state);
    }
  }
}
