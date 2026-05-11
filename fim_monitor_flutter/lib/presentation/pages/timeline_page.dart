// lib/presentation/screens/timeline_screen.dart
// v4 — refactorización completa de colores hardcodeados → context.fimColors
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/timeline/timeline_bloc.dart';
import '../blocs/graph/graph_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/alert_model.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});
  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _rutaController = TextEditingController();

  String? _filterTipo;
  String? _filterSeveridad;
  DateTimeRange? _filterRango;
  Timer? _sliderDebounce;

  static const _tipos = ['NEW', 'DELETED', 'MODIFIED', 'PERMISSIONS'];
  static const _severidades = ['ALTA', 'MEDIA', 'BAJA'];

  @override
  void initState() {
    super.initState();
    context.read<TimelineBloc>().add(const TimelineLoadRequested());
  }

  @override
  void dispose() {
    _sliderDebounce?.cancel();
    _scrollController.dispose();
    _rutaController.dispose();
    super.dispose();
  }

  void _aplicarFiltros() {
    if (!mounted) return;
    final rango = _filterRango;
    context.read<TimelineBloc>().add(TimelineLoadRequested(
          ruta: _rutaController.text.isEmpty ? null : _rutaController.text,
          desde: rango != null
              ? DateFormat('yyyy-MM-dd').format(rango.start)
              : null,
          hasta:
              rango != null ? DateFormat('yyyy-MM-dd').format(rango.end) : null,
        ));
  }

  void _limpiarFiltros() {
    if (!mounted) return;
    setState(() {
      _filterTipo = null;
      _filterSeveridad = null;
      _filterRango = null;
    });
    _rutaController.clear();
    context.read<TimelineBloc>().add(const TimelineLoadRequested());
  }

  Future<void> _seleccionarRango() async {
    final c = context.fimColors;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _filterRango,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: c.accent,
            surface: c.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _filterRango = picked);
      _aplicarFiltros();
    }
  }

  void _onSliderChanged(int index, TimelineLoaded state) {
    _sliderDebounce?.cancel();
    _sliderDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      context.read<TimelineBloc>().add(TimelineSnapshotChanged(index));
      final isLive = index == state.snapshots.length - 1;
      if (isLive) {
        context.read<GraphBloc>().add(const GraphSnapshotApplied(null));
      } else {
        context
            .read<GraphBloc>()
            .add(GraphSnapshotApplied(state.snapshots[index].nodeStates));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;

    return BlocListener<GraphBloc, GraphState>(
      listenWhen: (prev, curr) {
        if (prev is GraphLoaded && curr is GraphLoaded) {
          return prev.snapshotOverride != null && curr.snapshotOverride == null;
        }
        return false;
      },
      listener: (context, _) {
        final tlState = context.read<TimelineBloc>().state;
        if (tlState is TimelineLoaded && tlState.snapshots.isNotEmpty) {
          context
              .read<TimelineBloc>()
              .add(TimelineSnapshotChanged(tlState.snapshots.length - 1));
        }
      },
      child: ColoredBox(
        color: c.surfaceVariant,
        child: Column(
          children: [
            _buildHeader(c),
            _buildFilterBar(c),
            Expanded(
              child: BlocBuilder<TimelineBloc, TimelineState>(
                builder: (context, state) {
                  if (state is TimelineLoading) return _buildLoading(c);
                  if (state is TimelineError)
                    return _buildError(c, state.message);
                  if (state is TimelineLoaded) {
                    if (state.alerts.isEmpty) return _buildEmpty(c);
                    return _buildTimeline(c, state);
                  }
                  return _buildLoading(c);
                },
              ),
            ),
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
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(FimColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        color: c.headerBg,
        border: Border(bottom: BorderSide(color: c.headerBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.timeline, color: c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Línea Temporal',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              Text('Historial de eventos de auditoría',
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
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
                  color: c.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.accent.withOpacity(0.3)),
                ),
                child: Text('${state.alerts.length} eventos',
                    style: TextStyle(
                        color: c.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar(FimColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: c.filterBarBg,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DropdownFiltro(
                  hint: 'Tipo',
                  value: _filterTipo,
                  items: _tipos,
                  icon: Icons.category_outlined,
                  colorFn: (v) => eventColorFrom(v, c),
                  onChanged: (v) => setState(() => _filterTipo = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownFiltro(
                  hint: 'Severidad',
                  value: _filterSeveridad,
                  items: _severidades,
                  icon: Icons.warning_amber_outlined,
                  colorFn: (v) => severityColorFrom(v, c),
                  onChanged: (v) => setState(() => _filterSeveridad = v),
                ),
              ),
              const SizedBox(width: 8),
              _DateRangeButton(
                rango: _filterRango,
                accent: c.accent,
                border: c.border,
                textSecondary: c.textSecondary,
                surfaceCard: c.surfaceCard,
                onTap: _seleccionarRango,
              ),
              if (_filterTipo != null ||
                  _filterSeveridad != null ||
                  _filterRango != null ||
                  _rutaController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: _limpiarFiltros,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.eventDeleted.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: c.eventDeleted.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.close, size: 16, color: c.eventDeleted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rutaController,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Filtrar por ruta  (ej. /etc/passwd)',
              hintStyle: TextStyle(color: c.textDisabled, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: c.textDisabled, size: 18),
              filled: true,
              fillColor: c.surfaceVariant,
            ),
            onSubmitted: (_) => _aplicarFiltros(),
          ),
        ],
      ),
    );
  }

  // ── Timeline list ─────────────────────────────────────────────────────────

  List<AlertModel> _applyLocalFilters(List<AlertModel> alerts) {
    return alerts.where((a) {
      if (_filterTipo != null && a.tipoCambio != _filterTipo) return false;
      if (_filterSeveridad != null &&
          a.severidad.toUpperCase() != _filterSeveridad!.toUpperCase())
        return false;
      return true;
    }).toList();
  }

  Widget _buildTimeline(FimColors c, TimelineLoaded state) {
    final alerts = _applyLocalFilters(state.alerts);
    if (alerts.isEmpty) return _buildEmpty(c);

    final grupos = <String, List<AlertModel>>{};
    for (final a in alerts) {
      grupos
          .putIfAbsent(_formatearFechaGrupo(a.fechaEjecucion), () => [])
          .add(a);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: grupos.length,
      itemBuilder: (context, index) {
        final fecha = grupos.keys.elementAt(index);
        return _GrupoFecha(
          fecha: fecha,
          alerts: grupos[fecha]!,
          isFirst: index == 0,
        );
      },
    );
  }

  Widget _buildLoading(FimColors c) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
          ),
          const SizedBox(height: 16),
          Text('Cargando eventos...',
              style: TextStyle(color: c.textSecondary, fontSize: 14)),
        ]),
      );

  Widget _buildError(FimColors c, String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, color: c.eventDeleted, size: 48),
          const SizedBox(height: 12),
          Text('Error al cargar eventos',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(msg, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _aplicarFiltros,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
            style: FilledButton.styleFrom(
                backgroundColor: c.accent, foregroundColor: Colors.white),
          ),
        ]),
      );

  Widget _buildEmpty(FimColors c) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.inbox_outlined, color: c.textDisabled, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Sin eventos',
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('No hay eventos con los filtros actuales',
              style: TextStyle(color: c.textDisabled, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
              'Comprueba que el agente FIM está activo y ha ejecutado un escaneo',
              style: TextStyle(
                  color: c.textDisabled.withOpacity(0.7), fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      );

  String _formatearFechaGrupo(String? raw) {
    if (raw == null) return 'Fecha desconocida';
    try {
      final dt = DateTime.parse(raw);
      final hoy = DateTime.now();
      final ayer = hoy.subtract(const Duration(days: 1));
      final fmt = DateFormat('yyyy-MM-dd');
      if (fmt.format(dt) == fmt.format(hoy))
        return 'Hoy · ${DateFormat('dd MMM yyyy', 'es').format(dt)}';
      if (fmt.format(dt) == fmt.format(ayer))
        return 'Ayer · ${DateFormat('dd MMM yyyy', 'es').format(dt)}';
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToActive();
      });
    }
  }

  void _scrollToActive() {
    if (!_railController.hasClients) return;
    if (widget.activeIndex == widget.snapshots.length - 1) {
      _railController.animateTo(_railController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }
    final target = widget.activeIndex * 80.0;
    _railController.animateTo(
      target.clamp(0.0, _railController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    final count = widget.snapshots.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: c.timelineRailBg,
        border: Border(top: BorderSide(color: c.timelineRailBorder)),
      ),
      child: Column(
        children: [
          // ── Cabecera rail ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 13, color: c.textDisabled),
                const SizedBox(width: 6),
                Text('VIAJE EN EL TIEMPO',
                    style: TextStyle(
                        color: c.textDisabled,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.isLive
                      ? Row(key: const ValueKey('live'), children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: c.eventClean)),
                          const SizedBox(width: 5),
                          Text('EN VIVO',
                              style: TextStyle(
                                  color: c.eventClean,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1)),
                        ])
                      : Text(widget.snapshots[widget.activeIndex].label,
                          key: ValueKey(widget.activeIndex),
                          style: TextStyle(
                              color: c.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // ── Slider ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: c.accent,
                inactiveTrackColor: c.border,
                thumbColor: c.accent,
                overlayColor: c.accent.withOpacity(0.2),
              ),
              child: Slider(
                min: 0,
                max: (count - 1).toDouble(),
                value: widget.activeIndex.toDouble().clamp(0, count - 1),
                divisions: count > 1 && count <= 30 ? count - 1 : null,
                onChanged: (v) => widget.onIndexChanged(v.round()),
              ),
            ),
          ),
          // ── Rail de dots ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _railController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: count,
              itemBuilder: (context, index) {
                final snap = widget.snapshots[index];
                final isActive = index == widget.activeIndex;
                final dotColor = _colorForSnapshot(snap, c);

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
                        Text(_shortLabel(snap.timestamp),
                            style: TextStyle(
                                fontSize: 9,
                                color: isActive ? c.accent : c.textDisabled,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.normal),
                            textAlign: TextAlign.center),
                        Text('${snap.nodeStates.length} nodos',
                            style:
                                TextStyle(fontSize: 8, color: c.textDisabled),
                            textAlign: TextAlign.center),
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

  Color _colorForSnapshot(GraphSnapshot snap, FimColors c) {
    final v = snap.nodeStates.values;
    if (v.contains('DELETED')) return c.eventDeleted;
    if (v.contains('NEW')) return c.eventNew;
    if (v.contains('MODIFIED')) return c.eventModified;
    if (v.contains('PERMISSIONS')) return c.eventPerms;
    return c.textDisabled;
  }

  String _shortLabel(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}\n'
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRUPO DE FECHA
// ═══════════════════════════════════════════════════════════════════════════════

class _GrupoFecha extends StatelessWidget {
  final String fecha;
  final List<AlertModel> alerts;
  final bool isFirst;
  const _GrupoFecha(
      {required this.fecha, required this.alerts, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFirst) const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 8, top: 4),
          child: Row(children: [
            Text(fecha.toUpperCase(),
                style: TextStyle(
                    color: c.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${alerts.length}',
                  style: TextStyle(
                      color: c.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        ...alerts.map((a) => _AlertItem(alert: a)),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERT ITEM
// ═══════════════════════════════════════════════════════════════════════════════

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
    final c = context.fimColors;
    final color = eventColorFrom(widget.alert.tipoCambio, c);
    final sevColor = severityColorFrom(widget.alert.severidad, c);
    final hora = _hora(widget.alert.fechaEjecucion);
    final nombre = _nombre(widget.alert.rutaArchivo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 28,
          child: CustomPaint(
            painter: _VerticalLinePainter(color: c.border),
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
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _expanded ? c.itemBgExpanded : c.itemBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _expanded ? color.withOpacity(0.4) : c.itemBorder,
                  width: _expanded ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(children: [
                      _TipoBadge(tipo: widget.alert.tipoCambio, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre,
                                  style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                              if (widget.alert.rutaArchivo != null)
                                Text(widget.alert.rutaArchivo!,
                                    style: TextStyle(
                                        color: c.textSecondary, fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                            ]),
                      ),
                      const SizedBox(width: 8),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _SeveridadBadge(
                                severidad: widget.alert.severidad,
                                color: sevColor),
                            const SizedBox(height: 3),
                            Text(hora,
                                style: TextStyle(
                                    color: c.textDisabled, fontSize: 10)),
                          ]),
                      const SizedBox(width: 6),
                      Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: c.textDisabled),
                    ]),
                  ),
                  if (_expanded) _buildDetalle(c),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildDetalle(FimColors c) {
    final a = widget.alert;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _DetalleRow(label: 'ID Alerta', value: '#${a.id}', c: c),
          if (a.scanId != null)
            _DetalleRow(label: 'Scan ID', value: '#${a.scanId}', c: c),
          if (a.rutaArchivo != null)
            _DetalleRow(label: 'Ruta', value: a.rutaArchivo!, c: c),
          if (a.permisos != null)
            _DetalleRow(label: 'Permisos', value: a.permisos!, c: c),
          if (a.tamano != null)
            _DetalleRow(label: 'Tamaño', value: _size(a.tamano!), c: c),
          if (a.hashActual != null)
            _DetalleRow(
                label: 'Hash actual',
                value: a.hashActual!.length > 16
                    ? '${a.hashActual!.substring(0, 16)}…'
                    : a.hashActual!,
                mono: true,
                c: c),
          if (a.hashAnterior != null)
            _DetalleRow(
                label: 'Hash anterior',
                value: a.hashAnterior!.length > 16
                    ? '${a.hashAnterior!.substring(0, 16)}…'
                    : a.hashAnterior!,
                mono: true,
                c: c),
          if (a.fechaEjecucion != null)
            _DetalleRow(
                label: 'Fecha', value: _fechaCompleta(a.fechaEjecucion), c: c),
        ],
      ),
    );
  }

  String _hora(String? raw) {
    if (raw == null) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(raw));
    } catch (_) {
      return '';
    }
  }

  String _fechaCompleta(String? raw) {
    if (raw == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _nombre(String? ruta) {
    if (ruta == null || ruta.isEmpty) return 'Archivo desconocido';
    return ruta.split('/').last;
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

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
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_VerticalLinePainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS PEQUEÑOS
// ═══════════════════════════════════════════════════════════════════════════════

class _TipoBadge extends StatelessWidget {
  final String tipo;
  final Color color;
  const _TipoBadge({required this.tipo, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_icon(tipo), size: 11, color: color),
          const SizedBox(width: 4),
          Text(tipo,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ]),
      );

  IconData _icon(String t) => switch (t) {
        'NEW' => Icons.add_circle_outline,
        'DELETED' => Icons.remove_circle_outline,
        'MODIFIED' => Icons.edit_outlined,
        'PERMISSIONS' => Icons.lock_outline,
        _ => Icons.circle_outlined,
      };
}

class _SeveridadBadge extends StatelessWidget {
  final String severidad;
  final Color color;
  const _SeveridadBadge({required this.severidad, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(severidad,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );
}

class _DetalleRow extends StatelessWidget {
  final String label, value;
  final bool mono;
  final FimColors c;
  const _DetalleRow(
      {required this.label,
      required this.value,
      this.mono = false,
      required this.c});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(color: c.textSecondary, fontSize: 11))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 11,
                    fontFamily: mono ? 'monospace' : null)),
          ),
        ]),
      );
}

