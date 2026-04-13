// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // --- Backend ---
  static const String defaultBackendHost = '127.0.0.1';
  static const int defaultBackendPort = 8080;

  static String baseUrl(String host, int port) => 'http://$host:$port';
  static String wsUrl(String host, int port)   => 'ws://$host:$port/ws';

  // --- API REST endpoints ---
  static const String eventsEndpoint     = '/api/events';
  static const String scansEndpoint      = '/api/scans';
  static const String statusEndpoint     = '/api/status';
  static const String configEndpoint     = '/api/config/rules';

  // --- WebSocket: topic al que suscribirse ---
  static const String wsTopicEvents = '/topic/events';
  static const String wsAppPrefix   = '/app';

  // --- Paginación por defecto ---
  static const int defaultPageSize = 50;

  // --- Timeouts ---
  static const Duration httpTimeout      = Duration(seconds: 10);
  static const Duration wsReconnectDelay = Duration(seconds: 5);
}
