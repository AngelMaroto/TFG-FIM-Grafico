// lib/presentation/widgets/graph/fim_graph_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:graphview/GraphView.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/alert_model.dart';
import '../../blocs/graph/graph_bloc.dart';
import 'node_detail_panel.dart';
import 'graph_filter_bar.dart';

class FimGraphWidget extends StatefulWidget {
  const FimGraphWidget({super.key});
  @override
  State<FimGraphWidget> createState() => _FimGraphWidgetState();
}

class _FimGraphWidgetState extends State<FimGraphWidget> {
  final Graph _graph = Graph()..isTree = true;
  final BuchheimWalkerConfiguration _config = BuchheimWalkerConfiguration()
    ..siblingSeparation = 40
    ..levelSeparation = 60
    ..subtreeSeparation = 40
    ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

  final TransformationController _transformCtrl = TransformationController();
  final Map<String, AlertModel> _nodeAlerts = {};
  Map<String, AlertModel>? _lastNodeMap;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _rebuildGraph(Map<String, AlertModel> nodeMap) {
    if (nodeMap == _lastNodeMap) return;
    _lastNodeMap = nodeMap;
    _graph.nodes.clear();
    _graph.edges.clear();
    _nodeAlerts.clear();

    final Map<String, Node> nodes = {};

    Node getOrCreate(String path) {
      if (nodes.containsKey(path)) return nodes[path]!;
      final n = Node.Id(path);
      nodes[path] = n;
      _graph.addNode(n);
      return n;
    }

    getOrCreate('/');
    _nodeAlerts['/'] = AlertModel(
      id: -1,
      tipoCambio: 'CLEAN',
      severidad: 'BAJA',
      rutaArchivo: '/',
    );

    for (final entry in nodeMap.entries) {
      final path = entry.key;
      final alert = entry.value;
      _nodeAlerts[path] = alert;

      final parts = path.split('/').where((p) => p.isNotEmpty).toList();
      String current = '';
      for (int i = 0; i < parts.length; i++) {
        final parent = current.isEmpty ? '/' : current;
        current = '$current/${parts[i]}';
        getOrCreate(current);
        if (!_nodeAlerts.containsKey(current)) {
          _nodeAlerts[current] = AlertModel(
            id: -1,
            tipoCambio: 'CLEAN',
            severidad: 'BAJA',
            rutaArchivo: current,
          );
        }
        _graph.addEdge(getOrCreate(parent), getOrCreate(current));
      }
    }
  }

  void _resetZoom() =>
      _transformCtrl.value = Matrix4.identity()..translate(50.0, 80.0);

  void _zoomIn() {
    final m = _transformCtrl.value.clone();
    m.scale(1.15, 1.15);
    _transformCtrl.value = m;
  }

