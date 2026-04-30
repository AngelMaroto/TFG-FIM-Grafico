// lib/data/models/config_rule_model.dart

class ConfigRuleModel {
  final int? id;
  final String ruta;
  final String nivelSeveridad;

  const ConfigRuleModel({
    this.id,
    required this.ruta,
    required this.nivelSeveridad,
  });

  factory ConfigRuleModel.fromJson(Map<String, dynamic> json) {
    return ConfigRuleModel(
      id: json['id'] as int?,
      ruta: json['ruta'] as String? ?? '',
      nivelSeveridad: json['nivelSeveridad'] as String? ?? 'MEDIA',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'ruta': ruta,
        'nivelSeveridad': nivelSeveridad,
      };

  ConfigRuleModel copyWith({
    int? id,
    String? ruta,
    String? nivelSeveridad,
  }) =>
      ConfigRuleModel(
        id: id ?? this.id,
        ruta: ruta ?? this.ruta,
        nivelSeveridad: nivelSeveridad ?? this.nivelSeveridad,
      );

  @override
  bool operator ==(Object other) =>
      other is ConfigRuleModel && other.id == id && other.ruta == ruta;

  @override
  int get hashCode => Object.hash(id, ruta);
}
