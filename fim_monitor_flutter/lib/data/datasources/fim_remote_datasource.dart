// lib/data/datasources/fim_remote_datasource.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alert_model.dart';
import '../models/scan_model.dart';
import '../../core/constants/app_constants.dart';

abstract class FimRemoteDatasource {
  /// Devuelve los últimos [limit] eventos, con filtros opcionales.
  Future<List<AlertModel>> getAlerts({
    String? tipo,
    String? ruta,
    String? desde,
    String? hasta,
    int limit = AppConstants.defaultPageSize,
    int offset = 0,
  });

  /// Devuelve todos los escaneos registrados.
  Future<List<ScanModel>> getScans();

  /// Estado resumido del sistema monitorizado.
  Future<Map<String, dynamic>> getStatus();
}

class FimRemoteDatasourceImpl implements FimRemoteDatasource {
  final http.Client client;
  final String baseUrl;

  FimRemoteDatasourceImpl({required this.client, required this.baseUrl});

  // ── GET /api/events ──────────────────────────────────────────────────────
  @override
  Future<List<AlertModel>> getAlerts({
    String? tipo,
    String? ruta,
    String? desde,
    String? hasta,
    int limit  = AppConstants.defaultPageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit':  limit.toString(),
      'offset': offset.toString(),
      if (tipo  != null) 'tipo':  tipo,
      if (ruta  != null) 'ruta':  ruta,
      if (desde != null) 'desde': desde,
      if (hasta != null) 'hasta': hasta,
    };

    final uri = Uri.parse('$baseUrl${AppConstants.eventsEndpoint}')
        .replace(queryParameters: params);

    final response = await client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(AppConstants.httpTimeout);

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body) as List;
      return body
          .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw FimApiException(
      'getAlerts falló: ${response.statusCode}',
      response.statusCode,
    );
  }

  // ── GET /api/scans ───────────────────────────────────────────────────────
  @override
  Future<List<ScanModel>> getScans() async {
    final uri = Uri.parse('$baseUrl${AppConstants.scansEndpoint}');
    final response = await client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(AppConstants.httpTimeout);

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body) as List;
      return body
          .map((e) => ScanModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw FimApiException(
      'getScans falló: ${response.statusCode}',
      response.statusCode,
    );
  }

  // ── GET /api/status ──────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> getStatus() async {
    final uri = Uri.parse('$baseUrl${AppConstants.statusEndpoint}');
    final response = await client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(AppConstants.httpTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw FimApiException(
      'getStatus falló: ${response.statusCode}',
      response.statusCode,
    );
  }
}

class FimApiException implements Exception {
  final String message;
  final int statusCode;
  const FimApiException(this.message, this.statusCode);

  @override
  String toString() => 'FimApiException($statusCode): $message';
}
