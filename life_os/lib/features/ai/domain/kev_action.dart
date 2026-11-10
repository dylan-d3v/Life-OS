import '../../finance/domain/finance_transaction_item.dart';
import '../../projects/domain/project_item.dart';

/// Clase base sellada que representa cualquier acción intencionada por el usuario
/// e interpretada de forma estrictamente tipada por el motor de IA Kev.
sealed class KevAction {
  const KevAction();

  /// Identificador textual de la acción correspondiente al tool call del LLM.
  String get actionName;

  /// Serializa la acción en un mapa JSON estándar.
  Map<String, dynamic> toJson();

  /// Reconstruye una [KevAction] a partir de una llamada a herramienta (Tool Call)
  /// emitida por el LLM en formato Function Calling de OpenAI / Groq.
  factory KevAction.fromToolCall(String name, Map<String, dynamic> arguments) {
    try {
      switch (name) {
        case 'create_task':
          return CreateTaskAction.fromMap(arguments);
        case 'update_task':
          return UpdateTaskAction.fromMap(arguments);
        case 'delete_task':
          return DeleteTaskAction.fromMap(arguments);
        case 'create_note':
          return CreateNoteAction.fromMap(arguments);
        case 'update_note':
          return UpdateNoteAction.fromMap(arguments);
        case 'delete_note':
          return DeleteNoteAction.fromMap(arguments);
        case 'create_project':
          return CreateProjectAction.fromMap(arguments);
        case 'update_project':
          return UpdateProjectAction.fromMap(arguments);
        case 'delete_project':
          return DeleteProjectAction.fromMap(arguments);
        case 'create_calendar_event':
          return CreateCalendarEventAction.fromMap(arguments);
        case 'update_calendar_event':
          return UpdateCalendarEventAction.fromMap(arguments);
        case 'delete_calendar_event':
          return DeleteCalendarEventAction.fromMap(arguments);
        case 'log_finance':
          return LogFinanceAction.fromMap(arguments);
        case 'query_summary':
          return QueryAction.fromMap(arguments);
        default:
          return UnknownAction(
            rawName: name,
            rawArguments: arguments,
            reason: 'Acción no reconocida en el catálogo de herramientas de Kev.',
          );
      }
    } catch (e) {
      return UnknownAction(
        rawName: name,
        rawArguments: arguments,
        reason: 'Error al deserializar parámetros: $e',
      );
    }
  }

  /// Reconstruye una [KevAction] desde un JSON con estructura `{"action": "...", "parameters": {...}}`.
  factory KevAction.fromJson(Map<String, dynamic> json) {
    final action = json['action'] as String? ?? 'unknown';
    final params = json['parameters'] as Map<String, dynamic>? ?? const {};
    return KevAction.fromToolCall(action, params);
  }
}

// =============================================================================
// 1. Acción: Crear Tarea
// =============================================================================

class CreateTaskAction extends KevAction {
  final String title;
  final String notes;
  final int priority; // 1=Baja, 2=Media, 3=Alta, 4=Urgente
  final DateTime? dueDate;
  final String? projectName;

  const CreateTaskAction({
    required this.title,
    this.notes = '',
    this.priority = 2,
    this.dueDate,
    this.projectName,
  });

  @override
  String get actionName => 'create_task';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'title': title,
        'notes': notes,
        'priority': priority,
        'due_date': ?dueDate?.toIso8601String(),
        'project_name': ?projectName,
      },
    };
  }

  factory CreateTaskAction.fromMap(Map<String, dynamic> map) {
    final title = map['title']?.toString().trim() ?? '';
    if (title.isEmpty) {
      throw const FormatException('El título de la tarea es requerido.');
    }

    final rawPriority = map['priority'];
    int priority = 2;
    if (rawPriority is num) {
      priority = rawPriority.toInt().clamp(1, 4);
    } else if (rawPriority is String) {
      priority = (int.tryParse(rawPriority) ?? 2).clamp(1, 4);
    }

    DateTime? dueDate;
    final rawDue = map['due_date']?.toString();
    if (rawDue != null && rawDue.isNotEmpty) {
      dueDate = DateTime.tryParse(rawDue);
    }

    return CreateTaskAction(
      title: title,
      notes: map['notes']?.toString().trim() ?? '',
      priority: priority,
      dueDate: dueDate,
      projectName: map['project_name']?.toString().trim(),
    );
  }
}

