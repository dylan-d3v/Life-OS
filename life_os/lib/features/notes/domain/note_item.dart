/// Modelo de dominio que representa una nota o apunte en Life-OS.
///
/// Los datos sensibles ([title], [content], [tags]) se cifran con AES-256-GCM
/// antes de enviarse a Supabase. El estado de fijado ([isPinned]) y los metadatos
/// temporales se guardan en claro para permitir consultas rápidas y ordenamiento.
class NoteItem {
  final String id;
  final String? projectId;
  final bool isPinned;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const NoteItem({
    required this.id,
    this.projectId,
    this.isPinned = false,
    required this.title,
    this.content = '',
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Clona la nota modificando únicamente los campos deseados.
  NoteItem copyWith({
    String? id,
    String? projectId,
    bool? isPinned,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      isPinned: isPinned ?? this.isPinned,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Retorna un mapa con los campos sensibles que se deben cifrar con AES-256-GCM.
  Map<String, dynamic> toEncryptedFieldsMap() {
    return {
      'title': title,
      'content': content,
      'tags': tags,
    };
  }

  /// Reconstruye una [NoteItem] combinando los metadatos en claro de Supabase
  /// con el contenido descifrado localmente.
  factory NoteItem.fromDecryptedMap({
    required Map<String, dynamic> row,
    required Map<String, dynamic> decryptedFields,
  }) {
    final rawTags = decryptedFields['tags'];
    final List<String> parsedTags;
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    } else {
      parsedTags = const [];
    }

    return NoteItem(
      id: row['id'] as String,
      projectId: row['project_id'] as String?,
      isPinned: row['is_pinned'] as bool? ?? false,
      title: decryptedFields['title'] as String? ?? '',
      content: decryptedFields['content'] as String? ?? '',
      tags: parsedTags,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }
}

