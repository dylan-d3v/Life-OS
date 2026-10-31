/// Modelo de dominio que representa un Evento de Calendario en Life-OS.
///
/// La información confidencial ([title], [description], [location]) se cifra con
/// AES-256-GCM antes de enviarse a Supabase. Los tiempos ([startTime], [endTime],
/// [isAllDay]) se almacenan en claro para permitir filtros temporales y orden cronológico.
class CalendarEventItem {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String title;
  final String description;
  final String location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const CalendarEventItem({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    required this.title,
    this.description = '',
    this.location = '',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  CalendarEventItem copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? title,
    String? description,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return CalendarEventItem(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Retorna un mapa con los campos sensibles que deben cifrarse con AES-256-GCM.
  Map<String, dynamic> toEncryptedFieldsMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
    };
  }

  /// Reconstruye un [CalendarEventItem] combinando los metadatos temporales de Supabase
  /// con los datos descifrados en local.
  factory CalendarEventItem.fromDecryptedMap({
    required Map<String, dynamic> row,
    required Map<String, dynamic> decryptedFields,
  }) {
    return CalendarEventItem(
      id: row['id'] as String,
      startTime: DateTime.parse(row['start_time'] as String),
      endTime: DateTime.parse(row['end_time'] as String),
      isAllDay: row['is_all_day'] as bool? ?? false,
      title: decryptedFields['title'] as String? ?? '',
      description: decryptedFields['description'] as String? ?? '',
      location: decryptedFields['location'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }
}

