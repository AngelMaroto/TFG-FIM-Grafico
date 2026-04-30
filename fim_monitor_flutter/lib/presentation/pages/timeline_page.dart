// lib/presentation/screens/timeline_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/timeline/timeline_bloc.dart';
import '../blocs/graph/graph_bloc.dart';
import '../../data/models/alert_model.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _rutaController = TextEditingController();

  final _tipoNotifier = ValueNotifier<String?>(null);
  final _severidadNotifier = ValueNotifier<String?>(null);
  final _rangoNotifier = ValueNotifier<DateTimeRange?>(null);

  static const _tipos = ['NEW', 'DELETED', 'MODIFIED', 'PERMISSIONS'];
  static const _severidades = ['ALTA', 'MEDIA', 'BAJA'];

  @override
  void initState() {
    super.initState();
    context.read<TimelineBloc>().add(const TimelineLoadRequested());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _rutaController.dispose();
    _tipoNotifier.dispose();
    _severidadNotifier.dispose();
    _rangoNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<TimelineBloc>().add(TimelineLoadMore());
    }
  }

  void _aplicarFiltros() {
    final rango = _rangoNotifier.value;
    context.read<TimelineBloc>().add(TimelineLoadRequested(
          tipo: _tipoNotifier.value,
          ruta: _rutaController.text.isEmpty ? null : _rutaController.text,
          desde: rango != null
              ? DateFormat('yyyy-MM-dd').format(rango.start)
              : null,
          hasta:
              rango != null ? DateFormat('yyyy-MM-dd').format(rango.end) : null,
        ));
  }

  void _limpiarFiltros() {
    _tipoNotifier.value = null;
    _severidadNotifier.value = null;
    _rangoNotifier.value = null;
    _rutaController.clear();
    context.read<TimelineBloc>().add(const TimelineLoadRequested());
  }

  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _rangoNotifier.value,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF00D4FF),
            surface: const Color(0xFF1A1F2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _rangoNotifier.value = picked;
      _aplicarFiltros();
    }
  }

  /// Cuando el slider cambia de posición:
  /// 1. Notifica al TimelineBloc (actualiza el índice activo)
  /// 2. Notifica al GraphBloc (repinta los nodos con el estado histórico)
  void _onSliderChanged(int index, TimelineLoaded state) {
    context.read<TimelineBloc>().add(TimelineSnapshotChanged(index));

    final isLive = index == state.snapshots.length - 1;
    if (isLive) {
      // Volver a en vivo: quitar el override del grafo
      context.read<GraphBloc>().add(const GraphSnapshotApplied(null));
    } else {
      // Aplicar el estado histórico del snapshot seleccionado
      final snap = state.snapshots[index];
      context.read<GraphBloc>().add(GraphSnapshotApplied(snap.nodeStates));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(
            child: BlocBuilder<TimelineBloc, TimelineState>(
              buildWhen: (prev, curr) {
                if (prev is TimelineLoaded && curr is TimelineLoaded) {
                  return prev.alerts != curr.alerts ||
                      prev.hasMore != curr.hasMore;
                }
                return true;
              },
              builder: (context, state) {
                if (state is TimelineLoading) return _buildLoading();
                if (state is TimelineError) return _buildError(state.message);
                if (state is TimelineLoaded) {
                  if (state.alerts.isEmpty) return _buildEmpty();
                  return _buildTimeline(state);
                }
                return _buildLoading();
              },
            ),
          ),
          // Scrollbar temporal — conectado tanto a Timeline como a GraphBloc
          BlocBuilder<TimelineBloc, TimelineState>(
            buildWhen: (prev, curr) {
              if (prev is TimelineLoaded && curr is TimelineLoaded) {
                return prev.snapshots.length != curr.snapshots.length ||
                    prev.activeSnapshotIndex != curr.activeSnapshotIndex;
              }
              return curr is TimelineLoaded;
            },
            builder: (context, state) {
              if (state is! TimelineLoaded || state.snapshots.isEmpty) {
                return const SizedBox.shrink();
              }
              return _TemporalScrollbar(
                snapshots: state.snapshots,
                activeIndex: state.activeSnapshotIndex,
                isLive: state.isLive,
                onIndexChanged: (i) => _onSliderChanged(i, state),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF13192A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2940), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.timeline, color: Color(0xFF00D4FF), size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Línea Temporal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Historial de eventos de auditoría',
                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          BlocBuilder<TimelineBloc, TimelineState>(
            buildWhen: (prev, curr) {
              if (prev is TimelineLoaded && curr is TimelineLoaded) {
                return prev.alerts.length != curr.alerts.length;
              }
              return curr is TimelineLoaded;
            },
            builder: (context, state) {
              if (state is! TimelineLoaded) return const SizedBox.shrink();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF00D4FF).withOpacity(0.3)),
                ),
                child: Text(
                  '${state.alerts.length} eventos',
                  style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF0F1520),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _tipoNotifier,
                  builder: (_, tipo, __) => _DropdownFiltro(
                    hint: 'Tipo',
                    value: tipo,
                    items: _tipos,
                    icon: Icons.category_outlined,
                    colorMap: _colorPorTipo,
                    onChanged: (v) {
                      _tipoNotifier.value = v;
                      _aplicarFiltros();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<String?>(
                  valueListenable: _severidadNotifier,
                  builder: (_, sev, __) => _DropdownFiltro(
                    hint: 'Severidad',
                    value: sev,
                    items: _severidades,
                    icon: Icons.warning_amber_outlined,
                    colorMap: _colorPorSeveridad,
                    onChanged: (v) => _severidadNotifier.value = v,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<DateTimeRange?>(
                valueListenable: _rangoNotifier,
                builder: (_, rango, __) => GestureDetector(
                  onTap: _seleccionarRango,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: rango != null
                          ? const Color(0xFF00D4FF).withOpacity(0.15)
                          : const Color(0xFF1A2030),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: rango != null
                            ? const Color(0xFF00D4FF).withOpacity(0.5)
                            : const Color(0xFF2A3350),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range,
                            size: 16,
                            color: rango != null
                                ? const Color(0xFF00D4FF)
                                : const Color(0xFF6B7A99)),
                        const SizedBox(width: 6),
                        Text(
                          rango != null
                              ? '${DateFormat('dd/MM').format(rango.start)} – ${DateFormat('dd/MM').format(rango.end)}'
                              : 'Fechas',
                          style: TextStyle(
                            color: rango != null
                                ? const Color(0xFF00D4FF)
                                : const Color(0xFF6B7A99),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<String?>(
                valueListenable: _tipoNotifier,
                builder: (_, tipo, __) =>
                    ValueListenableBuilder<DateTimeRange?>(
                  valueListenable: _rangoNotifier,
                  builder: (_, rango, __) {
                    final hayFiltros = tipo != null ||
                        rango != null ||
                        _rutaController.text.isNotEmpty;
                    if (!hayFiltros) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: _limpiarFiltros,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1A1A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF4A2020)),
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Color(0xFFFF6B6B)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rutaController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Filtrar por ruta  (ej. /etc/passwd)',
              hintStyle:
                  const TextStyle(color: Color(0xFF3A4560), fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF3A4560), size: 18),
              filled: true,
              fillColor: const Color(0xFF1A2030),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A3350)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A3350)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF00D4FF), width: 1.5),
              ),
            ),
            onSubmitted: (_) => _aplicarFiltros(),
          ),
        ],
      ),
    );
  }

  // ── Timeline list ─────────────────────────────────────────────────────────

  Widget _buildTimeline(TimelineLoaded state) {
    final sev = _severidadNotifier.value;
    final alerts = sev != null
        ? state.alerts.where((a) => a.severidad == sev).toList()
        : state.alerts;

    if (alerts.isEmpty) return _buildEmpty();

    final grupos = <String, List<AlertModel>>{};
    for (final a in alerts) {
      final fecha = _formatearFechaGrupo(a.fechaEjecucion);
      grupos.putIfAbsent(fecha, () => []).add(a);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: grupos.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == grupos.length) return _buildLoadMoreIndicator();
        final fecha = grupos.keys.elementAt(index);
        final items = grupos[fecha]!;
        return _GrupoFecha(fecha: fecha, alerts: items, isFirst: index == 0);
      },
    );
  }

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF00D4FF)),
            ),
            SizedBox(height: 16),
            Text('Cargando eventos...',
                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 14)),
          ],
        ),
      );

  Widget _buildError(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 48),
            const SizedBox(height: 12),
            const Text('Error al cargar eventos',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(msg,
                style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _aplicarFiltros,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF)),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: Color(0xFF2A3350), size: 56),
            SizedBox(height: 12),
            Text('Sin eventos',
                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 16)),
            SizedBox(height: 4),
            Text('No hay eventos con los filtros actuales',
                style: TextStyle(color: Color(0xFF3A4560), fontSize: 12)),
          ],
        ),
      );

  Widget _buildLoadMoreIndicator() => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF00D4FF)),
          ),
        ),
      );

  String _formatearFechaGrupo(String? raw) {
    if (raw == null) return 'Fecha desconocida';
    try {
      final dt = DateTime.parse(raw);
      final hoy = DateTime.now();
      final ayer = hoy.subtract(const Duration(days: 1));
      if (DateFormat('yyyy-MM-dd').format(dt) ==
          DateFormat('yyyy-MM-dd').format(hoy)) {
        return 'Hoy · ${DateFormat('dd MMM yyyy', 'es').format(dt)}';
      }
      if (DateFormat('yyyy-MM-dd').format(dt) ==
          DateFormat('yyyy-MM-dd').format(ayer)) {
        return 'Ayer · ${DateFormat('dd MMM yyyy', 'es').format(dt)}';
      }
      return DateFormat('EEEE, dd MMM yyyy', 'es').format(dt);
    } catch (_) {
      return raw;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCROLLBAR TEMPORAL
// ═══════════════════════════════════════════════════════════════════════════════

class _TemporalScrollbar extends StatefulWidget {
  final List<GraphSnapshot> snapshots;
  final int activeIndex;
  final bool isLive;
  final ValueChanged<int> onIndexChanged;

  const _TemporalScrollbar({
    required this.snapshots,
    required this.activeIndex,
    required this.isLive,
    required this.onIndexChanged,
  });

  @override
  State<_TemporalScrollbar> createState() => _TemporalScrollbarState();
}

class _TemporalScrollbarState extends State<_TemporalScrollbar> {
  final ScrollController _railController = ScrollController();

  @override
  void dispose() {
    _railController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TemporalScrollbar old) {
    super.didUpdateWidget(old);
    if (old.activeIndex != widget.activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!_railController.hasClients) return;
    const itemWidth = 80.0;
    final target = widget.activeIndex * itemWidth;
    _railController.animateTo(
      target.clamp(0.0, _railController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.snapshots.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      height: 120,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1A),
        border: Border(top: BorderSide(color: Color(0xFF1E2940))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 13, color: Color(0xFF4A5880)),
                const SizedBox(width: 6),
                const Text(
                  'VIAJE EN EL TIEMPO',
                  style: TextStyle(
                    color: Color(0xFF4A5880),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.isLive
                      ? Row(
                          key: const ValueKey('live'),
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF4ADE80),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('EN VIVO',
                                style: TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                )),
                          ],
                        )
                      : Text(
                          widget.snapshots[widget.activeIndex].label,
                          key: ValueKey(widget.activeIndex),
                          style: const TextStyle(
                            color: Color(0xFF00D4FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: const Color(0xFF00D4FF),
                inactiveTrackColor: const Color(0xFF1E2940),
                thumbColor: const Color(0xFF00D4FF),
                overlayColor: const Color(0x2000D4FF),
              ),
              child: Slider(
                min: 0,
                max: (count - 1).toDouble(),
                value: widget.activeIndex.toDouble().clamp(0, count - 1),
                divisions: count > 1 && count <= 50 ? count - 1 : null,
                onChanged: (v) => widget.onIndexChanged(v.round()),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _railController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: count,
              itemBuilder: (context, index) {
                final snap = widget.snapshots[index];
                final isActive = index == widget.activeIndex;
                final dotColor = _colorForSnapshot(snap);

                return GestureDetector(
                  onTap: () => widget.onIndexChanged(index),
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: isActive ? 12 : 8,
                          height: isActive ? 12 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor.withOpacity(isActive ? 1.0 : 0.5),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                        color: dotColor.withOpacity(0.6),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _shortLabel(snap.timestamp),
                          style: TextStyle(
                            fontSize: 9,
                            color: isActive
                                ? const Color(0xFF00D4FF)
                                : const Color(0xFF3A4560),
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '${snap.nodeStates.length} nodos',
                          style: const TextStyle(
                              fontSize: 8, color: Color(0xFF2A3350)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForSnapshot(GraphSnapshot snap) {
    final values = snap.nodeStates.values;
    if (values.contains('DELETED')) return const Color(0xFFFF6B6B);
    if (values.contains('NEW')) return const Color(0xFF4ADE80);
    if (values.contains('MODIFIED')) return const Color(0xFFFFB347);
    if (values.contains('PERMISSIONS')) return const Color(0xFFB47FFF);
    return const Color(0xFF4A5880);
  }

  String _shortLabel(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}\n'
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRUPO DE FECHA
// ═══════════════════════════════════════════════════════════════════════════════

class _GrupoFecha extends StatelessWidget {
  final String fecha;
  final List<AlertModel> alerts;
  final bool isFirst;

  const _GrupoFecha({
    required this.fecha,
    required this.alerts,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFirst) const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 8, top: 4),
          child: Row(
            children: [
              Text(
                fecha.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF4A5880),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2030),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${alerts.length}',
                    style: const TextStyle(
                        color: Color(0xFF4A5880),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        ...alerts.map((a) => _AlertItem(alert: a)),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT ITEM — fix overflow: altura dinámica con LayoutBuilder
// ═══════════════════════════════════════════════════════════════════════════════
//
// CAUSA DEL OVERFLOW: la versión anterior usaba alturas fijas constantes
// (_colapsadoHeight = 62, _expandidoExtra = 158) que no se adaptaban al
// contenido real de cada tarjeta (número de campos de detalle variables).
//
// SOLUCIÓN: eliminar la altura fija del AnimatedContainer y dejar que el
// Column crezca según su contenido. La línea vertical usa un Container
// con altura fija solo para el segmento superior, y se extiende hacia abajo
// con Expanded dentro de un IntrinsicHeight...
//
// PERO IntrinsicHeight causa jank. Alternativa correcta: usar un Stack
// con la línea detrás y la tarjeta delante, sin altura acoplada.

class _AlertItem extends StatefulWidget {
  final AlertModel alert;
  const _AlertItem({required this.alert});

  @override
  State<_AlertItem> createState() => _AlertItemState();
}

class _AlertItemState extends State<_AlertItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color =
        _colorPorTipo[widget.alert.tipoCambio] ?? const Color(0xFF6B7A99);
    final severityColor =
        _colorPorSeveridad[widget.alert.severidad] ?? const Color(0xFF6B7A99);
    final hora = _formatearHora(widget.alert.fechaEjecucion);
    final nombreArchivo = _nombreDesdeRuta(widget.alert.rutaArchivo);

    // Stack: línea vertical de fondo + tarjeta encima.
    // La tarjeta crece libremente según su contenido (sin altura fija).
    // La línea es un Positioned.fill que se adapta al tamaño del Stack.
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna izquierda: dot + línea vertical
          SizedBox(
            width: 28,
            child: CustomPaint(
              painter: _VerticalLinePainter(color: const Color(0xFF1E2940)),
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Tarjeta — crece según contenido
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _expanded
                      ? const Color(0xFF141C2E)
                      : const Color(0xFF0F1520),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _expanded
                        ? color.withOpacity(0.4)
                        : const Color(0xFF1A2540),
                    width: _expanded ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // ← clave: no fuerza altura
                  children: [
                    // Fila principal
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          _TipoBadge(
                              tipo: widget.alert.tipoCambio, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreArchivo,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.alert.rutaArchivo != null)
                                  Text(
                                    widget.alert.rutaArchivo!,
                                    style: const TextStyle(
                                      color: Color(0xFF4A5880),
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _SeveridadBadge(
                                  severidad: widget.alert.severidad,
                                  color: severityColor),
                              const SizedBox(height: 3),
                              Text(hora,
                                  style: const TextStyle(
                                      color: Color(0xFF3A4560), fontSize: 10)),
                            ],
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: const Color(0xFF3A4560),
                          ),
                        ],
                      ),
                    ),
                    // Panel de detalle — se añade/quita en el árbol, no hay
                    // altura fija que pueda desbordarse
                    if (_expanded) _buildDetalle(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalle() {
    final a = widget.alert;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A2030)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _DetalleRow(label: 'ID Alerta', value: '#${a.id}'),
          if (a.scanId != null)
            _DetalleRow(label: 'Scan ID', value: '#${a.scanId}'),
          if (a.rutaArchivo != null)
            _DetalleRow(label: 'Ruta', value: a.rutaArchivo!),
          if (a.permisos != null)
            _DetalleRow(label: 'Permisos', value: a.permisos!),
          if (a.tamano != null)
            _DetalleRow(label: 'Tamaño', value: _formatSize(a.tamano!)),
          if (a.hashActual != null)
            _DetalleRow(
              label: 'Hash actual',
              value: a.hashActual!.length > 16
                  ? '${a.hashActual!.substring(0, 16)}…'
                  : a.hashActual!,
              mono: true,
            ),
          if (a.hashAnterior != null)
            _DetalleRow(
              label: 'Hash anterior',
              value: a.hashAnterior!.length > 16
                  ? '${a.hashAnterior!.substring(0, 16)}…'
                  : a.hashAnterior!,
              mono: true,
            ),
          if (a.fechaEjecucion != null)
            _DetalleRow(
                label: 'Fecha',
                value: _formatearFechaCompleta(a.fechaEjecucion)),
        ],
      ),
    );
  }

  String _formatearHora(String? raw) {
    if (raw == null) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(raw));
    } catch (_) {
      return '';
    }
  }

  String _formatearFechaCompleta(String? raw) {
    if (raw == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _nombreDesdeRuta(String? ruta) {
    if (ruta == null || ruta.isEmpty) return 'Archivo desconocido';
    return ruta.split('/').last;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// CustomPainter para la línea vertical — dibuja desde el centro hasta el fondo
// del widget, sin necesidad de conocer la altura del hijo.
class _VerticalLinePainter extends CustomPainter {
  final Color color;
  const _VerticalLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width / 2, 22),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_VerticalLinePainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════════════════

class _TipoBadge extends StatelessWidget {
  final String tipo;
  final Color color;
  const _TipoBadge({required this.tipo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoPorTipo(tipo), size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            tipo,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconoPorTipo(String tipo) {
    return switch (tipo) {
      'NEW' => Icons.add_circle_outline,
      'DELETED' => Icons.remove_circle_outline,
      'MODIFIED' => Icons.edit_outlined,
      'PERMISSIONS' => Icons.lock_outline,
      _ => Icons.circle_outlined,
    };
  }
}

class _SeveridadBadge extends StatelessWidget {
  final String severidad;
  final Color color;
  const _SeveridadBadge({required this.severidad, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severidad,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DetalleRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _DetalleRow(
      {required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: Color(0xFF4A5880), fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: const Color(0xFFB0BFDD),
                fontSize: 11,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownFiltro extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final IconData icon;
  final Map<String, Color> colorMap;
  final ValueChanged<String?> onChanged;

  const _DropdownFiltro({
    required this.hint,
    required this.value,
    required this.items,
    required this.icon,
    required this.colorMap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = value != null ? colorMap[value] : null;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: value != null
            ? (activeColor?.withOpacity(0.12) ?? const Color(0xFF1A2030))
            : const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != null
              ? (activeColor?.withOpacity(0.5) ?? const Color(0xFF2A3350))
              : const Color(0xFF2A3350),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF6B7A99)),
              const SizedBox(width: 6),
              Text(hint,
                  style:
                      const TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
            ],
          ),
          dropdownColor: const Color(0xFF13192A),
          iconSize: 16,
          iconEnabledColor: activeColor ?? const Color(0xFF6B7A99),
          isExpanded: true,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('Todos',
                  style:
                      const TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
            ),
            ...items.map((item) {
              final c = colorMap[item] ?? const Color(0xFF6B7A99);
              return DropdownMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(item,
                        style: TextStyle(
                            color: c,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
          onChanged: onChanged,
          selectedItemBuilder: (_) => [
            Text('Todos',
                style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
            ...items.map((item) {
              final c = colorMap[item] ?? const Color(0xFF6B7A99);
              return Text(item,
                  style: TextStyle(
                      color: c, fontSize: 12, fontWeight: FontWeight.w600));
            }),
          ],
        ),
      ),
    );
  }
}

// ── Paletas ───────────────────────────────────────────────────────────────────

const _colorPorTipo = {
  'NEW': Color(0xFF4ADE80),
  'DELETED': Color(0xFFFF6B6B),
  'MODIFIED': Color(0xFFFFB347),
  'PERMISSIONS': Color(0xFFB47FFF),
  'CLEAN': Color(0xFF4A5880),
};

const _colorPorSeveridad = {
  'ALTA': Color(0xFFFF6B6B),
  'MEDIA': Color(0xFFFFB347),
  'BAJA': Color(0xFF4ADE80),
};
