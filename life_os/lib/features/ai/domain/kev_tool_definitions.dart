/// Catálogo formal de especificaciones de herramientas (Tool Definitions)
/// en el formato estándar de llamadas a funciones de OpenAI / Groq.
///
/// Estas definiciones se inyectan en el parámetro `tools` de la API de inferencia
/// para forzar respuestas estrictamente tipadas y prevenir alucinaciones de texto libre.
class KevToolDefinitions {
  const KevToolDefinitions._();

  static const List<Map<String, dynamic>> allTools = [
    createTaskTool,
    updateTaskTool,
    deleteTaskTool,
    createNoteTool,
    updateNoteTool,
    deleteNoteTool,
    createProjectTool,
    updateProjectTool,
    deleteProjectTool,
    createCalendarEventTool,
    updateCalendarEventTool,
    deleteCalendarEventTool,
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
          'project_name': {
            'type': 'string',
            'description': 'Nombre del proyecto al que se asocia la nota si se menciona.',
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

  // 7. Tool: update_task
  static const Map<String, dynamic> updateTaskTool = {
    'type': 'function',
    'function': {
      'name': 'update_task',
      'description':
          'Actualiza el estado, prioridad, fecha límite o notas de una tarea existente buscándola por su nombre o término.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Título o palabras clave para identificar la tarea existente a modificar.',
          },
          'is_completed': {
            'type': 'boolean',
            'description':
                'true para marcar como completada/hecha, false para reabrir.',
          },
          'priority': {
            'type': 'integer',
            'enum': [1, 2, 3, 4],
            'description':
                'Nuevo nivel de prioridad: 1=Baja, 2=Media, 3=Alta, 4=Urgente.',
          },
          'due_date': {
            'type': 'string',
            'description': 'Nueva fecha límite en formato ISO 8601.',
          },
          'new_title': {
            'type': 'string',
            'description': 'Nuevo título si se solicita renombrar la tarea.',
          },
          'notes': {
            'type': 'string',
            'description': 'Nuevos detalles o notas adicionales.',
          },
          'project_name': {
            'type': 'string',
            'description':
                'Nuevo nombre de proyecto si se desea asociar o mover la tarea a otro proyecto.',
          },
        },
        'required': ['query'],
      },
    },
  };

  // 8. Tool: delete_task
  static const Map<String, dynamic> deleteTaskTool = {
    'type': 'function',
    'function': {
      'name': 'delete_task',
      'description':
          'Elimina una tarea existente buscándola por su título o término clave.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Título o palabras clave de la tarea a eliminar.',
          },
        },
        'required': ['query'],
      },
    },
  };

  // 9. Tool: update_note
  static const Map<String, dynamic> updateNoteTool = {
    'type': 'function',
    'function': {
      'name': 'update_note',
      'description':
          'Modifica una nota existente (fijar al inicio, archivar, renombrar o añadir contenido) buscándola por título o tema.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Título o palabras clave para identificar la nota a modificar.',
          },
          'is_pinned': {
            'type': 'boolean',
            'description': 'true para fijar al inicio, false para desfijar.',
          },
          'is_archived': {
            'type': 'boolean',
            'description': 'true para archivar la nota, false para desarchivar.',
          },
          'new_title': {
            'type': 'string',
            'description': 'Nuevo título si se solicita renombrar.',
          },
          'append_content': {
            'type': 'string',
            'description': 'Texto a anexar al final del contenido existente.',
          },
          'project_name': {
            'type': 'string',
            'description':
                'Nombre del proyecto al que se desea vincular o mover la nota.',
          },
        },
        'required': ['query'],
      },
    },
  };

  // 10. Tool: delete_note
  static const Map<String, dynamic> deleteNoteTool = {
    'type': 'function',
    'function': {
      'name': 'delete_note',
      'description':
          'Elimina una nota existente buscándola por su título o tema.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Título o palabras clave de la nota a eliminar.',
          },
        },
        'required': ['query'],
      },
    },
  };

  // 11. Tool: update_calendar_event
  static const Map<String, dynamic> updateCalendarEventTool = {
    'type': 'function',
    'function': {
      'name': 'update_calendar_event',
      'description':
          'Reprograma o actualiza un evento de calendario (fecha/hora, ubicación, categoría) buscándolo por título.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Título o motivo del evento existente a modificar.',
          },
          'new_start_time': {
            'type': 'string',
            'description':
                'Nueva fecha y hora de inicio en formato ISO 8601.',
          },
          'new_end_time': {
            'type': 'string',
            'description': 'Nueva fecha y hora de fin en formato ISO 8601.',
          },
          'location': {
            'type': 'string',
            'description': 'Nueva ubicación o enlace.',
          },
          'category': {
            'type': 'string',
            'enum': ['Personal', 'Trabajo', 'Estudios', 'Salud', 'Otro'],
            'description': 'Nueva categoría del evento.',
          },
          'is_all_day': {
            'type': 'boolean',
            'description': 'Si pasa a ser evento de todo el día.',
          },
          'new_title': {
            'type': 'string',
            'description': 'Nuevo título o motivo del evento.',
          },
        },
        'required': ['query'],
      },
    },
  };

  // 12. Tool: delete_calendar_event
  static const Map<String, dynamic> deleteCalendarEventTool = {
    'type': 'function',
    'function': {
      'name': 'delete_calendar_event',
      'description':
          'Cancela o elimina un evento de calendario buscándolo por su título o motivo.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Título o motivo del evento a cancelar o eliminar.',
          },
        },
        'required': ['query'],
      },
    },
  };

  // 13. Tool: update_project
  static const Map<String, dynamic> updateProjectTool = {
    'type': 'function',
    'function': {
      'name': 'update_project',
      'description':
          'Actualiza el estado, color o descripción de un proyecto existente buscándolo por su nombre.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Nombre o término clave del proyecto a modificar.',
          },
          'status': {
            'type': 'string',
            'enum': ['active', 'paused', 'completed', 'archived'],
            'description': 'Nuevo estado del proyecto.',
          },
          'color_hex': {
            'type': 'string',
            'description': 'Nuevo color hexadecimal (ej: "#10B981").',
          },
          'description': {
            'type': 'string',
            'description': 'Nueva descripción u objetivo del proyecto.',
          },
          'new_name': {
            'type': 'string',
            'description': 'Nuevo nombre si se solicita renombrar el proyecto.',
          },
        },
        'required': ['query'],
      },
    },
  };

  // 14. Tool: delete_project
  static const Map<String, dynamic> deleteProjectTool = {
    'type': 'function',
    'function': {
      'name': 'delete_project',
      'description':
          'Elimina un proyecto existente buscándolo por su nombre.',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Nombre del proyecto a eliminar.',
          },
        },
        'required': ['query'],
      },
    },
  };
}

