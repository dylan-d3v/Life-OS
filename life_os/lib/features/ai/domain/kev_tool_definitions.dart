/// Catálogo formal de especificaciones de herramientas (Tool Definitions)
/// en el formato estándar de llamadas a funciones de OpenAI / Groq.
///
/// Estas definiciones se inyectan en el parámetro `tools` de la API de inferencia
/// para forzar respuestas estrictamente tipadas y prevenir alucinaciones de texto libre.
class KevToolDefinitions {
  const KevToolDefinitions._();

  static const List<Map<String, dynamic>> allTools = [
    createTaskTool,
    createNoteTool,
    createProjectTool,
    createCalendarEventTool,
    logFinanceTool,
    querySummaryTool,
  ];

  // 1. Tool: create_task
  static const Map<String, dynamic> createTaskTool = {
    'type': 'function',
    'function': {
      'name': 'create_task',
      'description':
          'Crea una nueva tarea o pendiente en Life-OS con prioridad y fecha límite opcional.',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Título conciso y claro de la tarea.',
          },
          'notes': {
            'type': 'string',
            'description': 'Detalles, contexto o pasos adicionales para completar la tarea.',
          },
          'priority': {
            'type': 'integer',
            'enum': [1, 2, 3, 4],
            'description':
                'Nivel de prioridad: 1=Baja, 2=Media (por defecto), 3=Alta, 4=Urgente.',
          },
          'due_date': {
            'type': 'string',
            'description':
                'Fecha y hora límite en formato ISO 8601 (ej: 2026-11-05T18:00:00Z).',
          },
          'project_name': {
            'type': 'string',
            'description': 'Nombre del proyecto al que pertenece la tarea si se menciona.',
          },
        },
        'required': ['title'],
      },
    },
  };

  // 2. Tool: create_note
  static const Map<String, dynamic> createNoteTool = {
    'type': 'function',
    'function': {
      'name': 'create_note',
      'description':
          'Guarda un apunte, idea, resumen o conocimiento personal con etiquetas opcionales.',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Título o tema principal de la nota.',
          },
          'content': {
            'type': 'string',
            'description': 'Cuerpo completo de la nota o apunte en texto plano o markdown.',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Lista de palabras clave o etiquetas temáticas (ej: ["hardware", "esp32"]).',
          },
          'is_pinned': {
            'type': 'boolean',
            'description': 'Si la nota debe fijarse al inicio por ser de alta relevancia.',
          },
        },
        'required': ['title'],
      },
    },
  };

  // 3. Tool: create_project
  static const Map<String, dynamic> createProjectTool = {
    'type': 'function',
    'function': {
      'name': 'create_project',
      'description':
          'Crea un nuevo proyecto o meta que agrupará tareas y notas relacionadas.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Nombre representativo de la iniciativa o proyecto.',
          },
          'description': {
            'type': 'string',
            'description': 'Objetivo general o alcance del proyecto.',
          },
          'color_hex': {
            'type': 'string',
            'description': 'Color hexadecimal distintivo (ej: "#0284C7", "#10B981").',
          },
          'status': {
            'type': 'string',
            'enum': ['active', 'paused', 'completed', 'archived'],
            'description': 'Estado inicial del proyecto (por defecto "active").',
          },
        },
        'required': ['name'],
      },
    },
  };

  // 4. Tool: create_calendar_event
  static const Map<String, dynamic> createCalendarEventTool = {
    'type': 'function',
    'function': {
      'name': 'create_calendar_event',
      'description':
          'Programa una cita, reunión o evento en la agenda con fecha de inicio, fin y ubicación.',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Título o motivo del evento.',
          },
          'start_time': {
            'type': 'string',
            'description': 'Fecha y hora de inicio en formato ISO 8601.',
          },
          'end_time': {
            'type': 'string',
            'description': 'Fecha y hora de conclusión en formato ISO 8601.',
          },
          'is_all_day': {
            'type': 'boolean',
            'description': 'Indica si el evento dura todo el día sin horas fijas.',
          },
          'location': {
            'type': 'string',
            'description': 'Ubicación física, dirección o enlace de videollamada.',
          },
          'category': {
            'type': 'string',
            'enum': ['Personal', 'Trabajo', 'Estudios', 'Salud', 'Otro'],
            'description':
                'Categoría del evento: Personal (defecto), Trabajo, Estudios, Salud, Otro.',
          },
          'description': {
            'type': 'string',
            'description': 'Detalles adicionales de la reunión o agenda.',
          },
        },
        'required': ['title', 'start_time'],
      },
    },
  };

  // 5. Tool: log_finance
  static const Map<String, dynamic> logFinanceTool = {
    'type': 'function',
    'function': {
      'name': 'log_finance',
      'description':
          'Registra un movimiento financiero privado (gasto, ingreso o transferencia).',
      'parameters': {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['expense', 'income', 'transfer'],
            'description': 'Tipo de transacción: "expense" (gasto), "income" (ingreso) o "transfer".',
          },
          'amount': {
            'type': 'number',
            'description': 'Monto numérico positivo de la transacción (ej: 18.50).',
          },
          'currency': {
            'type': 'string',
            'description': 'Código de divisa (por defecto "USD").',
          },
          'category': {
            'type': 'string',
            'description': 'Categoría (ej: "Alimentación", "Transporte", "Servicios", "Salario").',
          },
          'notes': {
            'type': 'string',
            'description': 'Concepto o detalle de la compra o ingreso.',
          },
          'transaction_date': {
            'type': 'string',
            'description': 'Fecha de la transacción en formato ISO 8601 (por defecto actual).',
          },
        },
        'required': ['type', 'amount'],
      },
    },
  };

  // 6. Tool: query_summary
  static const Map<String, dynamic> querySummaryTool = {
    'type': 'function',
    'function': {
      'name': 'query_summary',
      'description':
          'Consulta un resumen inteligente de la jornada, tareas pendientes o balance financiero.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query_topic': {
            'type': 'string',
            'enum': ['daily_briefing', 'tasks_summary', 'finance_summary'],
            'description': 'Tema del resumen solicitado por el usuario.',
          },
          'target_date': {
            'type': 'string',
            'description': 'Fecha de referencia para la consulta en ISO 8601.',
          },
        },
      },
    },
  };
}

