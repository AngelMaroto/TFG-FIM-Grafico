// lib/presentation/widgets/graph/fim_graph_widget.dart
//
// FIX DE MEMORIA v5 — ciclo de vida + Visibility
//
//   PROBLEMA: AnimatedBuilder sobre TransformationController redibujaba el
//   grafo completo (CustomPainter) en cada frame del motor de Flutter incluso
//   con la app minimizada → CPU al 17% constante.
//
//   SOLUCIÓN:
//   • WidgetsBindingObserver en _FimGraphWidgetState — cuando la app va a
//     background se desactiva el AnimatedBuilder envolviéndolo en
//     Visibility(visible: false). Esto hace que Flutter no llame a paint()
//     ni a shouldRepaint() hasta que la app vuelva a foreground.
//   • El TransformationController sigue existiendo (mantiene zoom/posición)
//     pero no dispara rebuilds mientras está invisible.
//   • _StaticDotsBg con RepaintBoundary ya cacheada en GPU — sin cambios.
//
// MEJORAS VISUALES v6 (Estética Cyberpunk):
//   • Líneas de conexión con gradiente direccional (flujo).
//   • Glow (brillo acelerado por hardware) para nodos de ALTA severidad.
//   • MiniMapa (Glassmorphism) para visión global.
//
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui; // <-- Necesario para ImageFilter, Gradient, etc.
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/alert_model.dart';
import '../../blocs/graph/graph_bloc.dart';
import 'node_detail_panel.dart';
import 'graph_filter_bar.dart';
import '../../pages/settings_page.dart' show GraphVisualizationPrefs;

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE LAYOUT
// ─────────────────────────────────────────────────────────────────────────────

class _GNode {
  final String path;
  Offset pos;
  _GNode(this.path, this.pos);
}

class _GEdge {
  final int from, to;
  _GEdge(this.from, this.to);
}

class _GraphLayout {
  final List<_GNode> nodes;
  final List<_GEdge> edges;
  final Size canvasSize;
  _GraphLayout(this.nodes, this.edges, this.canvasSize);

