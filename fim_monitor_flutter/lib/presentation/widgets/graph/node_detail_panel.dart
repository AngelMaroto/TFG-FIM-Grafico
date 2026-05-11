// lib/presentation/widgets/graph/node_detail_panel.dart
import 'dart:ui' as ui;
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
    // 1. Obtenemos los colores dinámicos del tema actual (Claro u Oscuro)
    final c = context.fimColors;

    // 2. Usamos las funciones de color que aceptan el FimColors dinámico
    final color = eventColorFrom(alert.tipoCambio, c);
    final sev = severityColorFrom(alert.severidad, c);

    return ClipRRect(
      child: BackdropFilter(
        // Efecto cristal esmerilado para que el fondo del grafo se difumine
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: c.surface
                  .withOpacity(0.85), // Fondo dinámico semi-transparente
              border: Border(top: BorderSide(color: c.border.withOpacity(0.5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min, // Importante para no expandirse de más
              children: [
                // Cabecera: tipo + severidad
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      border: Border.all(color: color.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(alert.tipoCambio,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sev.withOpacity(0.12),
                      border: Border.all(color: sev.withOpacity(0.35)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Severidad: ${alert.severidad}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: sev, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 14),
                // Campos del evento
                if (alert.rutaArchivo != null)
                  _Row(
                      label: 'Ruta',
                      value: alert.rutaArchivo!,
                      mono: true,
                      colors: c),
                if (alert.fechaEjecucion != null)
                  _Row(
                      label: 'Tiempo',
                      value: _formatTs(alert.fechaEjecucion!),
                      colors: c),
                if (alert.hashActual != null)
                  _Row(
                      label: 'Hash actual',
                      value: alert.hashActual!,
                      mono: true,
                      muted: true,
                      colors: c),
                if (alert.hashAnterior != null)
                  _Row(
                      label: 'Hash anterior',
                      value: alert.hashAnterior!,
                      mono: true,
                      muted: true,
                      colors: c),
                if (alert.permisos != null)
                  _Row(label: 'Permisos', value: alert.permisos!, colors: c),
                if (alert.tamano != null)
                  _Row(
                      label: 'Tamaño',
                      value: _fmtBytes(alert.tamano!),
                      colors: c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _fmtBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1048576).toStringAsFixed(2)} MB';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final bool muted;
  final FimColors colors;

  const _Row(
      {required this.label,
      required this.value,
      required this.colors,
      this.mono = false,
      this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: AppTextStyles.bodySmall.copyWith(
                    color: colors
                        .textSecondary, // <-- Quitado el .withOpacity(0.8)
                    fontWeight: FontWeight.w600)), // <-- Subido a w600
          ),
          Expanded(
            child: Text(
              value,
              style: (mono ? AppTextStyles.hash : AppTextStyles.bodySmall)
                  .copyWith(
                // Aseguramos que el texto principal sea totalmente opaco
                color: muted ? colors.textSecondary : colors.textPrimary,
                fontWeight:
                    mono ? FontWeight.w500 : FontWeight.w600, // <-- Más peso
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
