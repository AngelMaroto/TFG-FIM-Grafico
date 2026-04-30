// lib/presentation/pages/settings_page.dart
//
// CAMBIOS respecto a la versión anterior:
//   • Persistencia real con SharedPreferences (añadir al pubspec).
//   • Al guardar, reinicia la DI completa con el nuevo host/puerto.
//   • Muestra la configuración activa al entrar.
//
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';

// ── Claves SharedPreferences ──────────────────────────────────────────────────
const _kHost = 'backend_host';
const _kPort = 'backend_port';

/// Carga host/puerto guardados, o los valores por defecto.
Future<(String, int)> loadSavedBackend() async {
  final prefs = await SharedPreferences.getInstance();
  final host = prefs.getString(_kHost) ?? AppConstants.defaultBackendHost;
  final port = prefs.getInt(_kPort) ?? AppConstants.defaultBackendPort;
  return (host, port);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController();
    _portCtrl = TextEditingController();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final (host, port) = await loadSavedBackend();
    if (!mounted) return;
    setState(() {
      _hostCtrl.text = host;
      _portCtrl.text = port.toString();
    });
  }

  Future<void> _save() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim());

    if (host.isEmpty) {
      _snack('El host no puede estar vacío', error: true);
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      _snack('Puerto inválido (1–65535)', error: true);
      return;
    }

    setState(() => _saving = true);

    // 1. Persistir
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHost, host);
    await prefs.setInt(_kPort, port);

    // 2. Reinicializar la DI con los nuevos valores
    await sl.reset();
    await initDependencies(host: host, port: port);

    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Guardado: $host:$port — reconectando…');
    Navigator.pop(context);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: AppTextStyles.bodySmall.copyWith(
              color: error ? AppColors.eventDeleted : AppColors.onPrimary)),
      backgroundColor: error ? AppColors.surface : AppColors.primary,
    ));
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conexión al backend',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('La app se reconectará automáticamente al guardar.',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 24),
            _Field(
                label: 'Host / IP',
                controller: _hostCtrl,
                hint: '192.168.1.100'),
            const SizedBox(height: 12),
            _Field(
                label: 'Puerto',
                controller: _portCtrl,
                hint: '8080',
                keyboardType: TextInputType.number),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : const Text('Guardar y reconectar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTextStyles.path.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodySmall,
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}