  static _GraphLayout build(Map<String, AlertModel> nodeMap,
      {bool showOnlyChanged = false}) {
    const hSep = 110.0, vSep = 100.0, padX = 80.0, padY = 70.0;

    final filteredKeys = showOnlyChanged
        ? nodeMap.keys
            .where((k) =>
                (nodeMap[k]?.tipoCambio ?? 'CLEAN').toUpperCase() != 'CLEAN')
            .toSet()
        : nodeMap.keys.toSet();

    final allPaths = <String>{'/'};
    for (final path in filteredKeys) {
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
// ─────────────────────────────────────────────────────────────────────────────

class _StaticDotsBg extends StatelessWidget {
  const _StaticDotsBg();
  @override
  Widget build(BuildContext context) {
    final dotColor = context.fimColors.dotsBg.withOpacity(0.35);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        isComplex: true,
        painter: _DotsBgPainter(dotColor: dotColor),
      ),
    );
  }
}

class _DotsBgPainter extends CustomPainter {
  final Color dotColor;
  const _DotsBgPainter({required this.dotColor});
  @override
  void paint(Canvas canvas, Size size) {
    const step = 28.0, dotR = 1.1;
    final paint = Paint()..color = dotColor;
    final cols = (size.width / step).ceil() + 1;
    final rows = (size.height / step).ceil() + 1;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        canvas.drawCircle(Offset(col * step, row * step), dotR, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsBgPainter old) => old.dotColor != dotColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  final _GraphLayout layout;
  final Map<String, AlertModel> nodeMap;
  final Map<String, String?>? snapshotOverride;
  final String? filterTipo,
      filterSeveridad,
      searchQuery,
      selectedPath,
      hoveredPath;
  final bool showNodeLabels;
  final FimColors colors;

  const _GraphPainter({
    required this.layout,
    required this.nodeMap,
    required this.colors,
    this.snapshotOverride,
    this.filterTipo,
    this.filterSeveridad,
    this.searchQuery,
    this.selectedPath,
    this.hoveredPath,
    this.showNodeLabels = true,
  });

  String _tipoFor(String path) {
    if (snapshotOverride != null) return snapshotOverride![path] ?? 'CLEAN';
    return nodeMap[path]?.tipoCambio ?? 'CLEAN';
  }

  String? _sevFor(String path) => nodeMap[path]?.severidad;
  Color _colorFor(String path) => eventColorFrom(_tipoFor(path), colors);
  Color _ringColor(String? sev) {
    switch (sev?.toUpperCase()) {
      case 'ALTA':
      case 'CRITICA':
        return colors.severityHigh;
      case 'MEDIA':
        return colors.severityMedium;
      case 'BAJA':
        return colors.severityLow;
      default:
        return colors.border;
    }
  }

  bool _dimmed(String path) {
    final a = nodeMap[path];
    if (filterTipo != null && a != null && a.tipoCambio != filterTipo)
      return true;
    if (filterSeveridad != null &&
        a != null &&
        a.severidad.toUpperCase() != filterSeveridad!.toUpperCase())
      return true;
    final q = searchQuery?.toLowerCase();
    if (q != null && q.isNotEmpty && !path.toLowerCase().contains(q))
      return true;
    return false;
  }

  bool _isDir(String path) {
    if (path == '/') return true;
    final last = path.split('/').last;
    if (!last.contains('.')) return true;
    const exts = {
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
      'ts'
    };
    return !exts.contains(last.split('.').last.toLowerCase());
  }

  void _drawFolderIcon(Canvas c, Offset center, Color color, double op) {
    const w = 14.0, h = 11.0;
    final l = center.dx - w / 2, t = center.dy - h / 2;
    final p = Paint()
      ..color = color.withOpacity(0.9 * op)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
        Path()
          ..moveTo(l, t + 3)
          ..lineTo(l, t + h)
          ..lineTo(l + w, t + h)
          ..lineTo(l + w, t + 3)
          ..close(),
        p);
    c.drawPath(
        Path()
          ..moveTo(l, t + 3)
          ..lineTo(l + 4, t)
          ..lineTo(l + 7, t)
          ..lineTo(l + 7, t + 3),
        p);
  }

  void _drawFileIcon(Canvas c, Offset center, Color color, double op) {
    const w = 11.0, h = 14.0, fold = 3.5;
    final l = center.dx - w / 2, t = center.dy - h / 2;
    final p = Paint()
      ..color = color.withOpacity(0.9 * op)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
        Path()
          ..moveTo(l, t)
          ..lineTo(l + w - fold, t)
          ..lineTo(l + w, t + fold)
          ..lineTo(l + w, t + h)
          ..lineTo(l, t + h)
          ..close(),
        p);
    c.drawPath(
        Path()
          ..moveTo(l + w - fold, t)
          ..lineTo(l + w - fold, t + fold)
          ..lineTo(l + w, t + fold),
        p);
    final lp = Paint()
      ..color = color.withOpacity(0.6 * op)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    c.drawLine(
        Offset(l + 2, t + h * 0.55), Offset(l + w - 2, t + h * 0.55), lp);
    c.drawLine(
        Offset(l + 2, t + h * 0.73), Offset(l + w - 2, t + h * 0.73), lp);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Detectamos si el fondo es claro para aumentar el contraste de las opacidades
    final isLight = colors.background.computeLuminance() > 0.5;

