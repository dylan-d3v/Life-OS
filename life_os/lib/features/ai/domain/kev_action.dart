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
        case 'create_note':
          return CreateNoteAction.fromMap(arguments);
        case 'create_project':
          return CreateProjectAction.fromMap(arguments);
        case 'create_calendar_event':
          return CreateCalendarEventAction.fromMap(arguments);
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

  const CreateNoteAction({
    required this.title,
    this.content = '',
    this.tags = const [],
    this.isPinned = false,
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
  final String description;

  const CreateCalendarEventAction({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.location = '',
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

    return CreateCalendarEventAction(
      title: title,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      location: map['location']?.toString().trim() ?? '',
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