class _DateRangeButton extends StatelessWidget {
  final DateTimeRange? rango;
  final Color accent, border, textSecondary, surfaceCard;
  final VoidCallback onTap;
  const _DateRangeButton({
    required this.rango,
    required this.accent,
    required this.border,
    required this.textSecondary,
    required this.surfaceCard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = rango != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.15) : surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? accent.withOpacity(0.5) : border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.date_range,
              size: 16, color: active ? accent : textSecondary),
          const SizedBox(width: 6),
          Text(
            active
                ? '${DateFormat('dd/MM').format(rango!.start)} – ${DateFormat('dd/MM').format(rango!.end)}'
                : 'Fechas',
            style: TextStyle(
                color: active ? accent : textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ]),
      ),
    );
  }
}

class _DropdownFiltro extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final IconData icon;
  final Color Function(String) colorFn;
  final ValueChanged<String?> onChanged;

  const _DropdownFiltro({
    required this.hint,
    required this.value,
    required this.items,
    required this.icon,
    required this.colorFn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    final activeColor = value != null ? colorFn(value!) : null;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: value != null
            ? (activeColor?.withOpacity(0.12) ?? c.surfaceCard)
            : c.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: value != null
                ? (activeColor?.withOpacity(0.5) ?? c.border)
                : c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(children: [
            Icon(icon, size: 14, color: c.textSecondary),
            const SizedBox(width: 6),
            Text(hint, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ]),
          dropdownColor: c.surface,
          iconSize: 16,
          iconEnabledColor: activeColor ?? c.textSecondary,
          isExpanded: true,
          items: [
            DropdownMenuItem<String>(
                value: null,
                child: Text('Todos',
                    style: TextStyle(color: c.textSecondary, fontSize: 12))),
            ...items.map((item) {
              final col = colorFn(item);
              return DropdownMenuItem<String>(
                value: item,
                child: Row(children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: col, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(item,
                      style: TextStyle(
                          color: col,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              );
            }),
          ],
          onChanged: onChanged,
          selectedItemBuilder: (_) => [
            Text('Todos',
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ...items.map((item) {
              final col = colorFn(item);
              return Text(item,
                  style: TextStyle(
                      color: col, fontSize: 12, fontWeight: FontWeight.w600));
            }),
          ],
        ),
      ),
    );
  }
}
