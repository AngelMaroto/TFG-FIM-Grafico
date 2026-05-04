// lib/presentation/pages/settings_page.dart
// v4 — colores hardcodeados → context.fimColors
//      Cero referencias a AppColors en el árbol de widgets.
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/theme/theme_bloc.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences keys
// ─────────────────────────────────────────────────────────────────────────────
const _kHost = 'backend_host';
const _kPort = 'backend_port';
const _kInterval = 'scan_interval_minutes';
const _kMinSeverity = 'min_severity';
const _kShowOnly = 'show_only_changed';
const _kLabels = 'show_node_labels';
const _kHttpTimeout = Duration(seconds: 4);

Future<(String, int)> loadSavedBackend() async {
  final prefs = await SharedPreferences.getInstance();
  return (
    prefs.getString(_kHost) ?? AppConstants.defaultBackendHost,
    prefs.getInt(_kPort) ?? AppConstants.defaultBackendPort,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GraphVisualizationPrefs — leído por FimGraphWidget
// ─────────────────────────────────────────────────────────────────────────────
class GraphVisualizationPrefs {
  final bool showOnlyChanged;
  final bool showNodeLabels;
  const GraphVisualizationPrefs({
    required this.showOnlyChanged,
    required this.showNodeLabels,
  });

  static Future<GraphVisualizationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return GraphVisualizationPrefs(
      showOnlyChanged: prefs.getBool(_kShowOnly) ?? false,
      showNodeLabels: prefs.getBool(_kLabels) ?? true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo Config_Rule
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
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  bool _saving = false;

  List<_ConfigRule> _rules = [];
  bool _rulesLoading = true;
  String? _rulesError;

  int _scanInterval = 5;
  String _minSeverity = 'BAJA';
  bool _showOnlyChanged = false;
  bool _showNodeLabels = true;
  bool _prefsLoaded = false;

  Map<String, dynamic>? _statusData;
  bool _checkLoading = false;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController();
    _portCtrl = TextEditingController();
    _loadAll();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_kHost) ?? AppConstants.defaultBackendHost;
    final port = prefs.getInt(_kPort) ?? AppConstants.defaultBackendPort;
    if (!mounted) return;
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
      final res = await http
          .get(Uri.parse(
              '${AppConstants.baseUrl(host, port)}${AppConstants.statusEndpoint}'))
          .timeout(_kHttpTimeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(
            () => _statusData = jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {
      if (mounted) setState(() => _statusData = null);
    }
  }

  Future<void> _fetchRules(String host, int port) async {
    if (!mounted) return;
    setState(() {
      _rulesLoading = true;
      _rulesError = null;
    });
    try {
      final res = await http
          .get(Uri.parse(
              '${AppConstants.baseUrl(host, port)}${AppConstants.configEndpoint}'))
          .timeout(_kHttpTimeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
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
      if (mounted)
        setState(() {
          _rulesError = 'Sin conexión con el backend';
          _rulesLoading = false;
        });
    }
  }

  Future<void> _addRule(String ruta, String severidad) async {
    final host = _hostCtrl.text.trim();
    final port =
        int.tryParse(_portCtrl.text.trim()) ?? AppConstants.defaultBackendPort;
    try {
      final res = await http.post(
        Uri.parse(
            '${AppConstants.baseUrl(host, port)}${AppConstants.configEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ruta': ruta, 'nivelSeveridad': severidad}),
      );
      if (!mounted) return;
      if (res.statusCode == 201) {
        _fetchRules(host, port);
      } else if (res.statusCode == 409) {
        _snack('Ya existe una regla para "$ruta"', error: true);
      } else {
        _snack('Error ${res.statusCode}', error: true);
      }
    } catch (_) {
      if (mounted) _snack('Sin conexión con el backend', error: true);
    }
  }

  Future<void> _updateRule(int id, String severidad) async {
    final host = _hostCtrl.text.trim();
    final port =
        int.tryParse(_portCtrl.text.trim()) ?? AppConstants.defaultBackendPort;
    try {
      final res = await http.put(
        Uri.parse(
            '${AppConstants.baseUrl(host, port)}${AppConstants.configEndpoint}/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nivelSeveridad': severidad}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) _fetchRules(host, port);
    } catch (_) {}
  }

  Future<void> _deleteRule(int id) async {
    final host = _hostCtrl.text.trim();
    final port =
        int.tryParse(_portCtrl.text.trim()) ?? AppConstants.defaultBackendPort;
    try {
      final res = await http
          .delete(Uri.parse(
              '${AppConstants.baseUrl(host, port)}${AppConstants.configEndpoint}/$id'))
          .timeout(_kHttpTimeout);
      if (!mounted) return;
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
    if (!mounted) return;
    setState(() => _saving = false);

    _snack('Guardado: $host:$port — verificando conexión…');
    await _fetchStatus(host, port);
    if (!mounted) return;

    if (_statusData != null) {
      _fetchRules(host, port);
      _snack(
          '✓ Conectado a $host:$port — reinicia la app para aplicar en el grafo');
    } else {
      _snack('Guardado. Backend no responde en $host:$port', error: true);
    }
  }

  Future<void> _savePref<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is int) await prefs.setInt(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  Future<void> _requestCheck() async {
    if (!mounted) return;
    setState(() => _checkLoading = true);
    final host = _hostCtrl.text.trim();
    final port =
        int.tryParse(_portCtrl.text.trim()) ?? AppConstants.defaultBackendPort;
    try {
      final res = await http
          .post(
              Uri.parse('${AppConstants.baseUrl(host, port)}/api/agent/check'))
          .timeout(_kHttpTimeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
        _snack('Check solicitado. El agente lo ejecutará en breve.');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _fetchStatus(host, port);
        });
      } else {
        _snack('Error ${res.statusCode} al solicitar check', error: true);
      }
    } catch (_) {
      if (mounted) _snack('Sin conexión con el backend', error: true);
    } finally {
      if (mounted) setState(() => _checkLoading = false);
    }
  }

  Future<void> _saveInterval(int minutes) async {
    if (!mounted) return;
    setState(() => _scanInterval = minutes);
    _savePref(_kInterval, minutes);
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_kHost) ?? AppConstants.defaultBackendHost;
    final port = prefs.getInt(_kPort) ?? AppConstants.defaultBackendPort;
    if (!mounted) return;
    try {
      final res = await http
          .put(
            Uri.parse(
                '${AppConstants.baseUrl(host, port)}/api/config/system/scan_interval'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'value': (minutes * 60).toString(),
              'descripcion': 'Intervalo de escaneo en segundos'
            }),
          )
          .timeout(_kHttpTimeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
        _snack('Intervalo actualizado a $minutes min en el agente.');
      } else {
        _snack('Error al guardar intervalo en backend', error: true);
      }
    } catch (_) {
      if (mounted)
        _snack('Sin conexión — intervalo guardado solo localmente',
            error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final c = context.fimColors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: AppTextStyles.bodySmall
              .copyWith(color: error ? c.eventDeleted : c.onPrimary)),
      backgroundColor: error ? c.surfaceVariant : c.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: context.fimColors.primary)),
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
          _buildAppearanceSection(),
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
    final c = context.fimColors;
    return _Card(
      title: 'Estado del sistema',
      action: Row(mainAxisSize: MainAxisSize.min, children: [
        _checkLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: c.primary))
            : IconButton(
                icon:
                    Icon(Icons.play_circle_outline, size: 18, color: c.primary),
                tooltip: 'Ejecutar check ahora',
                onPressed: _requestCheck,
              ),
        IconButton(
          icon: Icon(Icons.refresh, size: 16, color: c.textSecondary),
          tooltip: 'Actualizar estado',
          onPressed: () {
            final host = _hostCtrl.text.trim();
            final port = int.tryParse(_portCtrl.text.trim()) ?? 8080;
            _fetchStatus(host, port);
            _fetchRules(host, port);
          },
        ),
      ]),
      child: Column(children: [
        _StatusRow(
          label: _statusData != null
              ? 'Backend REST: Conectado'
              : 'Backend REST: Sin conexión',
          color: _statusData != null ? c.eventClean : c.eventDeleted,
        ),
        Divider(height: 1, color: c.border),
        _StatusRow(
          label: _statusData != null
              ? 'WebSocket: Disponible'
              : 'WebSocket: Error (ver logs)',
          color: _statusData != null ? c.eventClean : c.eventDeleted,
        ),
        if (_statusData != null) ...[
          Divider(height: 1, color: c.border),
          _InfoRow(
              label: 'Servidor',
              value: _statusData!['hostname']?.toString() ?? '—'),
          Divider(height: 1, color: c.border),
          _InfoRow(
              label: 'Último escaneo',
              value: _formatTs(_statusData!['ultimoScan']?.toString())),
          Divider(height: 1, color: c.border),
          _InfoRow(
              label: 'Escaneos / Eventos',
              value:
                  '${_statusData!['scans'] ?? 0} / ${_statusData!['events'] ?? 0}'),
        ],
      ]),
    );
  }

  // ── Conexión al backend ────────────────────────────────────────────────────

  Widget _buildBackendSection() {
    final c = context.fimColors;
    return _Card(
      title: 'Conexión al backend',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(children: [
          Row(children: [
            Expanded(
                flex: 5,
                child: _Field(
                    label: 'Host / IP',
                    ctrl: _hostCtrl,
                    hint: '192.168.1.100')),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: _Field(
                    label: 'Puerto',
                    ctrl: _portCtrl,
                    hint: '8080',
                    keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _saving ? null : _saveBackend,
              child: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.onPrimary))
                  : Text('Guardar y reconectar',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: c.onPrimary)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Directorios monitorizados ──────────────────────────────────────────────

  Widget _buildRulesSection() {
    final c = context.fimColors;
    return _Card(
      title: 'Directorios monitorizados',
      action: IconButton(
        icon: Icon(Icons.add, size: 16, color: c.primary),
        onPressed: () => _showAddDialog(),
      ),
      child: _rulesLoading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: c.primary)))
          : _rulesError != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_rulesError!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: c.eventDeleted)))
              : _rules.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                          child: Text(
                              'Sin reglas. Pulsa + para añadir un directorio.',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: c.textSecondary),
                              textAlign: TextAlign.center)))
                  : Column(
                      children: _rules
                          .map((r) => _RuleTile(
                                rule: r,
                                onDelete: () => _confirmDelete(r),
                                onChangeSev: (sev) => _updateRule(r.id, sev),
                              ))
                          .toList()),
    );
  }

  // ── Intervalo de escaneo ───────────────────────────────────────────────────

  Widget _buildIntervalSection() {
    final c = context.fimColors;
    const options = [1, 5, 15, 30, 60];
    return _Card(
      title: 'Intervalo de escaneo',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 8,
              children: options.map((m) {
                final sel = _scanInterval == m;
                return ChoiceChip(
                  label: Text(m == 60 ? '1 h' : '$m min'),
                  selected: sel,
                  selectedColor: c.primary.withOpacity(0.12),
                  labelStyle: AppTextStyles.bodySmall
                      .copyWith(color: sel ? c.primary : c.textSecondary),
                  side: BorderSide(color: sel ? c.primary : c.border),
                  onSelected: (_) => _saveInterval(m),
                );
              }).toList()),
          const SizedBox(height: 6),
          Text(
              'El agente comprobará cambios cada $_scanInterval '
              '${_scanInterval == 60 ? 'hora' : 'minutos'}.',
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
        ]),
      ),
    );
  }

  // ── Severidad mínima ───────────────────────────────────────────────────────

  Widget _buildSeveritySection() {
    final c = context.fimColors;
    const opts = ['ALTA', 'MEDIA', 'BAJA'];
    return _Card(
      title: 'Severidad mínima visible',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 8,
              children: opts.map((s) {
                final sel = _minSeverity == s;
                final col = severityColorFrom(s, c);
                return ChoiceChip(
                  label: Text(s),
                  selected: sel,
                  selectedColor: col.withOpacity(0.12),
                  labelStyle: AppTextStyles.bodySmall
                      .copyWith(color: sel ? col : c.textSecondary),
                  side: BorderSide(color: sel ? col : c.border),
                  onSelected: (_) {
                    setState(() => _minSeverity = s);
                    _savePref(_kMinSeverity, s);
                  },
                );
              }).toList()),
          const SizedBox(height: 6),
          Text(
              'Solo se mostrarán alertas de severidad $_minSeverity o superior.',
              style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
        ]),
      ),
    );
  }

  // ── Apariencia ─────────────────────────────────────────────────────────────

  Widget _buildAppearanceSection() {
    final c = context.fimColors;
    return _Card(
      title: 'Apariencia',
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) => Column(children: [
          _ToggleRow(
            label: 'Tema oscuro',
            subtitle: themeState.isDark
                ? 'Interfaz oscura (estilo terminal)'
                : 'Interfaz clara (slate azulado)',
            value: themeState.isDark,
            leading: Icon(
              themeState.isDark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              size: 16,
              color: themeState.isDark ? c.primary : c.accent,
            ),
            onChanged: (_) =>
                context.read<ThemeBloc>().add(const ThemeToggled()),
          ),
        ]),
      ),
    );
  }

  // ── Visualización ──────────────────────────────────────────────────────────

  Widget _buildVisualizationSection() {
    final c = context.fimColors;
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
        Divider(height: 1, color: c.border),
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
    final c = context.fimColors;
    return _Card(
      title: 'Acerca de',
      child: Column(children: [
        _InfoRow(label: 'Versión', value: '1.0.0-beta'),
        Divider(height: 1, color: c.border),
        _InfoRow(label: 'Autor', value: 'Ángel Maroto García'),
        Divider(height: 1, color: c.border),
        _InfoRow(label: 'Proyecto', value: 'TFG DAM · IFC02S · 2025-2026'),
        Divider(height: 1, color: c.border),
        _InfoRow(
            label: 'Stack',
            value: 'Flutter · Spring Boot · SQLite · AIDE',
            mono: true),
      ]),
    );
  }

  // ── Diálogos ───────────────────────────────────────────────────────────────

  void _showAddDialog() {
    final c = context.fimColors;
    final ctrl = TextEditingController();
    String sev = 'MEDIA';

    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: c.border)),
          title: Text('Añadir directorio',
              style: AppTextStyles.titleMedium.copyWith(color: c.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: AppTextStyles.path.copyWith(color: c.textPrimary),
              decoration: InputDecoration(
                labelText: 'Ruta del directorio',
                labelStyle:
                    AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
                hintText: '/etc/ssh',
                hintStyle:
                    AppTextStyles.bodySmall.copyWith(color: c.textDisabled),
                filled: true,
                fillColor: c.surfaceVariant,
                prefixIcon: Icon(Icons.folder_outlined,
                    size: 16, color: c.textSecondary),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: c.accent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Severidad',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: c.textSecondary))),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                children: ['ALTA', 'MEDIA', 'BAJA'].map((s) {
                  final col = severityColorFrom(s, c);
                  return ChoiceChip(
                    label: Text(s),
                    selected: sev == s,
                    selectedColor: col.withOpacity(0.12),
                    labelStyle: AppTextStyles.bodySmall
                        .copyWith(color: sev == s ? col : c.textSecondary),
                    side: BorderSide(color: sev == s ? col : c.border),
                    onSelected: (_) => setSt(() => sev = s),
                  );
                }).toList()),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary, foregroundColor: c.onPrimary),
              onPressed: () {
                final ruta = ctrl.text.trim();
                if (ruta.isEmpty) return;
                Navigator.pop(ctx);
                _addRule(ruta, sev);
              },
              child: Text('Añadir',
                  style: AppTextStyles.bodySmall.copyWith(color: c.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(_ConfigRule rule) {
    final c = context.fimColors;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: c.border)),
        title: Text('Eliminar regla',
            style: AppTextStyles.titleMedium.copyWith(color: c.textPrimary)),
        content: Text('¿Eliminar la regla para "${rule.ruta}"?',
            style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style:
                    AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: c.eventDeleted, foregroundColor: c.onPrimary),
            onPressed: () {
              Navigator.pop(context);
              _deleteRule(rule.id);
            },
            child: Text('Eliminar',
                style: AppTextStyles.bodySmall.copyWith(color: c.onPrimary)),
          ),
        ],
      ),
    );
  }

  String _formatTs(String? ts) {
    if (ts == null || ts == 'Sin escaneos') return 'Sin escaneos';
    try {
      final dt = DateTime.parse(ts);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
          '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares — todos usan context.fimColors
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _Card({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(
                child: Text(title,
                    style:
                        AppTextStyles.titleMedium.copyWith(color: c.primary))),
            if (action != null) action!,
          ]),
        ),
        Divider(height: 1, color: c.border),
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
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label,
            style: AppTextStyles.bodySmall.copyWith(color: c.textPrimary)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool mono;
  const _InfoRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    AppTextStyles.bodySmall.copyWith(color: c.textSecondary))),
        Text(value,
            style: mono
                ? AppTextStyles.path.copyWith(color: c.textPrimary)
                : AppTextStyles.bodySmall.copyWith(color: c.textPrimary)),
      ]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return SwitchListTile(
      secondary: leading,
      title: Text(label,
          style: AppTextStyles.bodySmall.copyWith(color: c.textPrimary)),
      subtitle: Text(subtitle,
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
      value: value,
      activeColor: c.primary,
      onChanged: onChanged,
    );
  }
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final TextInputType keyboard;
  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: AppTextStyles.path.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodySmall.copyWith(color: c.textDisabled),
          filled: true,
          fillColor: c.surfaceVariant,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.accent, width: 1.5)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.border)),
        ),
      ),
    ]);
  }
}

class _RuleTile extends StatelessWidget {
  final _ConfigRule rule;
  final VoidCallback onDelete;
  final ValueChanged<String> onChangeSev;
  const _RuleTile(
      {required this.rule, required this.onDelete, required this.onChangeSev});

  @override
  Widget build(BuildContext context) {
    final c = context.fimColors;
    final sevColor = severityColorFrom(rule.nivelSeveridad, c);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(Icons.folder_outlined, size: 14, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(rule.ruta,
                  style: AppTextStyles.path.copyWith(color: c.textPrimary))),
          PopupMenuButton<String>(
            initialValue: rule.nivelSeveridad,
            color: c.surfaceVariant,
            onSelected: onChangeSev,
            itemBuilder: (_) => ['ALTA', 'MEDIA', 'BAJA'].map((s) {
              final sc = severityColorFrom(s, c);
              return PopupMenuItem(
                value: s,
                child:
                    Text(s, style: AppTextStyles.bodySmall.copyWith(color: sc)),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: sevColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
                color: sevColor.withOpacity(0.1),
              ),
              child: Text(rule.nivelSeveridad,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: sevColor, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 14, color: c.eventDeleted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ]),
      ),
      Divider(height: 1, color: c.border),
    ]);
  }
}
