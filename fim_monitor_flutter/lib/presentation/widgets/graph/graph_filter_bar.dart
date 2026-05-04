// lib/presentation/widgets/graph/graph_filter_bar.dart
// v2 — colores hardcodeados → context.fimColors
//
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class GraphFilterBar extends StatefulWidget {
  final String? selected;
  final String? selectedSeveridad;
  final String? searchQuery;
  final void Function(String? tipo) onFilter;
  final void Function(String? severidad) onSeveridadFilter;
  final void Function(String? query) onSearch;

  const GraphFilterBar({
    super.key,
    required this.selected,
    required this.onFilter,
    required this.onSeveridadFilter,
    required this.onSearch,
    this.selectedSeveridad,
    this.searchQuery,
  });

  @override
  State<GraphFilterBar> createState() => _GraphFilterBarState();
}

class _GraphFilterBarState extends State<GraphFilterBar> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;

    return Container(
      color: c.filterBarBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Barra de búsqueda ──────────────────────────────────────────
          SizedBox(
            height: 32,
            child: TextField(
              controller: _searchCtrl,
              style: AppTextStyles.path
                  .copyWith(color: c.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Buscar ruta o archivo...',
                hintStyle: AppTextStyles.bodySmall
                    .copyWith(color: c.textDisabled, fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 14, color: c.textDisabled),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          widget.onSearch(null);
                          setState(() {});
                        },
                        child:
                            Icon(Icons.close, size: 14, color: c.textDisabled),
                      )
                    : null,
                filled: true,
                fillColor: c.surfaceVariant,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: c.accent, width: 1.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: c.border),
                ),
              ),
              onChanged: (v) {
                setState(() {});
                widget.onSearch(v.isEmpty ? null : v);
              },
            ),
          ),
          const SizedBox(height: 8),
          // ── Chips tipo + severidad en una sola fila scrollable ─────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Tipo:',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary)),
                const SizedBox(width: 8),
                _chip(c, 'Todos', null, widget.selected,
                    color: c.primary, onTap: () => widget.onFilter(null)),
                _chip(c, 'NEW', 'NEW', widget.selected,
                    color: c.eventNew,
                    onTap: () => widget
                        .onFilter(widget.selected == 'NEW' ? null : 'NEW')),
                _chip(c, 'MODIFIED', 'MODIFIED', widget.selected,
                    color: c.eventModified,
                    onTap: () => widget.onFilter(
                        widget.selected == 'MODIFIED' ? null : 'MODIFIED')),
                _chip(c, 'DELETED', 'DELETED', widget.selected,
                    color: c.eventDeleted,
                    onTap: () => widget.onFilter(
                        widget.selected == 'DELETED' ? null : 'DELETED')),
                _chip(c, 'PERMS', 'PERMISSIONS', widget.selected,
                    color: c.eventPerms,
                    onTap: () => widget.onFilter(
                        widget.selected == 'PERMISSIONS'
                            ? null
                            : 'PERMISSIONS')),
                const SizedBox(width: 16),
                Text('Severidad:',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary)),
                const SizedBox(width: 8),
                _chip(c, 'Todas', null, widget.selectedSeveridad,
                    color: c.primary,
                    onTap: () => widget.onSeveridadFilter(null)),
                _chip(c, 'ALTA', 'ALTA', widget.selectedSeveridad,
                    color: c.severityHigh,
                    onTap: () => widget.onSeveridadFilter(
                        widget.selectedSeveridad == 'ALTA' ? null : 'ALTA')),
                _chip(c, 'MEDIA', 'MEDIA', widget.selectedSeveridad,
                    color: c.severityMedium,
                    onTap: () => widget.onSeveridadFilter(
                        widget.selectedSeveridad == 'MEDIA' ? null : 'MEDIA')),
                _chip(c, 'BAJA', 'BAJA', widget.selectedSeveridad,
                    color: c.severityLow,
                    onTap: () => widget.onSeveridadFilter(
                        widget.selectedSeveridad == 'BAJA' ? null : 'BAJA')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    FimColors c,
    String label,
    String? value,
    String? selected, {
    required Color color,
    required VoidCallback onTap,
  }) {
    final active = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : c.surfaceVariant,
            border: Border.all(
              color: active ? color : c.border,
              width: active ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: active ? color : c.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
