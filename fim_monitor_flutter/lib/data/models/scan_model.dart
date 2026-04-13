// lib/data/models/scan_model.dart
import 'package:json_annotation/json_annotation.dart';

part 'scan_model.g.dart';

@JsonSerializable()
class ScanModel {
  final int id;
  @JsonKey(name: 'fecha_ejecucion')
  final String fechaEjecucion;
  final String hostname;
  @JsonKey(name: 'resumen_cambios')
  final String? resumenCambios;

  const ScanModel({
    required this.id,
    required this.fechaEjecucion,
    required this.hostname,
    this.resumenCambios,
  });

  factory ScanModel.fromJson(Map<String, dynamic> json) =>
      _$ScanModelFromJson(json);

  Map<String, dynamic> toJson() => _$ScanModelToJson(this);
}

// ────────────────────────────────────────────────────────────────────────────

// lib/data/models/file_entry_model.dart
// (en el mismo fichero por brevedad, se puede separar)

@JsonSerializable()
class FileEntryModel {
  final int id;
  @JsonKey(name: 'scan_id')
  final int scanId;
  @JsonKey(name: 'ruta_archivo')
  final String rutaArchivo;
  @JsonKey(name: 'hash_actual')
  final String? hashActual;
  @JsonKey(name: 'tamano')
  final int? tamano;
  final String? permisos;
  @JsonKey(name: 'nombre_archivo')
  final String nombreArchivo;

  const FileEntryModel({
    required this.id,
    required this.scanId,
    required this.rutaArchivo,
    this.hashActual,
    this.tamano,
    this.permisos,
    required this.nombreArchivo,
  });

  factory FileEntryModel.fromJson(Map<String, dynamic> json) =>
      _$FileEntryModelFromJson(json);

  Map<String, dynamic> toJson() => _$FileEntryModelToJson(this);
}
