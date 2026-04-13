// lib/presentation/widgets/graph/graph_filter_bar.dart
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barra de búsqueda ──────────────────────────────────────
          SizedBox(
            height: 32,
            child: TextField(
              controller: _searchCtrl,
              style: AppTextStyles.path
                  .copyWith(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Buscar ruta o archivo...',
                hintStyle: AppTextStyles.bodySmall,
                prefixIcon: const Icon(Icons.search,
                    size: 14, color: AppColors.textDisabled),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          widget.onSearch(null);
                        },
                        child: const Icon(Icons.close,
                            size: 14, color: AppColors.textDisabled),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onChanged: (v) {
                setState(() {});
                widget.onSearch(v.isEmpty ? null : v);
              },
            ),
          ),
          const SizedBox(height: 8),
          // ── Filtros tipo + severidad ───────────────────────────────
          Row(
            children: [
              Text('Tipo:', style: AppTextStyles.bodySmall),
              const SizedBox(width: 8),
              Wrap(spacing: 6, children: [
                _chip('Todos', null, widget.selected,
                    onTap: () => widget.onFilter(null)),
                _chip('NEW', 'NEW', widget.selected,
                    color: AppColors.eventNew,
                    onTap: () => widget.onFilter('NEW')),
                _chip('MODIFIED', 'MODIFIED', widget.selected,
                    color: AppColors.eventModified,
                    onTap: () => widget.onFilter('MODIFIED')),
                _chip('DELETED', 'DELETED', widget.selected,
                    color: AppColors.eventDeleted,
                    onTap: () => widget.onFilter('DELETED')),
                _chip('PERMS', 'PERMISSIONS', widget.selected,
                    color: AppColors.eventPerms,
                    onTap: () => widget.onFilter('PERMISSIONS')),
              ]),
              const SizedBox(width: 16),
              Text('Severidad:', style: AppTextStyles.bodySmall),
              const SizedBox(width: 8),
              Wrap(spacing: 6, children: [
                _chip('Todas', null, widget.selectedSeveridad,
                    onTap: () => widget.onSeveridadFilter(null)),
                _chip('ALTA', 'ALTA', widget.selectedSeveridad,
                    color: AppColors.severityHigh,
                    onTap: () => widget.onSeveridadFilter('ALTA')),
                _chip('MEDIA', 'MEDIA', widget.selectedSeveridad,
                    color: AppColors.severityMedium,
                    onTap: () => widget.onSeveridadFilter('MEDIA')),
                _chip('BAJA', 'BAJA', widget.selectedSeveridad,
                    color: AppColors.severityLow,
                    onTap: () => widget.onSeveridadFilter('BAJA')),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value, String? selected,
      {Color color = AppColors.textSecondary, required VoidCallback onTap}) {
    final active = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : AppColors.surfaceVariant,
          border: Border.all(color: active ? color : AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTextStyles.bodySmall.copyWith(
              color: active ? color : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            )),
      ),
    );
  }
}