    // 1. DIBUJAR LÍNEAS CON GRADIENTE DIRECCIONAL
    for (final e in layout.edges) {
      final dim = _dimmed(layout.nodes[e.from].path) &&
          _dimmed(layout.nodes[e.to].path);

      final p1 = layout.nodes[e.from].pos;
      final p2 = layout.nodes[e.to].pos;

      final colorHijo = _colorFor(layout.nodes[e.to].path);

      // En modo claro subimos la opacidad base de 0.15 a 0.4, y la final a 0.8
      final baseLineOp = isLight ? 0.4 : 0.15;
      final endLineOp = isLight ? 0.8 : 0.5;

      final gradient = ui.Gradient.linear(
        p1,
        p2,
        [
          colors.border.withOpacity(dim ? 0.05 : baseLineOp),
          colorHijo.withOpacity(dim ? 0.05 : endLineOp),
        ],
      );

      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..shader = gradient
            ..strokeWidth = dim
                ? 0.5
                : (isLight ? 2.0 : 1.5) // Un poco más gruesas en blanco
            ..style = PaintingStyle.stroke);
    }

    // 2. DIBUJAR NODOS Y GLOW
    for (final node in layout.nodes) {
      final path = node.path;
      final color = _colorFor(path);
      final sev = _sevFor(path);
      final ring = _ringColor(sev);
      final dim = _dimmed(path);
      final selected = path == selectedPath;
      final hovered = path == hoveredPath;
      final isDir = _isDir(path);
      final radius = isDir ? 20.0 : 16.0;
      final op = dim ? 0.12 : 1.0;

      // --- EFECTO GLOW (Más intenso en modo claro) ---
      if (sev != null &&
          (sev.toUpperCase() == 'ALTA' || sev.toUpperCase() == 'CRITICA') &&
          !dim) {
        final glowOp =
            isLight ? 0.75 : 0.5; // Subimos de 0.5 a 0.75 en light mode
        final glowPaint = Paint()
          ..shader = ui.Gradient.radial(
            node.pos,
            radius * 2.8,
            [ring.withOpacity(glowOp), ring.withOpacity(0.0)],
          );
        canvas.drawCircle(node.pos, radius * 2.8, glowPaint);
      }

      // Resto del código de pintado de nodos...
      // (Aquí te recomiendo subir ligeramente la opacidad del relleno del círculo)
      final fillOp = isLight ? 0.35 : 0.13;

      if (selected || hovered) {
        canvas.drawCircle(
            node.pos,
            radius + 9,
            Paint()
              ..color = color.withOpacity(selected ? 0.25 : 0.12)
              ..style = PaintingStyle.fill);
      }
      if (sev != null && !dim) {
        canvas.drawCircle(
            node.pos,
            radius + 5,
            Paint()
              ..color = ring.withOpacity(isLight ? 1.0 : 0.9)
              ..strokeWidth = isLight ? 3.0 : 2.5
              ..style = PaintingStyle.stroke);
      }

      // 🟢 EL TRUCO ESTÁ AQUÍ: Fondo interno blanco puro en modo claro
      // Esto actúa como un "foco" detrás del color para que no se mezcle con el gris del fondo
      final baseNodeColor = isLight ? Colors.white : colors.background;
      canvas.drawCircle(
          node.pos,
          radius + 2,
          Paint()
            ..color = baseNodeColor.withOpacity(dim ? 0.0 : 1.0)
            ..style = PaintingStyle.fill);

      // Anillo base
      canvas.drawCircle(
          node.pos,
          radius + 2,
          Paint()
            ..color = colors.background.withOpacity(dim ? 0.0 : 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);

      // Relleno de color del nodo (ahora brillará sobre el fondo blanco)
      canvas.drawCircle(
          node.pos,
          radius,
          Paint()
            ..color = color.withOpacity(fillOp * op)
            ..style = PaintingStyle.fill);

      // Borde del nodo (más grueso e intenso en modo claro)
      canvas.drawCircle(
          node.pos,
          radius,
          Paint()
            ..color = color.withOpacity(op)
            ..strokeWidth = selected ? 2.5 : (isLight ? 2.5 : 1.8)
            ..style = PaintingStyle.stroke);

      isDir
          ? _drawFolderIcon(canvas, node.pos, color, op)
          : _drawFileIcon(canvas, node.pos, color, op);
      if (showNodeLabels) {
        final label = path == '/' ? '/' : path.split('/').last;
        final lc = selected
            ? color.withOpacity(op)
            : colors.textSecondary.withOpacity(dim ? 0.2 : 0.9);
        _paintLabel(canvas, label,
            Offset(node.pos.dx, node.pos.dy + radius + (sev != null ? 9 : 7)),
            color: lc, bold: selected);
      }
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
              letterSpacing: 0.2)),
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
      old.hoveredPath != hoveredPath ||
      old.showNodeLabels != showNodeLabels ||
      old.colors != colors;
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

class _FimGraphWidgetState extends State<FimGraphWidget>
    with WidgetsBindingObserver {
  _GraphLayout? _layout;
  String _lastStructureKey = '';

  final TransformationController _transformCtrl = TransformationController();
  String? _hoveredPath;
  Timer? _hoverDebounce;

  bool _showOnlyChanged = false;
  bool _showNodeLabels = true;

  // FIX: cuando la app va a background, ocultar el AnimatedBuilder
  // para que Flutter no llame a paint() en cada frame.
  bool _appInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVisualizationPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hoverDebounce?.cancel();
    _transformCtrl.dispose();
    super.dispose();
  }

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inFg = state == AppLifecycleState.resumed;
    if (inFg != _appInForeground) {
      setState(() => _appInForeground = inFg);
    }
  }

  // ── Prefs de visualización ────────────────────────────────────────────────

  Future<void> _loadVisualizationPrefs() async {
    final prefs = await GraphVisualizationPrefs.load();
    if (!mounted) return;
    setState(() {
      _showOnlyChanged = prefs.showOnlyChanged;
      _showNodeLabels = prefs.showNodeLabels;
    });
    final s = context.read<GraphBloc>().state;
    if (s is GraphLoaded) _ensureLayout(s.nodeMap, force: true);
  }

  void _ensureLayout(Map<String, AlertModel> nodeMap, {bool force = false}) {
    final key = (nodeMap.keys.toList()..sort()).join('|') +
        (_showOnlyChanged ? ':oc' : '');
    if (key == _lastStructureKey && _layout != null && !force) return;
    _lastStructureKey = key;
    _layout = _GraphLayout.build(nodeMap, showOnlyChanged: _showOnlyChanged);
  }

  double _currentScale() {
    final s = _transformCtrl.value.storage;
    return math.sqrt(s[0] * s[0] + s[1] * s[1]);
  }

  void _applyScaleAt(double scale, Offset? focal) {
    final ns = _currentScale() * scale;
    if (ns < 0.12 || ns > 3.5) return;
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

  void _onHover(PointerHoverEvent e) {
    _hoverDebounce?.cancel();
    _hoverDebounce = Timer(const Duration(milliseconds: 16), () {
      if (!mounted) return;
      final hit = _hitTest(_toCanvas(e.localPosition));
      if (hit != _hoveredPath) setState(() => _hoveredPath = hit);
    });
  }

  void _onMouseExit(PointerExitEvent _) {
    _hoverDebounce?.cancel();
    if (_hoveredPath != null && mounted) setState(() => _hoveredPath = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GraphBloc, GraphState>(
      listenWhen: (p, c) {
        if (p is GraphLoaded && c is GraphLoaded) return p.nodeMap != c.nodeMap;
        return c is GraphLoaded;
      },
      listener: (_, state) {
        if (state is GraphLoaded) {
          _ensureLayout(state.nodeMap);
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
    if (_layout == null) return const _LoadingView();
    final layout = _layout!;
    final c = context.fimColors;

    return Column(children: [
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
        child: LayoutBuilder(// <-- NUEVO: LayoutBuilder para el minimapa
            builder: (context, constraints) {
          return Stack(children: [
            const _StaticDotsBg(),
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
                  if (hit != null)
                    context.read<GraphBloc>().add(GraphNodeSelected(hit));
                },
                child: MouseRegion(
                  cursor: _hoveredPath != null
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  onHover: _onHover,
                  onExit: _onMouseExit,
                  child: ClipRect(
                    child: Visibility(
                      visible: _appInForeground,
                      maintainState: true,
                      maintainSize:
                          false, // <-- Fijado para evitar el error de aserción
                      maintainAnimation: false,
                      child: AnimatedBuilder(
                        animation: _transformCtrl,
                        builder: (_, __) => CustomPaint(
                          size: Size.infinite,
                          painter: _TransformedPainter(
                            transform: _transformCtrl.value,
                            inner: _GraphPainter(
                              layout: layout,
                              nodeMap: state.nodeMap,
                              colors: c,
                              snapshotOverride: state.snapshotOverride,
                              filterTipo: state.filterTipo,
                              filterSeveridad: state.filterSeveridad,
                              searchQuery: state.searchQuery,
                              selectedPath: state.selectedRuta,
                              hoveredPath: _hoveredPath,
                              showNodeLabels: _showNodeLabels,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(left: 12, bottom: 12, child: const _SeverityLegend()),
            Positioned(
                right: 12,
                bottom: 12,
                child: _ZoomControls(
                    onReset: _resetZoom,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut)),

            // --- NUEVO: MINIMAPA (Glassmorphism UI) ---
            Positioned(
              top: 12,
              right: 12,
              child: _MiniMap(
                layout: layout,
                transformCtrl: _transformCtrl,
                colors: c,
                viewportSize: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
            // -----------------------------------------

            if (_hoveredPath != null)
              Positioned(
                  left: 12,
                  top: 12,
                  child: _PathTooltip(
                      path: _hoveredPath!,
                      sev: state.nodeMap[_hoveredPath!]?.severidad)),
          ]);
        }),
      ),
      if (state.selectedRuta != null)
        RepaintBoundary(
          child: NodeDetailPanel(
            alert: state.nodeMap[state.selectedRuta] ??
                AlertModel(
                    id: -1,
                    tipoCambio: 'CLEAN',
                    severidad: 'BAJA',
                    rutaArchivo: state.selectedRuta),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _SeverityLegend extends StatelessWidget {
  const _SeverityLegend();
  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: c.surface.withOpacity(0.9),
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Severidad',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 5),
            _LegendRow(color: c.severityHigh, label: 'ALTA'),
            const SizedBox(height: 3),
            _LegendRow(color: c.severityMedium, label: 'MEDIA'),
            const SizedBox(height: 3),
            _LegendRow(color: c.severityLow, label: 'BAJA'),
          ]),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5))),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: context.fimColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ]);
}

class _SnapshotBanner extends StatelessWidget {
  final VoidCallback onLive;
  const _SnapshotBanner({required this.onLive});
  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: c.accent.withOpacity(0.08),
      child: Row(children: [
        Icon(Icons.history, size: 14, color: c.accent),
        const SizedBox(width: 8),
        Text('Viendo estado histórico — el grafo muestra el pasado',
            style: TextStyle(
                color: c.accent, fontSize: 11, fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
            onTap: onLive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: c.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.accent.withOpacity(0.4))),
              child: Text('Volver a EN VIVO',
                  style: TextStyle(
                      color: c.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            )),
      ]),
    );
  }
}

class _PathTooltip extends StatelessWidget {
  final String path;
  final String? sev;
  const _PathTooltip({required this.path, this.sev});
  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    final sc = sev != null ? severityColorFrom(sev!, c) : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(path,
            style: AppTextStyles.path
                .copyWith(color: c.textPrimary, fontSize: 11)),
        if (sc != null) ...[
          const SizedBox(width: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: sc.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sc.withOpacity(0.4))),
              child: Text(sev!,
                  style: TextStyle(
                      color: sc,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3))),
        ],
      ]),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  final VoidCallback onReset, onZoomIn, onZoomOut;
  const _ZoomControls(
      {required this.onReset, required this.onZoomIn, required this.onZoomOut});
  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Container(
      decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _ZBtn(icon: Icons.add, onTap: onZoomIn),
        Divider(height: 1, color: c.border),
        _ZBtn(icon: Icons.remove, onTap: onZoomOut),
        Divider(height: 1, color: c.border),
        _ZBtn(icon: Icons.center_focus_strong_outlined, onTap: onReset),
      ]),
    );
  }
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
          child: Icon(icon, size: 16, color: context.fimColors.textSecondary)));
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => Center(
      child: CircularProgressIndicator(
          strokeWidth: 2, color: context.fimColors.primary));
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, color: c.eventDeleted, size: 32),
      const SizedBox(height: 12),
      Text(message,
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
      const SizedBox(height: 16),
      TextButton(
        onPressed: () =>
            context.read<GraphBloc>().add(const GraphLoadRequested()),
        child: Text('Reintentar', style: TextStyle(color: c.primary)),
      ),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINIMAPA (UI y Lógica)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniMap extends StatelessWidget {
  final _GraphLayout layout;
  final TransformationController transformCtrl;
  final FimColors colors;
  final Size viewportSize;

  const _MiniMap({
    required this.layout,
    required this.transformCtrl,
    required this.colors,
    required this.viewportSize,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        // Efecto cristal esmerilado que desenfoca el fondo
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 200,
          height: 140,
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.6),
            border: Border.all(color: colors.border.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedBuilder(
            // Solo se redibuja cuando te mueves o haces zoom
            animation: transformCtrl,
            builder: (context, _) => CustomPaint(
              painter: _MiniMapPainter(
                layout: layout,
                transform: transformCtrl.value,
                colors: colors,
                viewportSize: viewportSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final _GraphLayout layout;
  final Matrix4 transform;
  final FimColors colors;
  final Size viewportSize;

  _MiniMapPainter({
    required this.layout,
    required this.transform,
    required this.colors,
    required this.viewportSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.canvasSize.width == 0 || layout.canvasSize.height == 0) return;

    // Calcular escala para que el grafo gigante quepa en el minimapa (con algo de margen)
    final scaleX = size.width / layout.canvasSize.width;
    final scaleY = size.height / layout.canvasSize.height;
    final scale = math.min(scaleX, scaleY) * 0.85;

    final offsetX = (size.width - layout.canvasSize.width * scale) / 2;
    final offsetY = (size.height - layout.canvasSize.height * scale) / 2;

    final isLight = colors.surface.computeLuminance() > 0.5;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    // 1. Dibujar estructura básica muy ligera
    final edgePaint = Paint()
      ..color = colors.textSecondary
          .withOpacity(isLight ? 0.4 : 0.15) // Más oscuro en light mode
      ..strokeWidth = 3.0 / scale
      ..style = PaintingStyle.stroke;

    for (final e in layout.edges) {
      canvas.drawLine(
          layout.nodes[e.from].pos, layout.nodes[e.to].pos, edgePaint);
    }

    final nodePaint = Paint()
      ..color = colors.textSecondary.withOpacity(isLight ? 0.8 : 0.5);
    for (final node in layout.nodes) {
      canvas.drawCircle(node.pos, 35.0, nodePaint);
    }
    canvas.restore();

    // 2. Dibujar el Viewport (el rectángulo que indica dónde está mirando el usuario)
    final inv = Matrix4.tryInvert(transform);
    if (inv != null) {
      // Dónde empieza y termina la pantalla actual en las coordenadas del mundo gigante
      final tl = MatrixUtils.transformPoint(inv, Offset.zero);
      final br = MatrixUtils.transformPoint(
          inv, Offset(viewportSize.width, viewportSize.height));

      // Mapear eso a nuestro minimapa chiquito
      final miniTl = Offset(tl.dx * scale + offsetX, tl.dy * scale + offsetY);
      final miniBr = Offset(br.dx * scale + offsetX, br.dy * scale + offsetY);

      final rectPaint = Paint()
        ..color = colors.accent.withOpacity(0.9)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final fillPaint = Paint()
        ..color = colors.accent.withOpacity(0.15)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromPoints(miniTl, miniBr);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, rectPaint);
    }
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.transform != transform || old.layout != layout;
}
