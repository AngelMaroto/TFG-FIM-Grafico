// lib/core/di/injection.dart
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../data/datasources/fim_remote_datasource.dart';
import '../../data/datasources/fim_websocket_datasource.dart';
import '../../data/repositories/fim_repository_impl.dart';
import '../../domain/repositories/fim_repository.dart';
import '../../presentation/blocs/connection/connection_bloc.dart';
import '../../presentation/blocs/graph/graph_bloc.dart';
import '../../presentation/blocs/timeline/timeline_bloc.dart';
import '../constants/app_constants.dart';

final GetIt sl = GetIt.instance;

Future<void> initDependencies({
  String host = AppConstants.defaultBackendHost,
  int port    = AppConstants.defaultBackendPort,
}) async {
  // ── Infraestructura ──────────────────────────────────────────────────────
  sl.registerLazySingleton<http.Client>(() => http.Client());

  sl.registerLazySingleton<FimRemoteDatasource>(
    () => FimRemoteDatasourceImpl(
      client:  sl<http.Client>(),
      baseUrl: AppConstants.baseUrl(host, port),
    ),
  );

  sl.registerLazySingleton<FimWebSocketDatasource>(
    () => FimWebSocketDatasourceImpl(
      wsUrl: AppConstants.wsUrl(host, port),
    ),
  );

  // ── Repositorio ──────────────────────────────────────────────────────────
  sl.registerLazySingleton<FimRepository>(
    () => FimRepositoryImpl(
      remote:    sl<FimRemoteDatasource>(),
      webSocket: sl<FimWebSocketDatasource>(),
    ),
  );

  // ── BLoCs ────────────────────────────────────────────────────────────────
  // factory → nueva instancia cada vez que se pide (ciclo de vida de pantalla)
  sl.registerFactory(() => ConnectionBloc(sl<FimWebSocketDatasource>()));
  sl.registerFactory(() => GraphBloc(sl<FimRepository>()));
  sl.registerFactory(() => TimelineBloc(sl<FimRepository>()));
}
