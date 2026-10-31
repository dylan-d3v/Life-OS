/// Modelo de dominio que representa un Proyecto o Meta en Life-OS.
///
/// Los datos sensibles ([name], [description], [colorHex]) se cifran con AES-256-GCM
/// antes de persistirse en la tabla `projects` de Supabase. El estado operativo ([status])
/// y los metadatos temporales se guardan en claro para filtros rápidos.
class ProjectItem {
  final String id;
  final String name;
  final String description;
  final String colorHex;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const ProjectItem({
    required this.id,
    required this.name,
    this.description = '',
    this.colorHex = '#0284C7',
    this.status = ProjectStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  ProjectItem copyWith({
    String? id,
    String? name,
    String? description,
    String? colorHex,
    ProjectStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Retorna un mapa con los campos sensibles que deben cifrarse con AES-256-GCM.
  Map<String, dynamic> toEncryptedFieldsMap() {
    return {
      'name': name,
      'description': description,
      'color_hex': colorHex,
    };
  }

  /// Reconstruye un [ProjectItem] combinando los metadatos en claro de Supabase
  /// con los campos sensibles descifrados localmente.
  factory ProjectItem.fromDecryptedMap({
    required Map<String, dynamic> row,
    required Map<String, dynamic> decryptedFields,
  }) {
    return ProjectItem(
      id: row['id'] as String,
      name: decryptedFields['name'] as String? ?? '',
      description: decryptedFields['description'] as String? ?? '',
      colorHex: decryptedFields['color_hex'] as String? ?? '#0284C7',
      status: ProjectStatus.fromString(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }
}

/// Estados alineados con el CHECK constraint de la columna `status` en la tabla `projects`.
enum ProjectStatus {
  active('active', 'Activo'),
  paused('paused', 'Pausado'),
  completed('completed', 'Completado'),
  archived('archived', 'Archivado');

  const ProjectStatus(this.value, this.label);

  final String value;
  final String label;

  factory ProjectStatus.fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ProjectStatus.active,
    );
  }
}

