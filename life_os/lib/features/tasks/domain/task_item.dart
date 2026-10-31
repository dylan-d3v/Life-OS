/// Modelo de dominio que representa una tarea en Life-OS.
///
/// Los campos sensibles ([title], [notes]) se cifran localmente antes de
/// persistirse en Supabase; los metadatos operativos ([status], [priority],
/// [dueDate]) se almacenan en claro para permitir filtros y ordenamiento
/// en la base de datos.
class TaskItem {
  final String id;
  final String? projectId;
  final String title;
  final String notes;
  final TaskStatus status;
  final int priority; // 1=Baja, 2=Media, 3=Alta, 4=Urgente
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const TaskItem({
    required this.id,
    this.projectId,
    required this.title,
    this.notes = '',
    this.status = TaskStatus.todo,
    this.priority = 2,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Crea una copia de la tarea con los campos proporcionados reemplazados.
  TaskItem copyWith({
    String? id,
    String? projectId,
    String? title,
    String? notes,
    TaskStatus? status,
    int? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Retorna un mapa con los campos sensibles que deben cifrarse antes de
  /// ser enviados a Supabase. **Nunca** salen en claro del dispositivo.
  Map<String, dynamic> toEncryptedFieldsMap() {
    return {
      'title': title,
      'notes': notes,
    };
  }

  /// Reconstruye un [TaskItem] combinando los metadatos en claro de la fila
  /// de Supabase con los campos sensibles ya descifrados.
  factory TaskItem.fromDecryptedMap({
    required Map<String, dynamic> row,
    required Map<String, dynamic> decryptedFields,
  }) {
    return TaskItem(
      id: row['id'] as String,
      projectId: row['project_id'] as String?,
      title: decryptedFields['title'] as String? ?? '',
      notes: decryptedFields['notes'] as String? ?? '',
      status: TaskStatus.fromString(row['status'] as String),
      priority: row['priority'] as int? ?? 2,
      dueDate: row['due_date'] != null
          ? DateTime.parse(row['due_date'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }
}

/// Estados posibles de una tarea, alineados con el CHECK constraint de la
/// columna `status` en la tabla `tasks` de Supabase.
enum TaskStatus {
  todo('todo', 'Pendiente'),
  inProgress('in_progress', 'En progreso'),
  done('done', 'Completada'),
  cancelled('cancelled', 'Cancelada');

  const TaskStatus(this.value, this.label);

  /// Valor almacenado en la columna `status` de la base de datos.
  final String value;

  /// Etiqueta legible para la interfaz de usuario.
  final String label;

  /// Parsea el valor de la base de datos al enum correspondiente.
  factory TaskStatus.fromString(String value) {
    return TaskStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => TaskStatus.todo,
    );
  }
}

