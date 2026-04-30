// lib/presentation/pages/settings_page.dart
//
// Pantalla de ajustes completa — versión 2.0
//   • Sección: Estado del sistema (chips REST + WS, hostname, último scan)
//   • Sección: Conexión al backend (host/puerto + SharedPreferences)
//   • Sección: Directorios monitorizados (Config_Rules via ConfigBloc)
//   • Sección: Intervalo de escaneo (SharedPreferences)
//   • Sección: Severidad mínima visible (SharedPreferences)
//   • Sección: Opciones de visualización (SharedPreferences)
//   • Sección: Acerca de
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/fim_websocket_datasource.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences keys
// ─────────────────────────────────────────────────────────────────────────────
const _kHost = 'backend_host';
const _kPort = 'backend_port';
const _kInterval = 'scan_interval_minutes';
const _kMinSeverity = 'min_severity';
const _kShowOnly = 'show_only_changed';
const _kLabels = 'show_node_labels';

Future<(String, int)> loadSavedBackend() async {
  final prefs = await SharedPreferences.getInstance();
  return (
    prefs.getString(_kHost) ?? AppConstants.defaultBackendHost,
    prefs.getInt(_kPort) ?? AppConstants.defaultBackendPort,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo local para Config_Rules (sin BLoC extra, HTTP directo)
// ─────────────────────────────────────────────────────────────────────────────
class _ConfigRule {
  final int id;
  final String ruta;
  final String nivelSeveridad;
  const _ConfigRule(
      {required this.id, required this.ruta, required this.nivelSeveridad});

  factory _ConfigRule.fromJson(Map<String, dynamic> j) => _ConfigRule(
        id: j['id'] as int,
        ruta: j['ruta'] as String,
        nivelSeveridad: j['nivelSeveridad'] as String? ?? 'MEDIA',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Backend URL
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  bool _saving = false;

  // Config_Rules
  List<_ConfigRule> _rules = [];
  bool _rulesLoading = true;
  String? _rulesError;

  // Prefs
  int _scanInterval = 5;
  String _minSeverity = 'BAJA';
  bool _showOnlyChanged = false;
  bool _showNodeLabels = true;
  bool _prefsLoaded = false;

  // Status REST
  Map<String, dynamic>? _statusData;
  String? _wsError;
  bool _checkLoading = false;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController();
    _portCtrl = TextEditingController();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_kHost) ?? AppConstants.defaultBackendHost;
    final port = prefs.getInt(_kPort) ?? AppConstants.defaultBackendPort;

    setState(() {
      _hostCtrl.text = host;
      _portCtrl.text = port.toString();
      _scanInterval = prefs.getInt(_kInterval) ?? 5;
      _minSeverity = prefs.getString(_kMinSeverity) ?? 'BAJA';
      _showOnlyChanged = prefs.getBool(_kShowOnly) ?? false;
      _showNodeLabels = prefs.getBool(_kLabels) ?? true;
      _prefsLoaded = true;
    });

    _fetchStatus(host, port);
    _fetchRules(host, port);
  }

  Future<void> _fetchStatus(String host, int port) async {
    try {
      final uri = Uri.parse(
          '${AppConstants.baseUrl(host, port)}${AppConstants.statusEndpoint}');
      final res = await http.get(uri).timeout(AppConstants.httpTimeout);
      if (res.statusCode == 200 && mounted) {
        setState(
            () => _statusData = jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _fetchRules(String host, int port) async {
    setState(() {
      _rulesLoading = true;
      _rulesError = null;
    });
    try {
      final uri = Uri.parse(
          '${AppConstants.baseUrl(host, port)}${AppConstants.configEndpoint}');
      final res = await http.get(uri).timeout(AppConstants.httpTimeout);
      if (res.statusCode == 200 && mounted) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _rules = list
              .map((e) => _ConfigRule.fromJson(e as Map<String, dynamic>))
              .toList();
          _rulesLoading = false;
        });
      } else {
        setState(() {
          _rulesError = 'Error ${res.statusCode}';
          _rulesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rulesError = 'Sin conexión con el backend';
          _rulesLoading = false;
        });
      }
    }
  }

  Future<void> _addRule(String ruta, String severidad) async {
    final host = _hostCtrl.text.trim();
    final port =
        int.tryParse(_portCtrl.text.trim()) ?? AppConstants.defaultBackendPort;
    try {
      final uri = Uri.parse(
          '${AppConstants.baseUrl(host, port)}${AppConstants.configEndpoint}');
      final res = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'ruta': ruta, 'nivelSeveridad': severidad}));
      if (res.statusCode == 201) {
        _fetchRules(host, port);
      } else if (res.statusCode == 409) {
        _snack('Ya existe una regla para "$ruta"', error: true);
      } else {
        _snack('Error ${res.statusCode}', error: true);
      }
    } catch (_) {
      _snack('Sin conexión con el backend', error: true);
    }
  }

  Future<void> _updateRule(int id, String severidad) async {
    final host = _hostCtrl.text.trim();
    final port =
        int.tryParse(_portCtrl.text.trim()) ?? AppConstants.defaultBackendPort;
    try {
      final uri = Uri.parse(
          '${AppConstants.baseUrl(host, port)}${AppConstants.configEndpoint}/$id');
      final res = await http.put(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'nivelSeveridad': severidad}));
      if (res.statusCode == 200) _fetchRules(host, port);
    } catch (_) {}
  }

  Future<void> _deleteRule(int id) async {
    final host = _hostCtrl.text.trim();
    final port =
        int.tryParse(_portCtrl.text.trim()) ?? AppConstants.defaultBackendPort;
    try {
      final uri = Uri.parse(
          '${AppConstants.baseUrl(host, port)}${AppConstants.configEndpoint}/$id');
      final res = await http.delete(uri);
      if (res.statusCode == 204) _fetchRules(host, port);
    } catch (_) {}
  }

  Future<void> _saveBackend() async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHost, host);
    await prefs.setInt(_kPort, port);
    await sl.reset();
    await initDependencies(host: host, port: port);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Guardado: $host:$port — reconectando…');
    _fetchStatus(host, port);
    _fetchRules(host, port);
  }

  Future<void> _savePref<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is int) await prefs.setInt(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  Future<void> _requestCheck() async {
    setState(() => _checkLoading = true);
    final host = _hostCtrl.text.trim();
    final port =
        int.tryParse(_portCtrl.text.trim()) ?? AppConstants.defaultBackendPort;
    try {
      final uri =
          Uri.parse('${AppConstants.baseUrl(host, port)}/api/agent/check');
      final res = await http.post(uri).timeout(AppConstants.httpTimeout);
      if (res.statusCode == 200) {
        _snack('Check solicitado. El agente lo ejecutará en breve.');
        // Refrescar status tras 3s para ver el nuevo scan
        Future.delayed(
            const Duration(seconds: 3), () => _fetchStatus(host, port));
      } else {
        _snack('Error ${res.statusCode} al solicitar check', error: true);
      }
    } catch (_) {
      _snack('Sin conexión con el backend', error: true);
    } finally {
      if (mounted) setState(() => _checkLoading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: AppTextStyles.bodySmall.copyWith(
              color: error ? AppColors.eventDeleted : AppColors.onPrimary)),
      backgroundColor: error ? AppColors.surfaceVariant : AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _saveInterval(int minutes) async {
    setState(() => _scanInterval = minutes);

    // Guardar localmente
    _savePref(_kInterval, minutes);
    // Leer host/puerto de SharedPreferences (no de los controllers)
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_kHost) ?? AppConstants.defaultBackendHost;
    final port = prefs.getInt(_kPort) ?? AppConstants.defaultBackendPort;
    try {
      print(
          'PUT a: ${AppConstants.baseUrl(host, port)}/api/config/system/scan_interval');
      final uri = Uri.parse(
          '${AppConstants.baseUrl(host, port)}/api/config/system/scan_interval');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'value': (minutes * 60).toString(),
          'descripcion': 'Intervalo de escaneo en segundos',
        }),
      );
      if (res.statusCode == 200) {
        _snack('Intervalo actualizado a $minutes min en el agente.');
      } else {
        _snack('Error al guardar intervalo en backend', error: true);
      }
    } catch (_) {
      _snack('Sin conexión — intervalo guardado solo localmente', error: true);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildStatusSection(),
          const SizedBox(height: 12),
          _buildBackendSection(),
          const SizedBox(height: 12),
          _buildRulesSection(),
          const SizedBox(height: 12),
          _buildIntervalSection(),
          const SizedBox(height: 12),
          _buildSeveritySection(),
          const SizedBox(height: 12),
          _buildVisualizationSection(),
          const SizedBox(height: 12),
          _buildAboutSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Estado del sistema ─────────────────────────────────────────────────────

  Widget _buildStatusSection() {
    return _Card(
      title: 'Estado del sistema',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón check manual
          _checkLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary))
              : IconButton(
                  icon: const Icon(Icons.play_circle_outline,
                      size: 18, color: AppColors.primary),
                  tooltip: 'Ejecutar check ahora',
                  onPressed: _requestCheck,
                ),
          IconButton(
            icon: const Icon(Icons.refresh,
                size: 16, color: AppColors.textSecondary),
            tooltip: 'Actualizar estado',
            onPressed: () {
              final host = _hostCtrl.text.trim();
              final port = int.tryParse(_portCtrl.text.trim()) ?? 8080;
              _fetchStatus(host, port);
              _fetchRules(host, port);
            },
          ),
        ],
      ),
      child: Column(children: [
        // REST status
        _StatusRow(
          label: _statusData != null
              ? 'Backend REST: Conectado'
              : 'Backend REST: Sin conexión',
          color: _statusData != null
              ? AppColors.eventClean
              : AppColors.eventDeleted,
        ),
        const Divider(height: 1, color: AppColors.border),
        // WS: inferido del statusData (si hay datos el backend responde → WS probablemente activo)
        _StatusRow(
          label: _wsError == null && _statusData != null
              ? 'WebSocket: Disponible'
              : 'WebSocket: Error (ver logs)',
          color: _wsError == null && _statusData != null
              ? AppColors.eventClean
              : AppColors.eventDeleted,
        ),
        if (_statusData != null) ...[
          const Divider(height: 1, color: AppColors.border),
          _InfoRow(
              label: 'Servidor',
              value: _statusData!['hostname']?.toString() ?? '—'),
          const Divider(height: 1, color: AppColors.border),
          _InfoRow(
              label: 'Último escaneo',
              value: _formatTs(_statusData!['ultimoScan']?.toString())),
          const Divider(height: 1, color: AppColors.border),
          _InfoRow(
            label: 'Escaneos / Eventos',
            value:
                '${_statusData!['scans'] ?? 0} / ${_statusData!['events'] ?? 0}',
          ),
        ],
      ]),
    );
  }

  // ── Conexión al backend ────────────────────────────────────────────────────

  Widget _buildBackendSection() {
    return _Card(
      title: 'Conexión al backend',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(children: [
          Row(children: [
            Expanded(
              flex: 5,
              child: _Field(
                  label: 'Host / IP', ctrl: _hostCtrl, hint: '192.168.1.100'),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _Field(
                  label: 'Puerto',
                  ctrl: _portCtrl,
                  hint: '8080',
                  keyboard: TextInputType.number),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _saving ? null : _saveBackend,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary))
                  : Text('Guardar y reconectar',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.onPrimary)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Directorios monitorizados ──────────────────────────────────────────────

  Widget _buildRulesSection() {
    return _Card(
      title: 'Directorios monitorizados',
      action: IconButton(
        icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
        onPressed: () => _showAddDialog(),
      ),
      child: _rulesLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary)))
          : _rulesError != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_rulesError!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.eventDeleted)))
              : _rules.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Sin reglas. Pulsa + para añadir un directorio.',
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: _rules
                          .map((r) => _RuleTile(
                                rule: r,
                                onDelete: () => _confirmDelete(r),
                                onChangeSev: (sev) => _updateRule(r.id, sev),
                              ))
                          .toList(),
                    ),
    );
  }

  // ── Intervalo de escaneo ───────────────────────────────────────────────────

  Widget _buildIntervalSection() {
    const options = [1, 5, 15, 30, 60];
    return _Card(
      title: 'Intervalo de escaneo',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: options.map((m) {
                final sel = _scanInterval == m;
                return ChoiceChip(
                  label: Text(m == 60 ? '1 h' : '$m min'),
                  selected: sel,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                      color: sel ? AppColors.primary : AppColors.textSecondary),
                  side: BorderSide(
                      color: sel ? AppColors.primary : AppColors.border),
                  onSelected: (_) => _saveInterval(m),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              'El agente comprobará cambios cada $_scanInterval '
              '${_scanInterval == 60 ? 'hora' : 'minutos'}.',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ── Severidad mínima ───────────────────────────────────────────────────────

  Widget _buildSeveritySection() {
    const opts = ['ALTA', 'MEDIA', 'BAJA'];
    return _Card(
      title: 'Severidad mínima visible',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: opts.map((s) {
                final sel = _minSeverity == s;
                final c = severityColor(s);
                return ChoiceChip(
                  label: Text(s),
                  selected: sel,
                  selectedColor: c.withOpacity(0.15),
                  labelStyle: AppTextStyles.bodySmall
                      .copyWith(color: sel ? c : AppColors.textSecondary),
                  side: BorderSide(color: sel ? c : AppColors.border),
                  onSelected: (_) {
                    setState(() => _minSeverity = s);
                    _savePref(_kMinSeverity, s);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              'Solo se mostrarán alertas de severidad $_minSeverity o superior.',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ── Visualización ──────────────────────────────────────────────────────────

  Widget _buildVisualizationSection() {
    return _Card(
      title: 'Opciones de visualización',
      child: Column(children: [
        _ToggleRow(
          label: 'Solo nodos con cambios',
          subtitle: 'Oculta nodos en estado OK en el grafo',
          value: _showOnlyChanged,
          onChanged: (v) {
            setState(() => _showOnlyChanged = v);
            _savePref(_kShowOnly, v);
          },
        ),
        const Divider(height: 1, color: AppColors.border),
        _ToggleRow(
          label: 'Etiquetas en el grafo',
          subtitle: 'Muestra el nombre del archivo sobre cada nodo',
          value: _showNodeLabels,
          onChanged: (v) {
            setState(() => _showNodeLabels = v);
            _savePref(_kLabels, v);
          },
        ),
      ]),
    );
  }

  // ── Acerca de ──────────────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return _Card(
      title: 'Acerca de',
      child: Column(children: [
        _InfoRow(label: 'Versión', value: '1.0.0-beta'),
        const Divider(height: 1, color: AppColors.border),
        _InfoRow(label: 'Autor', value: 'Ángel Maroto García'),
        const Divider(height: 1, color: AppColors.border),
        _InfoRow(label: 'Proyecto', value: 'TFG DAM · IFC02S · 2025-2026'),
        const Divider(height: 1, color: AppColors.border),
        _InfoRow(
            label: 'Stack',
            value: 'Flutter · Spring Boot · SQLite · AIDE',
            mono: true),
      ]),
    );
  }

  // ── Diálogos ───────────────────────────────────────────────────────────────

  void _showAddDialog() {
    final ctrl = TextEditingController();
    String sev = 'MEDIA';

    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Añadir directorio', style: AppTextStyles.titleMedium),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: AppTextStyles.path.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Ruta del directorio',
                labelStyle: AppTextStyles.bodySmall,
                hintText: '/etc/ssh',
                hintStyle: AppTextStyles.bodySmall,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                prefixIcon: const Icon(Icons.folder_outlined,
                    size: 16, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Severidad', style: AppTextStyles.bodySmall),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['ALTA', 'MEDIA', 'BAJA'].map((s) {
                final c = severityColor(s);
                return ChoiceChip(
                  label: Text(s),
                  selected: sev == s,
                  selectedColor: c.withOpacity(0.15),
                  labelStyle: AppTextStyles.bodySmall
                      .copyWith(color: sev == s ? c : AppColors.textSecondary),
                  side: BorderSide(color: sev == s ? c : AppColors.border),
                  onSelected: (_) => setSt(() => sev = s),
                );
              }).toList(),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary),
              onPressed: () {
                final ruta = ctrl.text.trim();
                if (ruta.isEmpty) return;
                Navigator.pop(ctx);
                _addRule(ruta, sev);
              },
              child: Text('Añadir',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(_ConfigRule rule) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Eliminar regla', style: AppTextStyles.titleMedium),
        content: Text('¿Eliminar la regla para "${rule.ruta}"?',
            style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.eventDeleted,
                foregroundColor: AppColors.onPrimary),
            onPressed: () {
              Navigator.pop(context);
              _deleteRule(rule.id);
            },
            child: Text('Eliminar',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatTs(String? ts) {
    if (ts == null || ts == 'Sin escaneos') return 'Sin escaneos';
    try {
      final dt = DateTime.parse(ts);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _Card({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Text(title,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primary)),
            ),
            if (action != null) action!,
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        child,
      ]),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusRow({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textPrimary)),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _InfoRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          Text(value,
              style: mono
                  ? AppTextStyles.path
                  : AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary)),
        ]),
      );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.label,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(label,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final TextInputType keyboard;
  const _Field(
      {required this.label,
      required this.ctrl,
      required this.hint,
      this.keyboard = TextInputType.text});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            style: AppTextStyles.path.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodySmall,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

class _RuleTile extends StatelessWidget {
  final _ConfigRule rule;
  final VoidCallback onDelete;
  final ValueChanged<String> onChangeSev;
  const _RuleTile(
      {required this.rule, required this.onDelete, required this.onChangeSev});

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Icon(Icons.folder_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(rule.ruta,
                  style: AppTextStyles.path
                      .copyWith(color: AppColors.textPrimary)),
            ),
            // Selector de severidad
            PopupMenuButton<String>(
              initialValue: rule.nivelSeveridad,
              color: AppColors.surfaceVariant,
              onSelected: onChangeSev,
              itemBuilder: (_) => ['ALTA', 'MEDIA', 'BAJA']
                  .map((s) => PopupMenuItem(
                        value: s,
                        child: Text(s,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: severityColor(s))),
                      ))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                      color:
                          severityColor(rule.nivelSeveridad).withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(4),
                  color: severityColor(rule.nivelSeveridad).withOpacity(0.1),
                ),
                child: Text(
                  rule.nivelSeveridad,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: severityColor(rule.nivelSeveridad),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 14, color: AppColors.eventDeleted),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
      ]);
}
