// lib/data/datasources/fim_websocket_datasource.dart
import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/alert_model.dart';
import '../../core/constants/app_constants.dart';

abstract class FimWebSocketDatasource {
  /// Stream de alertas recibidas en tiempo real.
  Stream<AlertModel> get alertStream;

  /// Estado de la conexión WebSocket.
  Stream<WsConnectionState> get connectionStream;

  Future<void> connect();
  void disconnect();
}

enum WsConnectionState { connecting, connected, disconnected, error }

class FimWebSocketDatasourceImpl implements FimWebSocketDatasource {
  final String wsUrl;

  FimWebSocketDatasourceImpl({required this.wsUrl});

  StompClient? _client;

  final _alertController      = StreamController<AlertModel>.broadcast();
  final _connectionController = StreamController<WsConnectionState>.broadcast();

  @override
  Stream<AlertModel>        get alertStream      => _alertController.stream;
  @override
  Stream<WsConnectionState> get connectionStream => _connectionController.stream;

  @override
  Future<void> connect() async {
    _connectionController.add(WsConnectionState.connecting);

    _client = StompClient(
      config: StompConfig.sockJS(
        url: wsUrl,
        onConnect: _onConnect,
        onDisconnect: (_) {
          _connectionController.add(WsConnectionState.disconnected);
          // Reconexión automática
          Future.delayed(AppConstants.wsReconnectDelay, connect);
        },
        onWebSocketError: (error) {
          _connectionController.add(WsConnectionState.error);
          Future.delayed(AppConstants.wsReconnectDelay, connect);
        },
        onStompError: (frame) {
          _connectionController.add(WsConnectionState.error);
        },
        reconnectDelay: AppConstants.wsReconnectDelay,
      ),
    );

    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _connectionController.add(WsConnectionState.connected);

    _client!.subscribe(
      destination: AppConstants.wsTopicEvents,
      callback: (frame) {
        if (frame.body == null) return;
        try {
          final json = jsonDecode(frame.body!) as Map<String, dynamic>;
          final alert = AlertModel.fromJson(json);
          _alertController.add(alert);
        } catch (e) {
          // Ignorar mensajes malformados, registrar en debug
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
    _client?.deactivate();
    _alertController.close();
    _connectionController.close();
  }
}