// =============================================================================
// 2. Acción: Crear Nota
// =============================================================================

class CreateNoteAction extends KevAction {
  final String title;
  final String content;
  final List<String> tags;
  final bool isPinned;
  final String? projectName;

  const CreateNoteAction({
    required this.title,
    this.content = '',
    this.tags = const [],
    this.isPinned = false,
    this.projectName,
  });

  @override
  String get actionName => 'create_note';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'title': title,
        'content': content,
        'tags': tags,
        'is_pinned': isPinned,
        'project_name': ?projectName,
      },
    };
  }

  factory CreateNoteAction.fromMap(Map<String, dynamic> map) {
    final title = map['title']?.toString().trim() ?? '';
    final content = map['content']?.toString().trim() ?? '';
    if (title.isEmpty && content.isEmpty) {
      throw const FormatException('La nota debe tener al menos título o contenido.');
    }

    final rawTags = map['tags'];
    final List<String> parsedTags;
    if (rawTags is List) {
      parsedTags = rawTags
          .map((t) => t.toString().trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .toList();
    } else if (rawTags is String) {
      parsedTags = rawTags
          .split(',')
          .map((t) => t.trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .toList();
    } else {
      parsedTags = const [];
    }

    final isPinned = map['is_pinned'] == true ||
        map['is_pinned']?.toString().toLowerCase() == 'true';

    return CreateNoteAction(
      title: title.isNotEmpty ? title : 'Nota rápida',
      content: content,
      tags: parsedTags,
      isPinned: isPinned,
      projectName: map['project_name']?.toString().trim(),
    );
  }
}

// =============================================================================
// 3. Acción: Crear Proyecto
// =============================================================================

class CreateProjectAction extends KevAction {
  final String name;
  final String description;
  final String colorHex;
  final ProjectStatus status;

  const CreateProjectAction({
    required this.name,
    this.description = '',
    this.colorHex = '#0284C7',
    this.status = ProjectStatus.active,
  });

  @override
  String get actionName => 'create_project';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'name': name,
        'description': description,
        'color_hex': colorHex,
        'status': status.value,
      },
    };
  }

  factory CreateProjectAction.fromMap(Map<String, dynamic> map) {
    final name = map['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      throw const FormatException('El nombre del proyecto es requerido.');
    }

    final rawStatus = map['status']?.toString() ?? 'active';

    return CreateProjectAction(
      name: name,
      description: map['description']?.toString().trim() ?? '',
      colorHex: map['color_hex']?.toString().trim() ?? '#0284C7',
      status: ProjectStatus.fromString(rawStatus),
    );
  }
}

// =============================================================================
// 4. Acción: Crear Evento de Calendario
// =============================================================================

class CreateCalendarEventAction extends KevAction {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String location;
  final String category;
  final String description;

  const CreateCalendarEventAction({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.location = '',
    this.category = 'Personal',
    this.description = '',
  });

  @override
  String get actionName => 'create_calendar_event';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'title': title,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_all_day': isAllDay,
        'location': location,
        'category': category,
        'description': description,
      },
    };
  }

  factory CreateCalendarEventAction.fromMap(Map<String, dynamic> map) {
    final title = map['title']?.toString().trim() ?? '';
    if (title.isEmpty) {
      throw const FormatException('El título del evento es requerido.');
    }

    final rawStart = map['start_time']?.toString();
    final startTime = rawStart != null ? DateTime.tryParse(rawStart) : null;
    if (startTime == null) {
      throw const FormatException('La fecha y hora de inicio son requeridas.');
    }

    final rawEnd = map['end_time']?.toString();
    DateTime endTime;
    if (rawEnd != null && rawEnd.isNotEmpty) {
      endTime = DateTime.tryParse(rawEnd) ?? startTime.add(const Duration(hours: 1));
    } else {
      endTime = startTime.add(const Duration(hours: 1));
    }

    if (endTime.isBefore(startTime)) {
      endTime = startTime.add(const Duration(hours: 1));
    }

    final isAllDay = map['is_all_day'] == true ||
        map['is_all_day']?.toString().toLowerCase() == 'true';

    final rawCat = map['category']?.toString().trim() ?? '';
    final category = rawCat.isNotEmpty ? rawCat : 'Personal';

    return CreateCalendarEventAction(
      title: title,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      location: map['location']?.toString().trim() ?? '',
      category: category,
      description: map['description']?.toString().trim() ?? '',
    );
  }
}

