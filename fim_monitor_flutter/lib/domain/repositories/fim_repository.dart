// lib/domain/repositories/fim_repository.dart
import '../../data/models/alert_model.dart';
import '../../data/models/scan_model.dart';
import '../../data/datasources/fim_websocket_datasource.dart';

/// Contrato que deben cumplir las implementaciones concretas.
/// La capa de presentación (BLoCs) solo conoce esta interfaz.
abstract class FimRepository {
  Future<List<AlertModel>> fetchAlerts({
    String? tipo,
    String? ruta,
    String? desde,
    String? hasta,
    int limit  = 50,
    int offset = 0,
  });

  Future<List<ScanModel>> fetchScans();

  Future<Map<String, dynamic>> fetchStatus();

  Stream<AlertModel>        get liveAlerts;
  Stream<WsConnectionState> get connectionState;

  Future<void> connectWebSocket();
  void         disconnectWebSocket();
}
