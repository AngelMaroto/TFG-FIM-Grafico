// lib/main.dart
//
// CAMBIOS v2:
//   • ThemeBloc añadido como BlocProvider global (encima de MaterialApp).
//   • MaterialApp.router usa BlocBuilder<ThemeBloc> para cambiar entre
//     AppTheme.dark y AppTheme.light en caliente sin reiniciar la app.
//   • ThemeLoaded se dispara en el arranque para leer SharedPreferences.
//
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/blocs/theme/theme_bloc.dart';
import 'presentation/pages/settings_page.dart'; // loadSavedBackend

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (host, port) = await loadSavedBackend();
  await initDependencies(host: host, port: port);
  runApp(const FimMonitorApp());
}

class FimMonitorApp extends StatelessWidget {
  const FimMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // ThemeBloc global — disponible en toda la app
      create: (_) => ThemeBloc()..add(const ThemeLoaded()),
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'FIM Monitor',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeState.isDark ? ThemeMode.dark : ThemeMode.light,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