// =============================================================================
// 5. Acción: Registrar Transacción Financiera
// =============================================================================

class LogFinanceAction extends KevAction {
  final TransactionType type;
  final double amount;
  final String currency;
  final String category;
  final String notes;
  final DateTime transactionDate;

  const LogFinanceAction({
    required this.type,
    required this.amount,
    this.currency = 'USD',
    this.category = 'General',
    this.notes = '',
    required this.transactionDate,
  });

  @override
  String get actionName => 'log_finance';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'type': type.value,
        'amount': amount,
        'currency': currency,
        'category': category,
        'notes': notes,
        'transaction_date': transactionDate.toIso8601String(),
      },
    };
  }

  factory LogFinanceAction.fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    double? parsedAmount;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      parsedAmount = double.tryParse(rawAmount.replaceAll(',', '.'));
    }

    if (parsedAmount == null || parsedAmount <= 0) {
      throw const FormatException('El monto financiero debe ser un número positivo.');
    }

    final rawType = map['type']?.toString().toLowerCase() ?? 'expense';
    final type = switch (rawType) {
      'income' || 'ingreso' => TransactionType.income,
      'transfer' || 'transferencia' => TransactionType.transfer,
      _ => TransactionType.expense,
    };

    final rawDate = map['transaction_date']?.toString();
    final transactionDate =
        rawDate != null ? (DateTime.tryParse(rawDate) ?? DateTime.now()) : DateTime.now();

    return LogFinanceAction(
      type: type,
      amount: parsedAmount,
      currency: map['currency']?.toString().trim().toUpperCase() ?? 'USD',
      category: map['category']?.toString().trim() ?? 'General',
      notes: map['notes']?.toString().trim() ?? '',
      transactionDate: transactionDate,
    );
  }
}

// =============================================================================
// 6. Acción: Consulta / Resumen
// =============================================================================

class QueryAction extends KevAction {
  final String queryTopic; // 'daily_briefing', 'tasks_summary', 'finance_summary'
  final DateTime targetDate;

  const QueryAction({
    this.queryTopic = 'daily_briefing',
    required this.targetDate,
  });

  @override
  String get actionName => 'query_summary';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'query_topic': queryTopic,
        'target_date': targetDate.toIso8601String(),
      },
    };
  }

  factory QueryAction.fromMap(Map<String, dynamic> map) {
    final rawTopic = map['query_topic']?.toString().trim() ?? 'daily_briefing';
    final rawDate = map['target_date']?.toString();
    final targetDate =
        rawDate != null ? (DateTime.tryParse(rawDate) ?? DateTime.now()) : DateTime.now();

    return QueryAction(
      queryTopic: rawTopic,
      targetDate: targetDate,
    );
  }
}

// =============================================================================
// 7. Acción: Desconocida / Fallback
// =============================================================================

class UnknownAction extends KevAction {
  final String rawName;
  final Map<String, dynamic> rawArguments;
  final String reason;

  const UnknownAction({
    required this.rawName,
    required this.rawArguments,
    required this.reason,
  });

  @override
  String get actionName => 'unknown';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'raw_name': rawName,
        'raw_arguments': rawArguments,
        'reason': reason,
      },
    };
  }
}

// =============================================================================
// 8. Acciones de Modificación y Eliminación (CRUD)
// =============================================================================

class UpdateTaskAction extends KevAction {
  final String query;
  final bool? isCompleted;
  final int? priority;
  final DateTime? dueDate;
  final String? newTitle;
  final String? notes;
  final String? projectName;

  const UpdateTaskAction({
    required this.query,
    this.isCompleted,
    this.priority,
    this.dueDate,
    this.newTitle,
    this.notes,
    this.projectName,
  });

