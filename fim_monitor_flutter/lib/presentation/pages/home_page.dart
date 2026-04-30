// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/graph/graph_bloc.dart';
import '../blocs/timeline/timeline_bloc.dart';
import '../widgets/graph/fim_graph_widget.dart';
import '../pages/timeline_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) => sl<ConnectionBloc>()..add(ConnectRequested())),
        BlocProvider(
            create: (_) => sl<GraphBloc>()..add(const GraphLoadRequested())),
        BlocProvider(
            create: (_) =>
                sl<TimelineBloc>()..add(const TimelineLoadRequested())),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.security, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          const Text('FIM Monitor'),
          const SizedBox(width: 16),
          BlocBuilder<ConnectionBloc, ConnectionState>(
            builder: (context, state) {
              final (color, label) = switch (state) {
                ConnectionConnected() => (AppColors.eventClean, 'Conectado'),
                ConnectionConnecting() => (
                    AppColors.eventModified,
                    'Conectando…'
                  ),
                ConnectionDisconnected() => (
                    AppColors.textDisabled,
                    'Desconectado'
                  ),
                ConnectionError() => (AppColors.eventDeleted, 'Error WS'),
                _ => (AppColors.textDisabled, '—'),
              };
              return Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label,
                    style: AppTextStyles.bodySmall.copyWith(color: color)),
              ]);
            },
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isWide ? const _DesktopLayout() : const _MobileLayout(),
    );
  }
}

// ── Desktop: grafo izquierda + timeline derecha ───────────────────────────────
class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(flex: 6, child: FimGraphWidget()),
      VerticalDivider(width: 1, color: AppColors.border),
      const Expanded(
        flex: 4,
        child: TimelineScreen(), // ← SUSTITUIDO
      ),
    ]);
  }
}

// ── Mobile: pestañas ──────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Grafo'),
            Tab(icon: Icon(Icons.timeline_outlined), text: 'Timeline'),
          ],
        ),
        const Expanded(
          child: TabBarView(children: [
            FimGraphWidget(),
            TimelineScreen(), // ← SUSTITUIDO
          ]),
        ),
      ]),
    );
  }
}
