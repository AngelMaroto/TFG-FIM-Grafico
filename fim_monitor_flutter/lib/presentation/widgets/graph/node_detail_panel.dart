// lib/presentation/widgets/graph/node_detail_panel.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/alert_model.dart';

/// Panel que se muestra debajo del grafo al seleccionar un nodo.
/// Muestra todos los campos del evento FIM (RF-11).
class NodeDetailPanel extends StatelessWidget {
  final AlertModel alert;

  const NodeDetailPanel({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = eventColor(alert.tipoCambio);
    final sev   = severityColor(alert.severidad);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: tipo + severidad
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(alert.tipoCambio,
                    style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: sev.withOpacity(0.12),
                  border: Border.all(color: sev.withOpacity(0.35)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Severidad: ${alert.severidad}',
                    style: AppTextStyles.bodySmall.copyWith(color: sev)),
              ),
            ]),
            const SizedBox(height: 10),
            // Campos del evento
            if (alert.rutaArchivo != null)
              _Row(label: 'Ruta',   value: alert.rutaArchivo!,  mono: true),
            if (alert.fechaEjecucion != null)
              _Row(label: 'Tiempo', value: _formatTs(alert.fechaEjecucion!)),
            if (alert.hashActual != null)
              _Row(label: 'Hash actual',   value: alert.hashActual!,  mono: true, muted: true),
            if (alert.hashAnterior != null)
              _Row(label: 'Hash anterior', value: alert.hashAnterior!, mono: true, muted: true),
            if (alert.permisos != null)
              _Row(label: 'Permisos', value: alert.permisos!),
            if (alert.tamano != null)
              _Row(label: 'tamano',   value: '${_fmtBytes(alert.tamano!)}'),
          ],
        ),
      ),
    );
  }

  String _formatTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
    } catch (_) { return iso; }
  }

  String _fmtBytes(int b) {
    if (b < 1024)       return '$b B';
    if (b < 1048576)    return '${(b/1024).toStringAsFixed(1)} KB';
    return '${(b/1048576).toStringAsFixed(2)} MB';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool   mono;
  final bool   muted;

  const _Row({required this.label, required this.value,
      this.mono = false, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textDisabled)),
          ),
          Expanded(
            child: Text(value,
              style: (mono ? AppTextStyles.hash : AppTextStyles.bodySmall).copyWith(
                color: muted ? AppColors.textDisabled : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
