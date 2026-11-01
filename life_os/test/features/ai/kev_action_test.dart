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
    test('allTools contiene exactamente 6 definiciones con nombres válidos', () {
      expect(KevToolDefinitions.allTools.length, 6);

      final names = KevToolDefinitions.allTools
          .map((t) => (t['function'] as Map)['name'] as String)
          .toList();

      expect(names, containsAll([
        'create_task',
        'create_note',
        'create_project',
        'create_calendar_event',
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

