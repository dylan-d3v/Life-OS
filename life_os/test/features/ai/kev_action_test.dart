import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/ai/domain/kev_action.dart';
import 'package:life_os/features/ai/domain/kev_tool_definitions.dart';
import 'package:life_os/features/finance/domain/finance_transaction_item.dart';
import 'package:life_os/features/projects/domain/project_item.dart';

void main() {
  group('KevAction Domain Tests', () {
    test('CreateTaskAction se deserializa correctamente desde Tool Call y JSON', () {
      final args = {
        'title': 'Comprar sensores de pulso para el ESP32',
        'notes': 'Buscar modelo MAX30102 con interface I2C',
        'priority': 3,
        'due_date': '2026-11-10T15:00:00Z',
        'project_name': 'Hardware Life-OS',
      };

      final action = KevAction.fromToolCall('create_task', args) as CreateTaskAction;

      expect(action.actionName, 'create_task');
      expect(action.title, 'Comprar sensores de pulso para el ESP32');
      expect(action.notes, 'Buscar modelo MAX30102 con interface I2C');
      expect(action.priority, 3);
      expect(action.dueDate, DateTime.parse('2026-11-10T15:00:00Z'));
      expect(action.projectName, 'Hardware Life-OS');

      // Serialización roundtrip
      final json = action.toJson();
      expect(json['action'], 'create_task');
      expect(json['parameters']['title'], action.title);

      final fromJson = KevAction.fromJson(json) as CreateTaskAction;
      expect(fromJson.title, action.title);
    });

    test('CreateTaskAction tolera prioridad como string y sin fecha límite', () {
      final args = {
        'title': 'Revisar logs del sistema',
        'priority': '4',
      };

      final action = KevAction.fromToolCall('create_task', args) as CreateTaskAction;

      expect(action.title, 'Revisar logs del sistema');
      expect(action.priority, 4);
      expect(action.dueDate, isNull);
    });

    test('CreateNoteAction parsea etiquetas como lista o como string separado por comas', () {
      final argsWithList = {
        'title': 'Idea de arquitectura Kev',
        'content': 'Separar LLM parser de action dispatcher',
        'tags': ['ai', 'architecture', '#typesafe'],
        'is_pinned': true,
      };

      final actionList =
          KevAction.fromToolCall('create_note', argsWithList) as CreateNoteAction;
      expect(actionList.tags, ['ai', 'architecture', 'typesafe']);
      expect(actionList.isPinned, isTrue);

      final argsWithString = {
        'title': 'Recordatorio rápido',
        'content': 'Llamar al banco',
        'tags': 'finanzas, trámite, #banco',
        'is_pinned': 'true',
      };

      final actionString =
          KevAction.fromToolCall('create_note', argsWithString) as CreateNoteAction;
      expect(actionString.tags, ['finanzas', 'trámite', 'banco']);
      expect(actionString.isPinned, isTrue);

      final argsWithProject = {
        'title': 'Diagrama de bloques',
        'content': 'Componentes I2C',
        'project_name': 'Satélite Cubesat',
      };
      final actionProject =
          KevAction.fromToolCall('create_note', argsWithProject) as CreateNoteAction;
      expect(actionProject.projectName, 'Satélite Cubesat');
    });

    test('CreateProjectAction mapea correctamente status enum', () {
      final args = {
        'name': 'Fase 4: Inteligencia Artificial',
        'description': 'Implementación del cerebro Kev con TypeSafe function calling',
        'color_hex': '#8B5CF6',
        'status': 'active',
      };

      final action =
          KevAction.fromToolCall('create_project', args) as CreateProjectAction;

      expect(action.name, 'Fase 4: Inteligencia Artificial');
      expect(action.description, contains('TypeSafe'));
      expect(action.colorHex, '#8B5CF6');
      expect(action.status, ProjectStatus.active);
    });

    test('CreateCalendarEventAction calcula fin por defecto si se omite o es inválido', () {
      final startTime = DateTime.parse('2026-11-05T14:00:00Z');
      final args = {
        'title': 'Reunión de alineación Kev',
        'start_time': startTime.toIso8601String(),
        'location': 'Google Meet',
        'description': 'Revisión de avance del asistente',
      };

      final action = KevAction.fromToolCall('create_calendar_event', args)
          as CreateCalendarEventAction;

      expect(action.title, 'Reunión de alineación Kev');
      expect(action.startTime, startTime);
      // Debe autocalcularse 1 hora después
      expect(action.endTime, startTime.add(const Duration(hours: 1)));
      expect(action.isAllDay, isFalse);
      expect(action.location, 'Google Meet');
      expect(action.category, 'Personal');
    });

    test('CreateCalendarEventAction parsea category y location explícitos', () {
      final startTime = DateTime.parse('2026-11-12T09:00:00Z');
      final args = {
        'title': 'Examen de Matemáticas',
        'start_time': startTime.toIso8601String(),
        'location': 'CEN',
        'category': 'Estudios',
        'is_all_day': true,
        'description': 'Examen de matemáticas',
      };

      final action = KevAction.fromToolCall('create_calendar_event', args)
          as CreateCalendarEventAction;

      expect(action.title, 'Examen de Matemáticas');
      expect(action.location, 'CEN');
      expect(action.category, 'Estudios');
      expect(action.isAllDay, isTrue);
      expect(action.description, 'Examen de matemáticas');
    });

    test('LogFinanceAction tolera montos como string con coma o punto decimal', () {
      final argsString = {
        'type': 'gasto',
        'amount': '18,75',
        'currency': 'USD',
        'category': 'Alimentación',
        'notes': 'Almuerzo ejecutivo',
      };

      final action =
          KevAction.fromToolCall('log_finance', argsString) as LogFinanceAction;

      expect(action.type, TransactionType.expense);
      expect(action.amount, 18.75);
      expect(action.currency, 'USD');
      expect(action.category, 'Alimentación');
      expect(action.notes, 'Almuerzo ejecutivo');
    });

    test('QueryAction parsea tema y fecha de consulta correctamente', () {
      final args = {
        'query_topic': 'tasks_summary',
        'target_date': '2026-11-01T00:00:00Z',
      };

      final action =
          KevAction.fromToolCall('query_summary', args) as QueryAction;

      expect(action.queryTopic, 'tasks_summary');
      expect(action.targetDate, DateTime.parse('2026-11-01T00:00:00Z'));
    });

    test('UpdateTaskAction parsea query, is_completed, priority y due_date', () {
      final dueDate = DateTime.parse('2026-11-20T18:00:00Z');
      final args = {
        'query': 'comprar café tostado',
        'is_completed': true,
        'priority': 3,
        'due_date': dueDate.toIso8601String(),
        'new_title': 'Comprar café expreso',
        'notes': 'Comprar 2 bolsas',
      };

      final action =
          KevAction.fromToolCall('update_task', args) as UpdateTaskAction;

      expect(action.query, 'comprar café tostado');
      expect(action.isCompleted, isTrue);
      expect(action.priority, 3);
      expect(action.dueDate, dueDate);
      expect(action.newTitle, 'Comprar café expreso');
      expect(action.notes, 'Comprar 2 bolsas');
    });

    test('DeleteTaskAction parsea query de eliminación', () {
      final args = {'query': 'comprar leche'};
      final action =
          KevAction.fromToolCall('delete_task', args) as DeleteTaskAction;
      expect(action.query, 'comprar leche');
    });

    test('UpdateNoteAction parsea query, is_pinned y append_content', () {
      final args = {
        'query': 'ideas del satélite',
        'is_pinned': true,
        'is_archived': false,
        'new_title': 'Ideas del ESP32 Satélite',
        'append_content': 'Agregar batería LiPo 3.7V',
        'project_name': 'Hardware ESP32',
      };

      final action =
          KevAction.fromToolCall('update_note', args) as UpdateNoteAction;

      expect(action.query, 'ideas del satélite');
      expect(action.isPinned, isTrue);
      expect(action.isArchived, isFalse);
      expect(action.newTitle, 'Ideas del ESP32 Satélite');
      expect(action.appendContent, 'Agregar batería LiPo 3.7V');
      expect(action.projectName, 'Hardware ESP32');
    });

    test('DeleteNoteAction parsea query de eliminación', () {
      final args = {'query': 'apuntes viejos'};
      final action =
          KevAction.fromToolCall('delete_note', args) as DeleteNoteAction;
      expect(action.query, 'apuntes viejos');
    });

    test('UpdateCalendarEventAction parsea query, reprogramación, ubicación y categoría', () {
      final newStart = DateTime.parse('2026-11-13T10:00:00Z');
      final newEnd = DateTime.parse('2026-11-13T12:00:00Z');
      final args = {
        'query': 'examen de matemáticas',
        'new_start_time': newStart.toIso8601String(),
        'new_end_time': newEnd.toIso8601String(),
        'location': 'Aula Magna',
        'category': 'Estudios',
        'is_all_day': false,
        'new_title': 'Examen Final de Álgebra',
      };

      final action = KevAction.fromToolCall('update_calendar_event', args)
          as UpdateCalendarEventAction;

      expect(action.query, 'examen de matemáticas');
      expect(action.newStartTime, newStart);
      expect(action.newEndTime, newEnd);
      expect(action.location, 'Aula Magna');
      expect(action.category, 'Estudios');
      expect(action.isAllDay, isFalse);
      expect(action.newTitle, 'Examen Final de Álgebra');
    });

    test('DeleteCalendarEventAction parsea query de cancelación', () {
      final args = {'query': 'reunión con Carlos'};
      final action = KevAction.fromToolCall('delete_calendar_event', args)
          as DeleteCalendarEventAction;
      expect(action.query, 'reunión con Carlos');
    });

    test('UpdateProjectAction parsea query, nuevo status y color', () {
      final args = {
        'query': 'Life-OS',
        'status': 'paused',
        'color_hex': '#F59E0B',
        'description': 'Pausado temporalmente por exámenes',
        'new_name': 'Life-OS v2',
      };

      final action =
          KevAction.fromToolCall('update_project', args) as UpdateProjectAction;

      expect(action.query, 'Life-OS');
      expect(action.status, ProjectStatus.paused);
      expect(action.colorHex, '#F59E0B');
      expect(action.description, 'Pausado temporalmente por exámenes');
      expect(action.newName, 'Life-OS v2');
    });

    test('DeleteProjectAction parsea query de eliminación', () {
      final args = {'query': 'proyecto cancelado'};
      final action =
          KevAction.fromToolCall('delete_project', args) as DeleteProjectAction;
      expect(action.query, 'proyecto cancelado');
    });

    test('Tool no reconocida o argumentos corruptos retornan UnknownAction elegantemente', () {
      final unknownTool =
          KevAction.fromToolCall('hack_nasa', {'target': 'satellite'});
      expect(unknownTool, isA<UnknownAction>());
      expect((unknownTool as UnknownAction).rawName, 'hack_nasa');

      final corruptArgs = KevAction.fromToolCall('log_finance', {
        'amount': 'invalido_no_es_numero',
      });
      expect(corruptArgs, isA<UnknownAction>());
      expect((corruptArgs as UnknownAction).reason, contains('monto financiero'));
    });
  });

  group('KevToolDefinitions Tests', () {
    test('allTools contiene exactamente 14 definiciones con nombres válidos', () {
      expect(KevToolDefinitions.allTools.length, 14);

      final names = KevToolDefinitions.allTools
          .map((t) => (t['function'] as Map)['name'] as String)
          .toList();

      expect(names, containsAll([
        'create_task',
        'update_task',
        'delete_task',
        'create_note',
        'update_note',
        'delete_note',
        'create_project',
        'update_project',
        'delete_project',
        'create_calendar_event',
        'update_calendar_event',
        'delete_calendar_event',
        'log_finance',
        'query_summary',
      ]));
    });

    test('Todas las tools tienen estructura conforme al estándar OpenAI / Groq', () {
      for (final tool in KevToolDefinitions.allTools) {
        expect(tool['type'], 'function');
        final function = tool['function'] as Map<String, dynamic>;
        expect(function['name'], isA<String>());
        expect(function['description'], isA<String>());
        expect(function['parameters'], isA<Map<String, dynamic>>());
        final params = function['parameters'] as Map<String, dynamic>;
        expect(params['type'], 'object');
        expect(params['properties'], isA<Map<String, dynamic>>());
      }
    });
  });
}