  @override
  String get actionName => 'update_task';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'query': query,
        if (isCompleted != null) 'is_completed': isCompleted,
        if (priority != null) 'priority': priority,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
        if (newTitle != null) 'new_title': newTitle,
        if (notes != null) 'notes': notes,
        if (projectName != null) 'project_name': projectName,
      },
    };
  }

  factory UpdateTaskAction.fromMap(Map<String, dynamic> map) {
    final query = map['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      throw const FormatException(
          'El término de búsqueda (query) de la tarea es requerido.');
    }

    bool? isCompleted;
    if (map.containsKey('is_completed') && map['is_completed'] != null) {
      isCompleted = map['is_completed'] == true ||
          map['is_completed'].toString().toLowerCase() == 'true';
    }

    int? priority;
    if (map['priority'] != null) {
      final rawP = map['priority'];
      if (rawP is num) {
        priority = rawP.toInt().clamp(1, 4);
      } else if (rawP is String) {
        priority = int.tryParse(rawP)?.clamp(1, 4);
      }
    }

    DateTime? dueDate;
    final rawDue = map['due_date']?.toString();
    if (rawDue != null && rawDue.isNotEmpty) {
      dueDate = DateTime.tryParse(rawDue);
    }

    return UpdateTaskAction(
      query: query,
      isCompleted: isCompleted,
      priority: priority,
      dueDate: dueDate,
      newTitle: map['new_title']?.toString().trim(),
      notes: map['notes']?.toString().trim(),
      projectName: map['project_name']?.toString().trim(),
    );
  }
}

class DeleteTaskAction extends KevAction {
  final String query;

  const DeleteTaskAction({required this.query});

  @override
  String get actionName => 'delete_task';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {'query': query},
    };
  }

  factory DeleteTaskAction.fromMap(Map<String, dynamic> map) {
    final query = map['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      throw const FormatException(
          'El término de búsqueda de la tarea a eliminar es requerido.');
    }
    return DeleteTaskAction(query: query);
  }
}

class UpdateNoteAction extends KevAction {
  final String query;
  final bool? isPinned;
  final bool? isArchived;
  final String? newTitle;
  final String? appendContent;
  final String? projectName;

  const UpdateNoteAction({
    required this.query,
    this.isPinned,
    this.isArchived,
    this.newTitle,
    this.appendContent,
    this.projectName,
  });

  @override
  String get actionName => 'update_note';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'query': query,
        if (isPinned != null) 'is_pinned': isPinned,
        if (isArchived != null) 'is_archived': isArchived,
        if (newTitle != null) 'new_title': newTitle,
        if (appendContent != null) 'append_content': appendContent,
        if (projectName != null) 'project_name': projectName,
      },
    };
  }

  factory UpdateNoteAction.fromMap(Map<String, dynamic> map) {
    final query = map['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      throw const FormatException(
          'El término de búsqueda de la nota es requerido.');
    }

    bool? isPinned;
    if (map.containsKey('is_pinned') && map['is_pinned'] != null) {
      isPinned = map['is_pinned'] == true ||
          map['is_pinned'].toString().toLowerCase() == 'true';
    }

    bool? isArchived;
    if (map.containsKey('is_archived') && map['is_archived'] != null) {
      isArchived = map['is_archived'] == true ||
          map['is_archived'].toString().toLowerCase() == 'true';
    }

    return UpdateNoteAction(
      query: query,
      isPinned: isPinned,
      isArchived: isArchived,
      newTitle: map['new_title']?.toString().trim(),
      appendContent: map['append_content']?.toString().trim(),
      projectName: map['project_name']?.toString().trim(),
    );
  }
}

class DeleteNoteAction extends KevAction {
  final String query;

  const DeleteNoteAction({required this.query});

  @override
  String get actionName => 'delete_note';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {'query': query},
    };
  }

  factory DeleteNoteAction.fromMap(Map<String, dynamic> map) {
    final query = map['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      throw const FormatException(
          'El término de búsqueda de la nota a eliminar es requerido.');
    }
    return DeleteNoteAction(query: query);
  }
}

