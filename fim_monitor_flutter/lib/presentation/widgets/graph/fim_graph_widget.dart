// lib/presentation/widgets/graph/fim_graph_widget.dart
//
// CustomPainter puro — sin graphview ni BuchheimWalker.
//
// FIXES DE RENDIMIENTO v3:
//   • _DotsBgPainter usa RepaintBoundary + cache de imagen para no redibujar
//     2000+ círculos en cada frame del AnimatedBuilder.
//   • _ensureLayout() se llama SOLO desde el listener (una vez por cambio
//     de estructura), nunca desde builder. Elimina el doble-cómputo.
//   • onHover usa un timer de debounce (16ms) para no disparar setState
//     60 veces por segundo al mover el ratón.
//   • dispose() cancela el debounce timer para evitar llamadas a setState
//     sobre un widget desmontado (causa del crash al minimizar).
//
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/alert_model.dart';
import '../../blocs/graph/graph_bloc.dart';
import 'node_detail_panel.dart';
import 'graph_filter_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLORES DE SEVERIDAD
// ─────────────────────────────────────────────────────────────────────────────

Color _severityRingColor(String? sev) {
  switch (sev?.toUpperCase()) {
    case 'ALTA':
      return const Color(0xFFEF4444);
    case 'MEDIA':
      return const Color(0xFFF97316);
    case 'BAJA':
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF374151);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE LAYOUT
// ─────────────────────────────────────────────────────────────────────────────

class _GNode {
  final String path;
  Offset pos;
  _GNode(this.path, this.pos);
}

class _GEdge {
  final int from;
  final int to;
  _GEdge(this.from, this.to);
}

class _GraphLayout {
  final List<_GNode> nodes;
  final List<_GEdge> edges;
  final Size canvasSize;

  _GraphLayout(this.nodes, this.edges, this.canvasSize);

  static _GraphLayout build(Map<String, AlertModel> nodeMap) {
    const hSep = 110.0;
    const vSep = 100.0;
    const padX = 80.0;
    const padY = 70.0;

    final allPaths = <String>{'/'};
    for (final path in nodeMap.keys) {
      if (path.isEmpty) continue;
      final parts = path.split('/').where((p) => p.isNotEmpty).toList();
      String cur = '';
      for (final p in parts) {
        cur = '$cur/$p';
        allPaths.add(cur);
      }
    }

    final pathList = allPaths.toList()..sort();
    final index = <String, int>{};
    for (int i = 0; i < pathList.length; i++) index[pathList[i]] = i;

    final n = pathList.length;
    final children = List<List<int>>.generate(n, (_) => []);
    for (final path in pathList) {
      if (path == '/') continue;
      final parts = path.split('/').where((p) => p.isNotEmpty).toList();
      final parentPath = parts.length == 1
          ? '/'
          : '/${parts.sublist(0, parts.length - 1).join('/')}';
      if (index.containsKey(parentPath)) {
        final pi = index[parentPath]!;
        final ci = index[path]!;
        if (!children[pi].contains(ci)) children[pi].add(ci);
      }
    }

    final level = List<int>.filled(n, 0);
    final rootIdx = index['/']!;
    final queue = <int>[rootIdx];
    final visited = List<bool>.filled(n, false);
    visited[rootIdx] = true;
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final child in children[cur]) {
        if (!visited[child]) {
          visited[child] = true;
          level[child] = level[cur] + 1;
          queue.add(child);
        }
      }
    }

    final byLevel = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      byLevel.putIfAbsent(level[i], () => []).add(i);
    }

    final positions = List<Offset>.filled(n, Offset.zero);
    int maxLevel = 0, maxWidth = 0;
    for (final e in byLevel.entries) {
      if (e.key > maxLevel) maxLevel = e.key;
      if (e.value.length > maxWidth) maxWidth = e.value.length;
      final total = e.value.length;
      for (int i = 0; i < total; i++) {
        positions[e.value[i]] =
            Offset(i * hSep - (total - 1) * hSep / 2.0, e.key * vSep);
      }
    }

    double minX = positions.map((o) => o.dx).reduce(math.min);
    double minY = positions.map((o) => o.dy).reduce(math.min);
    for (int i = 0; i < n; i++) {
      positions[i] =
          Offset(positions[i].dx - minX + padX, positions[i].dy - minY + padY);
    }

    final w = (maxWidth * hSep + padX * 2).clamp(800.0, 12000.0);
    final h = (maxLevel * vSep + padY * 2 + 100).clamp(500.0, 8000.0);

    final nodes = List.generate(n, (i) => _GNode(pathList[i], positions[i]));
    final edges = <_GEdge>[];
    for (int pi = 0; pi < n; pi++) {
      for (final ci in children[pi]) edges.add(_GEdge(pi, ci));
    }
    return _GraphLayout(nodes, edges, Size(w, h));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FONDO DE PUNTOS
