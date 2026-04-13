// lib/data/models/alert_model.dart
import 'package:json_annotation/json_annotation.dart';

part 'alert_model.g.dart';

@JsonSerializable()
class AlertModel {
  final int id;
  final int? scanId;
  final int? fileEntryId;
  final int? configRulesId;
  final String tipoCambio;
  final String severidad;
  final String? hashAnterior;
  final String? rutaArchivo;
  final String? hashActual;
  final String? permisos;
  final int? tamano;
  final String? fechaEjecucion;

  const AlertModel({
    required this.id,
    this.scanId,
    this.fileEntryId,
    this.configRulesId,
    required this.tipoCambio,
    required this.severidad,
    this.hashAnterior,
    this.rutaArchivo,
    this.hashActual,
    this.permisos,
    this.tamano,
    this.fechaEjecucion,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final scanObj = json['scan'];
    String? fechaEj = json['fechaEjecucion'] as String?;
    if (fechaEj == null && scanObj is Map) {
      fechaEj = scanObj['fechaEjecucion'] as String?;
    }
    return AlertModel(
      id: (json['id'] as num).toInt(),
      scanId: scanObj is Map ? (scanObj['id'] as num?)?.toInt() : null,
      fileEntryId: null,
      configRulesId: null,
      tipoCambio: (json['tipoCambio'] ?? 'CLEAN') as String,
      severidad: (json['severidad'] ?? 'BAJA') as String,
      hashAnterior: json['hashAnterior'] as String?,
      rutaArchivo: json['rutaArchivo'] as String?,
      hashActual: json['hashActual'] as String?,
      permisos: json['permisos'] as String?,
      tamano: (json['tamano'] as num?)?.toInt(),
      fechaEjecucion: fechaEj,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipoCambio': tipoCambio,
        'severidad': severidad,
        if (rutaArchivo != null) 'rutaArchivo': rutaArchivo,
        if (hashActual != null) 'hashActual': hashActual,
        if (hashAnterior != null) 'hashAnterior': hashAnterior,
        if (permisos != null) 'permisos': permisos,
        if (tamano != null) 'tamano': tamano,
        if (fechaEjecucion != null) 'fechaEjecucion': fechaEjecucion,
      };
}