class UpdateCalendarEventAction extends KevAction {
  final String query;
  final DateTime? newStartTime;
  final DateTime? newEndTime;
  final String? location;
  final String? category;
  final bool? isAllDay;
  final String? newTitle;

  const UpdateCalendarEventAction({
    required this.query,
    this.newStartTime,
    this.newEndTime,
    this.location,
    this.category,
    this.isAllDay,
    this.newTitle,
  });

  @override
  String get actionName => 'update_calendar_event';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'query': query,
        if (newStartTime != null)
          'new_start_time': newStartTime!.toIso8601String(),
        if (newEndTime != null) 'new_end_time': newEndTime!.toIso8601String(),
        if (location != null) 'location': location,
        if (category != null) 'category': category,
        if (isAllDay != null) 'is_all_day': isAllDay,
        if (newTitle != null) 'new_title': newTitle,
      },
    };
  }

  factory UpdateCalendarEventAction.fromMap(Map<String, dynamic> map) {
    final query = map['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      throw const FormatException(
          'El término de búsqueda del evento es requerido.');
    }

    DateTime? newStart;
    final rawStart = map['new_start_time']?.toString();
    if (rawStart != null && rawStart.isNotEmpty) {
      newStart = DateTime.tryParse(rawStart);
    }

    DateTime? newEnd;
    final rawEnd = map['new_end_time']?.toString();
    if (rawEnd != null && rawEnd.isNotEmpty) {
      newEnd = DateTime.tryParse(rawEnd);
    }

    bool? isAllDay;
    if (map.containsKey('is_all_day') && map['is_all_day'] != null) {
      isAllDay = map['is_all_day'] == true ||
          map['is_all_day'].toString().toLowerCase() == 'true';
    }

    return UpdateCalendarEventAction(
      query: query,
      newStartTime: newStart,
      newEndTime: newEnd,
      location: map['location']?.toString().trim(),
      category: map['category']?.toString().trim(),
      isAllDay: isAllDay,
      newTitle: map['new_title']?.toString().trim(),
    );
  }
}

class DeleteCalendarEventAction extends KevAction {
  final String query;

  const DeleteCalendarEventAction({required this.query});

  @override
  String get actionName => 'delete_calendar_event';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {'query': query},
    };
  }

  factory DeleteCalendarEventAction.fromMap(Map<String, dynamic> map) {
    final query = map['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      throw const FormatException(
          'El término de búsqueda del evento a eliminar es requerido.');
    }
    return DeleteCalendarEventAction(query: query);
  }
}

class UpdateProjectAction extends KevAction {
  final String query;
  final ProjectStatus? status;
  final String? colorHex;
  final String? description;
  final String? newName;

  const UpdateProjectAction({
    required this.query,
    this.status,
    this.colorHex,
    this.description,
    this.newName,
  });

  @override
  String get actionName => 'update_project';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {
        'query': query,
        if (status != null) 'status': status!.value,
        if (colorHex != null) 'color_hex': colorHex,
        if (description != null) 'description': description,
        if (newName != null) 'new_name': newName,
      },
    };
  }

  factory UpdateProjectAction.fromMap(Map<String, dynamic> map) {
    final query = map['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      throw const FormatException(
          'El nombre del proyecto a modificar es requerido.');
    }

    ProjectStatus? status;
    final rawStatus = map['status']?.toString();
    if (rawStatus != null && rawStatus.isNotEmpty) {
      status = ProjectStatus.fromString(rawStatus);
    }

    return UpdateProjectAction(
      query: query,
      status: status,
      colorHex: map['color_hex']?.toString().trim(),
      description: map['description']?.toString().trim(),
      newName: map['new_name']?.toString().trim(),
    );
  }
}

class DeleteProjectAction extends KevAction {
  final String query;

  const DeleteProjectAction({required this.query});

  @override
  String get actionName => 'delete_project';

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionName,
      'parameters': {'query': query},
    };
  }

  factory DeleteProjectAction.fromMap(Map<String, dynamic> map) {
    final query = map['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      throw const FormatException(
          'El nombre del proyecto a eliminar es requerido.');
    }
    return DeleteProjectAction(query: query);
  }
}