  void _zoomOut() {
    final m = _transformCtrl.value.clone();
    m.scale(0.87, 0.87);
    _transformCtrl.value = m;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GraphBloc, GraphState>(
      // Reconstruir el grafo (layout) solo cuando cambia nodeMap,
      // NO cuando solo cambia snapshotOverride (eso solo repinta colores).
      listenWhen: (p, c) {
        if (p is GraphLoaded && c is GraphLoaded) {
          return p.nodeMap != c.nodeMap;
        }
        return c is GraphLoaded;
      },
      listener: (context, state) {
        if (state is GraphLoaded) setState(() => _rebuildGraph(state.nodeMap));
      },
      // buildWhen incluye snapshotOverride para repintar colores
      buildWhen: (p, c) =>
          c is! GraphLoaded ||
          p is! GraphLoaded ||
          p.nodeMap != c.nodeMap ||
          p.selectedRuta != c.selectedRuta ||
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
    final filteredMap = Map.fromEntries(
      state.nodeMap.entries.where((e) {
        final alert = e.value;
        final q = state.searchQuery?.toLowerCase();
        final matchSearch =
            q == null || q.isEmpty || e.key.toLowerCase().contains(q);
        final matchSev = state.filterSeveridad == null ||
            alert.severidad.toUpperCase() ==
                state.filterSeveridad!.toUpperCase();
        return matchSearch && matchSev;
      }),
    );
    _rebuildGraph(filteredMap);

    return Column(
      children: [
        // Banner de "viaje en el tiempo" cuando el slider no está en vivo
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
              InteractiveViewer(
                constrained: false,
                transformationController: _transformCtrl,
                minScale: 0.2,
                maxScale: 2.0,
                scaleFactor: 800,
                boundaryMargin: const EdgeInsets.all(500),
                trackpadScrollCausesScale: true,
                child: GraphView(
                  graph: _graph,
                  algorithm: BuchheimWalkerAlgorithm(
                      _config, TreeEdgeRenderer(_config)),
                  paint: Paint()
                    ..color = AppColors.border
                    ..strokeWidth = 1.0
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final path = node.key!.value as String;
                    final alert = _nodeAlerts[path];
                    final q = state.searchQuery?.toLowerCase();
                    final dimmed = q != null &&
                        q.isNotEmpty &&
                        !path.toLowerCase().contains(q);

                    // Si hay snapshot activo, obtener el tipoCambio histórico
                    // para este nodo. Si no aparece en el snapshot = CLEAN.
                    final snapshotTipo = state.snapshotOverride != null
                        ? (state.snapshotOverride![path] ?? 'CLEAN')
                        : null;

                    return _FimNode(
                      path: path,
                      alert: alert,
                      isSelected: state.selectedRuta == path,
                      dimmed: dimmed,
                      // snapshotTipo sobrescribe el color del nodo cuando
                      // el slider no está en la posición de en vivo
                      snapshotTipo: snapshotTipo,
                      onTap: () => context
                          .read<GraphBloc>()
                          .add(GraphNodeSelected(path)),
                    );
                  },
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _ZoomControls(
                  onReset: _resetZoom,
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                ),
              ),
            ],
          ),
        ),
        if (state.selectedRuta != null &&
            _nodeAlerts.containsKey(state.selectedRuta))
          NodeDetailPanel(alert: _nodeAlerts[state.selectedRuta]!),
      ],
    );
  }
}

// ── Banner de snapshot histórico ──────────────────────────────────────────────

class _SnapshotBanner extends StatelessWidget {
  final VoidCallback onLive;
  const _SnapshotBanner({required this.onLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF00D4FF).withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.history, size: 14, color: Color(0xFF00D4FF)),
          const SizedBox(width: 8),
          const Text(
            'Viendo estado histórico — el grafo muestra el pasado',
            style: TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
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
              child: const Text(
                'Volver a EN VIVO',
                style: TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nodo ──────────────────────────────────────────────────────────────────────

class _FimNode extends StatelessWidget {
  final String path;
  final AlertModel? alert;
  final bool isSelected;
  final bool dimmed;
  final VoidCallback onTap;

  /// Cuando no es null, sobrescribe el color del nodo con el estado histórico.
  final String? snapshotTipo;

  const _FimNode({
    required this.path,
    required this.alert,
    required this.isSelected,
    required this.onTap,
    this.dimmed = false,
    this.snapshotTipo,
  });

  bool get _isDir {
    final last = path.split('/').last;
    final ext = last.contains('.') ? last.split('.').last.toLowerCase() : '';
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
      'java'
    };
    return !fileExts.contains(ext);
  }

  String get _label {
    final name = path.split('/').last;
    return name.isEmpty ? '/' : name;
  }

  @override
  Widget build(BuildContext context) {
    // snapshotTipo tiene prioridad sobre el tipo real del nodo
    final tipo = snapshotTipo ?? alert?.tipoCambio ?? 'CLEAN';
    final color = eventColor(tipo);
    final size = _isDir ? 52.0 : 44.0;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.25 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(isSelected ? 0.25 : 0.12),
                border: Border.all(color: color, width: isSelected ? 2.5 : 1.5),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12)]
                    : null,
              ),
              child: Center(
                child: Icon(
                  _isDir
                      ? Icons.folder_outlined
                      : Icons.insert_drive_file_outlined,
                  size: _isDir ? 22 : 18,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 80,
              child: Text(
                _label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: isSelected ? color : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Zoom controls ─────────────────────────────────────────────────────────────

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

// ── Estados de carga ──────────────────────────────────────────────────────────

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
