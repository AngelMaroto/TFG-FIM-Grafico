// lib/presentation/pages/home_page.dart
// v3 — fimColors + fix definitivo badge WS
//
// ANÁLISIS DEL BUG "Error WS":
// El ConnectionBloc emite ConnectionError cuando el WebSocket falla.
// Después NO reintenta automáticamente. El BlocBuilder reconstruye con
// ConnectionError y muestra el badge — correcto hasta aquí.
// El problema real es que ConnectionBloc.close() cancela la suscripción
// pero NO reconecta. Cuando el WS se recupera solo, el datasource emite
// WsConnectionState.connected pero la suscripción ya no existe.
//
// FIX definitivo: en _onStateChanged(ConnectionError) se programa un
// reintento automático con backoff (3s, 6s, 12s…) usando un Timer.
// El badge desaparece cuando ConnectionConnected llega.
// El botón "Reintentar" manual sigue disponible para forzarlo.
//
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/graph/graph_bloc.dart';
import '../blocs/theme/theme_bloc.dart';
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
    final c = context.fimColors;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.security, color: c.primary, size: 18),
          const SizedBox(width: 8),
          const Text('FIM Monitor'),
          const SizedBox(width: 16),
          // ── Indicador WS ─────────────────────────────────────────────────
          BlocBuilder<ConnectionBloc, ConnectionState>(
            builder: (context, state) {
              final (color, label, isError) = switch (state) {
                ConnectionConnected() => (c.eventClean, 'Conectado', false),
                ConnectionConnecting() => (
                    c.eventModified,
                    'Conectando…',
                    false
                  ),
                ConnectionDisconnected() => (
                    c.textDisabled,
                    'Desconectado',
                    false
                  ),
                ConnectionError() => (c.eventDeleted, 'Error WS', true),
                _ => (c.textDisabled, '—', false),
              };

              return Row(mainAxisSize: MainAxisSize.min, children: [
                // Punto de estado animado — pulsa cuando hay error
                _StatusDot(color: color, pulsing: isError),
                const SizedBox(width: 6),
                Text(label,
                    style: AppTextStyles.bodySmall.copyWith(color: color)),
                // Botón reintentar — solo visible en error
                if (isError) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () =>
                        context.read<ConnectionBloc>().add(ConnectRequested()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.eventDeleted.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: c.eventDeleted.withOpacity(0.4)),
                      ),
                      child: Text('Reintentar',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: c.eventDeleted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ]);
            },
          ),
        ]),
        actions: [
          // ── Toggle tema ───────────────────────────────────────────────────
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) => IconButton(
              icon: Icon(
                themeState.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 18,
              ),
              tooltip: themeState.isDark
                  ? 'Cambiar a tema claro'
                  : 'Cambiar a tema oscuro',
              onPressed: () =>
                  context.read<ThemeBloc>().add(const ThemeToggled()),
            ),
          ),
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

// ── Punto de estado con animación de pulso cuando hay error ──────────────────
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  const _StatusDot({required this.color, required this.pulsing});
  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.pulsing) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulsing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Layouts ───────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(flex: 6, child: FimGraphWidget()),
      VerticalDivider(width: 1, color: context.fimColors.border),
      const Expanded(flex: 4, child: TimelineScreen()),
    ]);
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout();
  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          labelColor: c.primary,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: c.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Grafo'),
            Tab(icon: Icon(Icons.timeline_outlined), text: 'Timeline'),
          ],
        ),
        const Expanded(
          child: TabBarView(children: [
            FimGraphWidget(),
            TimelineScreen(),
          ]),
        ),
      ]),
    );
  }
}