//
// FIX: ya NO usa AnimatedBuilder sobre TransformationController.
// El fondo es estático (desplazamiento con paralaje era el problema de perf).
// Se pinta una sola vez con RepaintBoundary + isComplex=true para que Flutter
// lo cachee en una textura de GPU y no lo recalcule en cada frame.
// ─────────────────────────────────────────────────────────────────────────────

class _StaticDotsBg extends StatelessWidget {
  const _StaticDotsBg();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        isComplex: true, // indica a Flutter que cachee en GPU
        painter: const _DotsBgPainter(),
      ),
    );
  }
}

class _DotsBgPainter extends CustomPainter {
  const _DotsBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const step = 28.0;
    const dotR = 1.1;
    final paint = Paint()..color = const Color(0xFF4B5563).withOpacity(0.35);

    final cols = (size.width / step).ceil() + 1;
    final rows = (size.height / step).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        canvas.drawCircle(
          Offset(col * step, row * step),
          dotR,
          paint,
        );
      }
    }
  }

  // Nunca necesita repintarse — el fondo es estático
  @override
  bool shouldRepaint(_DotsBgPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  final _GraphLayout layout;
  final Map<String, AlertModel> nodeMap;
  final Map<String, String?>? snapshotOverride;
  final String? filterTipo;
  final String? filterSeveridad;
  final String? searchQuery;
  final String? selectedPath;
  final String? hoveredPath;

  const _GraphPainter({
    required this.layout,
    required this.nodeMap,
    this.snapshotOverride,
    this.filterTipo,
    this.filterSeveridad,
    this.searchQuery,
    this.selectedPath,
    this.hoveredPath,
  });

  String _tipoFor(String path) {
    if (snapshotOverride != null) return snapshotOverride![path] ?? 'CLEAN';
    return nodeMap[path]?.tipoCambio ?? 'CLEAN';
  }

  String? _sevFor(String path) => nodeMap[path]?.severidad;
  Color _colorFor(String path) => eventColor(_tipoFor(path));

  bool _dimmed(String path) {
    final alert = nodeMap[path];
    if (filterTipo != null && alert != null) {
      if (alert.tipoCambio != filterTipo) return true;
    }
    if (filterSeveridad != null && alert != null) {
      if (alert.severidad.toUpperCase() != filterSeveridad!.toUpperCase()) {
        return true;
      }
    }
    final q = searchQuery?.toLowerCase();
    if (q != null && q.isNotEmpty) {
      if (!path.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  bool _isDir(String path) {
    if (path == '/') return true;
    final last = path.split('/').last;
    if (!last.contains('.')) return true;
    const fileExts = {
      'txt',
      'conf',
      'cfg',
      'log',
      'json',
      'xml',
      'yaml',
      'yml',
      'sh',
      'py',
      'dart',
      'java',
      'class',
      'so',
      'ko',
      'md',
      'toml',
      'ini',
      'env',
      'html',
      'css',
      'js',
      'ts',
    };
    return !fileExts.contains(last.split('.').last.toLowerCase());
  }

  void _drawFolderIcon(Canvas canvas, Offset center, Color color, double op) {
    const w = 14.0, h = 11.0;
    final left = center.dx - w / 2;
    final top = center.dy - h / 2;
    final paint = Paint()
      ..color = color.withOpacity(0.9 * op)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(left, top + 3)
      ..lineTo(left, top + h)
      ..lineTo(left + w, top + h)
      ..lineTo(left + w, top + 3)
      ..close();
    canvas.drawPath(body, paint);
    final tab = Path()
      ..moveTo(left, top + 3)
      ..lineTo(left + 4, top)
      ..lineTo(left + 7, top)
      ..lineTo(left + 7, top + 3);
    canvas.drawPath(tab, paint);
  }

  void _drawFileIcon(Canvas canvas, Offset center, Color color, double op) {
    const w = 11.0, h = 14.0;
    final left = center.dx - w / 2;
    final top = center.dy - h / 2;
    final paint = Paint()
      ..color = color.withOpacity(0.9 * op)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const fold = 3.5;
    final body = Path()
      ..moveTo(left, top)
      ..lineTo(left + w - fold, top)
      ..lineTo(left + w, top + fold)
      ..lineTo(left + w, top + h)
      ..lineTo(left, top + h)
      ..close();
    canvas.drawPath(body, paint);
    final corner = Path()
      ..moveTo(left + w - fold, top)
      ..lineTo(left + w - fold, top + fold)
      ..lineTo(left + w, top + fold);
    canvas.drawPath(corner, paint);
    final linePaint = Paint()
      ..color = color.withOpacity(0.6 * op)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left + 2, top + h * 0.55),
        Offset(left + w - 2, top + h * 0.55), linePaint);
    canvas.drawLine(Offset(left + 2, top + h * 0.73),
        Offset(left + w - 2, top + h * 0.73), linePaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in layout.edges) {
      final dimA = _dimmed(layout.nodes[e.from].path);
      final dimB = _dimmed(layout.nodes[e.to].path);
      final dim = dimA && dimB;
      canvas.drawLine(
        layout.nodes[e.from].pos,
        layout.nodes[e.to].pos,
        Paint()
          ..color = AppColors.border.withOpacity(dim ? 0.08 : 0.45)
          ..strokeWidth = dim ? 0.5 : 1.0
          ..style = PaintingStyle.stroke,
      );
    }

    for (final node in layout.nodes) {
      final path = node.path;
      final color = _colorFor(path);
      final sev = _sevFor(path);
      final ringColor = _severityRingColor(sev);
      final dim = _dimmed(path);
      final selected = path == selectedPath;
      final hovered = path == hoveredPath;
      final isDir = _isDir(path);
      final radius = isDir ? 20.0 : 16.0;
      final op = dim ? 0.12 : 1.0;

      if (selected || hovered) {
        canvas.drawCircle(
          node.pos,
          radius + 9,
          Paint()
            ..color = color.withOpacity(selected ? 0.25 : 0.12)
            ..style = PaintingStyle.fill,
        );
      }

      if (sev != null && !dim) {
        canvas.drawCircle(
          node.pos,
          radius + 5,
          Paint()
            ..color = ringColor.withOpacity(0.9)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke,
        );
      }

      canvas.drawCircle(
        node.pos,
        radius + 2,
        Paint()
          ..color = const Color(0xFF111827).withOpacity(dim ? 0.0 : 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      canvas.drawCircle(
        node.pos,
        radius,
        Paint()
          ..color = color.withOpacity(0.13 * op)
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        node.pos,
        radius,
        Paint()
          ..color = color.withOpacity(op)
          ..strokeWidth = selected ? 2.5 : 1.8
          ..style = PaintingStyle.stroke,
      );

      if (isDir) {
        _drawFolderIcon(canvas, node.pos, color, op);
      } else {
        _drawFileIcon(canvas, node.pos, color, op);
      }

      final label = path == '/' ? '/' : path.split('/').last;
      final labelColor = selected
          ? color.withOpacity(op)
          : AppColors.textSecondary.withOpacity(dim ? 0.2 : 0.9);

      _paintLabel(
        canvas,
        label,
        Offset(node.pos.dx, node.pos.dy + radius + (sev != null ? 9 : 7)),
        color: labelColor,
        bold: selected,
      );
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset topCenter,
      {required Color color, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11.0,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          fontFamily: 'monospace',
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 96);
    tp.paint(canvas, topCenter - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      !identical(old.nodeMap, nodeMap) ||
      old.snapshotOverride != snapshotOverride ||
      old.filterTipo != filterTipo ||
      old.filterSeveridad != filterSeveridad ||
      old.searchQuery != searchQuery ||
      old.selectedPath != selectedPath ||
      old.hoveredPath != hoveredPath;
}

class _TransformedPainter extends CustomPainter {
  final Matrix4 transform;
  final _GraphPainter inner;
  _TransformedPainter({required this.transform, required this.inner});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);
    inner.paint(canvas, inner.layout.canvasSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TransformedPainter old) =>
      old.transform != transform || inner.shouldRepaint(old.inner);
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class FimGraphWidget extends StatefulWidget {
  const FimGraphWidget({super.key});
  @override
  State<FimGraphWidget> createState() => _FimGraphWidgetState();
}

class _FimGraphWidgetState extends State<FimGraphWidget> {
  _GraphLayout? _layout;
  String _lastStructureKey = '';

  final TransformationController _transformCtrl = TransformationController();
  String? _hoveredPath;

  // FIX: debounce del hover para no llamar setState 60fps al mover el ratón.
  Timer? _hoverDebounce;

  @override
  void dispose() {
    // FIX: cancelar timer antes de dispose para evitar setState en widget muerto.
    _hoverDebounce?.cancel();
    _transformCtrl.dispose();
    super.dispose();
  }

  // FIX: layout se calcula SOLO desde el listener, nunca desde builder.
  // Esto evita el doble-cómputo cuando el BLoC emite dos estados seguidos.
  void _ensureLayout(Map<String, AlertModel> nodeMap) {
    final key = (nodeMap.keys.toList()..sort()).join('|');
    if (key == _lastStructureKey && _layout != null) return;
    _lastStructureKey = key;
    _layout = _GraphLayout.build(nodeMap);
  }

  double _currentScale() {
    final s = _transformCtrl.value.storage;
    return math.sqrt(s[0] * s[0] + s[1] * s[1]);
  }

  void _applyScaleAt(double scale, Offset? focal) {
    final newScale = _currentScale() * scale;
    if (newScale < 0.12 || newScale > 3.5) return;
    final m = _transformCtrl.value.clone();
    if (focal != null) {
      m
        ..translate(focal.dx, focal.dy)
        ..scale(scale, scale)
        ..translate(-focal.dx, -focal.dy);
    } else {
      m.scale(scale, scale);
    }
    _transformCtrl.value = m;
  }

  void _resetZoom() =>
      _transformCtrl.value = Matrix4.identity()..translate(20.0, 20.0);
  void _zoomIn() => _applyScaleAt(1.2, null);
  void _zoomOut() => _applyScaleAt(1 / 1.2, null);

  Offset _toCanvas(Offset screen) {
    final s = _transformCtrl.value.storage;
    return Offset((screen.dx - s[12]) / s[0], (screen.dy - s[13]) / s[5]);
  }

  String? _hitTest(Offset cp) {
    if (_layout == null) return null;
    String? best;
    double bestDist = double.infinity;
    for (final node in _layout!.nodes) {
      final hitR = (node.path == '/' ? 20.0 : 16.0) + 12.0;
      final d = (node.pos - cp).distance;
      if (d <= hitR && d < bestDist) {
        bestDist = d;
        best = node.path;
      }
    }
    return best;
  }

  // FIX: debounce del hover — agrupa eventos de ratón en ventanas de 16ms
  // para no llamar setState en cada píxel de movimiento.
  void _onHover(PointerHoverEvent e) {
    _hoverDebounce?.cancel();
    _hoverDebounce = Timer(const Duration(milliseconds: 16), () {
      if (!mounted) return; // FIX: guard contra widget desmontado
      final hit = _hitTest(_toCanvas(e.localPosition));
      if (hit != _hoveredPath) {
        setState(() => _hoveredPath = hit);
      }
    });
  }

  void _onMouseExit(PointerExitEvent _) {
    _hoverDebounce?.cancel();
    if (_hoveredPath != null && mounted) {
      setState(() => _hoveredPath = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GraphBloc, GraphState>(
      listenWhen: (p, c) {
        if (p is GraphLoaded && c is GraphLoaded) return p.nodeMap != c.nodeMap;
        return c is GraphLoaded;
      },
      // FIX: _ensureLayout SOLO en el listener — nunca en builder.
      listener: (_, state) {
        if (state is GraphLoaded) {
          _ensureLayout(state.nodeMap);
          // Forzar rebuild solo si el layout cambió (setState protegido por _ensureLayout)
          if (mounted) setState(() {});
        }
      },
      buildWhen: (p, c) =>
          c is! GraphLoaded ||
          p is! GraphLoaded ||
          p.nodeMap != c.nodeMap ||
          p.selectedRuta != c.selectedRuta ||
          p.filterTipo != c.filterTipo ||
          p.filterSeveridad != c.filterSeveridad ||
          p.searchQuery != c.searchQuery ||
          p.snapshotOverride != c.snapshotOverride,
      builder: (context, state) => switch (state) {
        GraphInitial() || GraphLoading() => const _LoadingView(),
        GraphError(:final message) => _ErrorView(message: message),
        GraphLoaded() => _buildLoaded(context, state as GraphLoaded),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildLoaded(BuildContext context, GraphLoaded state) {
    // FIX: NO llamar _ensureLayout aquí. Si _layout es null en este punto
    // (primera carga), mostramos loading hasta que el listener lo calcule.
    if (_layout == null) return const _LoadingView();
    final layout = _layout!;

    return Column(
      children: [
        if (state.snapshotOverride != null)
          _SnapshotBanner(
            onLive: () =>
                context.read<GraphBloc>().add(const GraphSnapshotApplied(null)),
          ),
        GraphFilterBar(
          selected: state.filterTipo,
          selectedSeveridad: state.filterSeveridad,
          searchQuery: state.searchQuery,
          onFilter: (tipo) => context.read<GraphBloc>().add(GraphFilterChanged(
              tipo: tipo,
              severidad: state.filterSeveridad,
              searchQuery: state.searchQuery)),
          onSeveridadFilter: (sev) => context.read<GraphBloc>().add(
              GraphFilterChanged(
                  tipo: state.filterTipo,
                  severidad: sev,
                  searchQuery: state.searchQuery)),
          onSearch: (q) => context.read<GraphBloc>().add(GraphFilterChanged(
              tipo: state.filterTipo,
              severidad: state.filterSeveridad,
              searchQuery: q)),
        ),
        Expanded(
          child: Stack(
            children: [
              // FIX: fondo estático cacheado en GPU — no se repinta nunca.
              const _StaticDotsBg(),

              // Grafo
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _applyScaleAt(event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1,
                        event.localPosition);
                  }
                },
                child: GestureDetector(
                  onPanUpdate: (d) {
                    _transformCtrl.value = _transformCtrl.value.clone()
                      ..translate(d.delta.dx, d.delta.dy);
                  },
                  onTapUp: (d) {
                    final hit = _hitTest(_toCanvas(d.localPosition));
                    if (hit != null) {
                      context.read<GraphBloc>().add(GraphNodeSelected(hit));
                    }
                  },
                  child: MouseRegion(
                    cursor: _hoveredPath != null
                        ? SystemMouseCursors.click
                        : MouseCursor.defer,
                    // FIX: usar onHover con debounce en lugar de setState directo
                    onHover: _onHover,
                    onExit: _onMouseExit,
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: _transformCtrl,
                        builder: (_, __) => CustomPaint(
                          size: Size.infinite,
                          painter: _TransformedPainter(
                            transform: _transformCtrl.value,
                            inner: _GraphPainter(
                              layout: layout,
                              nodeMap: state.nodeMap,
                              snapshotOverride: state.snapshotOverride,
                              filterTipo: state.filterTipo,
                              filterSeveridad: state.filterSeveridad,
                              searchQuery: state.searchQuery,
                              selectedPath: state.selectedRuta,
                              hoveredPath: _hoveredPath,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 12,
                bottom: 12,
                child: const _SeverityLegend(),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _ZoomControls(
                    onReset: _resetZoom,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut),
              ),
              if (_hoveredPath != null)
                Positioned(
                    left: 12,
                    top: 12,
                    child: _PathTooltip(
                      path: _hoveredPath!,
                      sev: state.nodeMap[_hoveredPath]?.severidad,
                    )),
            ],
          ),
        ),
        if (state.selectedRuta != null)
          NodeDetailPanel(
            alert: state.nodeMap[state.selectedRuta] ??
                AlertModel(
                    id: -1,
                    tipoCambio: 'CLEAN',
                    severidad: 'BAJA',
                    rutaArchivo: state.selectedRuta),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES — sin cambios respecto a v2
// ─────────────────────────────────────────────────────────────────────────────

class _SeverityLegend extends StatelessWidget {
  const _SeverityLegend();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Severidad',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 5),
          _LegendRow(color: const Color(0xFFEF4444), label: 'ALTA'),
          const SizedBox(height: 3),
          _LegendRow(color: const Color(0xFFF97316), label: 'MEDIA'),
          const SizedBox(height: 3),
          _LegendRow(color: const Color(0xFF6B7280), label: 'BAJA'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _SnapshotBanner extends StatelessWidget {
  final VoidCallback onLive;
  const _SnapshotBanner({required this.onLive});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: const Color(0xFF00D4FF).withOpacity(0.08),
        child: Row(children: [
          const Icon(Icons.history, size: 14, color: Color(0xFF00D4FF)),
          const SizedBox(width: 8),
          const Text('Viendo estado histórico — el grafo muestra el pasado',
              style: TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          GestureDetector(
            onTap: onLive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF00D4FF).withOpacity(0.4)),
              ),
              child: const Text('Volver a EN VIVO',
                  style: TextStyle(
                      color: Color(0xFF00D4FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );
}

class _PathTooltip extends StatelessWidget {
  final String path;
  final String? sev;
  const _PathTooltip({required this.path, this.sev});
  @override
  Widget build(BuildContext context) {
    final sevColor = _severityRingColor(sev);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(path,
              style: AppTextStyles.path
                  .copyWith(color: AppColors.textPrimary, fontSize: 11)),
          if (sev != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: sevColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: sevColor.withOpacity(0.4)),
              ),
              child: Text(sev!,
                  style: TextStyle(
                      color: sevColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  final VoidCallback onReset, onZoomIn, onZoomOut;
  const _ZoomControls(
      {required this.onReset, required this.onZoomIn, required this.onZoomOut});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _ZBtn(icon: Icons.add, onTap: onZoomIn),
          Divider(height: 1, color: AppColors.border),
          _ZBtn(icon: Icons.remove, onTap: onZoomOut),
          Divider(height: 1, color: AppColors.border),
          _ZBtn(icon: Icons.center_focus_strong_outlined, onTap: onReset),
        ]),
      );
}

class _ZBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 16, color: AppColors.textSecondary)),
      );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
      child:
          CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline,
              color: AppColors.eventDeleted, size: 32),
          const SizedBox(height: 12),
          Text(message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                context.read<GraphBloc>().add(const GraphLoadRequested()),
            child:
                Text('Reintentar', style: TextStyle(color: AppColors.primary)),
          ),
        ]),
      );
}
