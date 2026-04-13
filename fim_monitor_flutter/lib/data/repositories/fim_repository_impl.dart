// lib/data/repositories/fim_repository_impl.dart
import '../../domain/repositories/fim_repository.dart';
import '../datasources/fim_remote_datasource.dart';
import '../datasources/fim_websocket_datasource.dart';
import '../models/alert_model.dart';
import '../models/scan_model.dart';

class FimRepositoryImpl implements FimRepository {
  final FimRemoteDatasource    remote;
  final FimWebSocketDatasource webSocket;

  FimRepositoryImpl({required this.remote, required this.webSocket});

  @override
  Future<List<AlertModel>> fetchAlerts({
    String? tipo,
    String? ruta,
    String? desde,
    String? hasta,
    int limit  = 50,
    int offset = 0,
  }) =>
      remote.getAlerts(
        tipo: tipo, ruta: ruta, desde: desde, hasta: hasta,
        limit: limit, offset: offset,
      );

  @override
  Future<List<ScanModel>> fetchScans() => remote.getScans();

  @override
  Future<Map<String, dynamic>> fetchStatus() => remote.getStatus();

  @override
  Stream<AlertModel>        get liveAlerts      => webSocket.alertStream;
  @override
  Stream<WsConnectionState> get connectionState => webSocket.connectionStream;

  @override
  Future<void> connectWebSocket() => webSocket.connect();

  @override
  void disconnectWebSocket() => webSocket.disconnect();
}
