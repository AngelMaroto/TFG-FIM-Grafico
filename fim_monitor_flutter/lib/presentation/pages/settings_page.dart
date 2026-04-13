// lib/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

/// Permite al usuario configurar la URL del backend.
/// TODO: persistir con SharedPreferences y reiniciar la DI al guardar.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: AppConstants.defaultBackendHost);
    _portCtrl = TextEditingController(text: AppConstants.defaultBackendPort.toString());
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
            Text('Backend', style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.primary)),
            const SizedBox(height: 16),
            _Field(label: 'Host / IP', controller: _hostCtrl,
                hint: '192.168.1.100'),
            const SizedBox(height: 12),
            _Field(label: 'Puerto', controller: _portCtrl,
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
                onPressed: () {
                  // TODO: persistir y reiniciar conexión
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Guardado: ${_hostCtrl.text}:${_portCtrl.text}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.background),
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
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
        Text(label, style: AppTextStyles.bodySmall
            .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller:  controller,
          keyboardType: keyboardType,
          style: AppTextStyles.path.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodySmall,
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
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
        ),
      ],
    );
  }
}
