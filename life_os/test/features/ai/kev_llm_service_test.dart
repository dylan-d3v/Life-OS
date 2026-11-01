import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/features/ai/data/groq_llm_service.dart';
import 'package:life_os/features/ai/data/kev_system_prompt.dart';
import 'package:life_os/features/ai/data/mock_llm_service.dart';
import 'package:life_os/features/ai/domain/kev_action.dart';
import 'package:life_os/features/finance/domain/finance_transaction_item.dart';

void main() {
  group('KevSystemPrompt Tests', () {
    test('buildSystemPrompt incluye fecha, día de la semana y catálogo de herramientas', () {
      final refDate = DateTime(2026, 11, 2, 14, 30); // 2 de noviembre de 2026 es Lunes
      final prompt = KevSystemPrompt.buildSystemPrompt(refDate);

      expect(prompt, contains('2026-11-02'));
      expect(prompt, contains('Lunes'));
      expect(prompt, contains('14:30:00'));
      expect(prompt, contains('create_task'));
      expect(prompt, contains('create_note'));
      expect(prompt, contains('create_project'));
      expect(prompt, contains('create_calendar_event'));
      expect(prompt, contains('log_finance'));
      expect(prompt, contains('query_summary'));
      expect(prompt, contains('DETERMINISMO ESTRICTO'));
    });
  });

  group('GroqLlmService Tests (con HTTP MockClient)', () {
    test('Parsea tool_call de create_task exitosamente', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.groq.com/openai/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer gsk_test_valid_key');

        final responseBody = {
          'id': 'chatcmpl-123',
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'tool_calls': [
                  {
                    'id': 'call_abc123',
                    'type': 'function',
                    'function': {
                      'name': 'create_task',
                      'arguments': jsonEncode({
                        'title': 'Comprar resistencias 10k para ESP32',
                        'priority': 3,
                        'due_date': '2026-11-05T18:00:00Z',
                      }),
                    },
                  }
                ],
              },
            }
          ],
        };

        return http.Response(jsonEncode(responseBody), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final service = GroqLlmService(
        client: mockClient,
        apiKey: 'gsk_test_valid_key',
      );

      final action = await service.parseUserIntent('Añade tarea urgente de comprar resistencias');

      expect(action, isA<CreateTaskAction>());
      final taskAction = action as CreateTaskAction;
      expect(taskAction.title, 'Comprar resistencias 10k para ESP32');
      expect(taskAction.priority, 3);
      expect(taskAction.dueDate, DateTime.parse('2026-11-05T18:00:00Z'));
    });

    test('Parsea tool_call de log_finance exitosamente', () async {
      final mockClient = MockClient((request) async {
        final responseBody = {
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'tool_calls': [
                  {
                    'function': {
                      'name': 'log_finance',
                      'arguments': jsonEncode({
                        'type': 'expense',
                        'amount': 22.50,
                        'category': 'Transporte',
                        'notes': 'Uber al trabajo',
                      }),
                    },
                  }
                ],
              },
            }
          ],
        };

        return http.Response(
          jsonEncode(responseBody),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GroqLlmService(
        client: mockClient,
        apiKey: 'gsk_test_valid_key',
      );

      final action = await service.parseUserIntent('Gasté 22.50 en Uber');

      expect(action, isA<LogFinanceAction>());
      final financeAction = action as LogFinanceAction;
      expect(financeAction.amount, 22.50);
      expect(financeAction.category, 'Transporte');
      expect(financeAction.type, TransactionType.expense);
    });

    test('Retorna UnknownAction si no hay API key configurada o es placeholder', () async {
      final service = GroqLlmService(apiKey: 'your-groq-api-key-here');
      final action = await service.parseUserIntent('Hola Kev');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'auth_error');
      expect(unknown.reason, contains('GROQ_API_KEY no configurada'));
    });

    test('Retorna UnknownAction si la entrada del usuario está vacía', () async {
      final service = GroqLlmService(apiKey: 'gsk_valid_key');
      final action = await service.parseUserIntent('   ');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'empty_input');
    });

    test('Maneja respuestas conversacionales sin tool_calls', () async {
      final mockClient = MockClient((request) async {
        final responseBody = {
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': '¡Hola! Soy Kev, tu asistente personal. ¿En qué te puedo ayudar?',
              },
            }
          ],
        };
        return http.Response(
          jsonEncode(responseBody),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GroqLlmService(
        client: mockClient,
        apiKey: 'gsk_test_valid_key',
      );

      final action = await service.parseUserIntent('Hola Kev');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'conversation');
      expect(unknown.reason, contains('¡Hola! Soy Kev'));
    });

    test('Maneja errores HTTP (ej. 429 Too Many Requests o 500)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Rate limit exceeded', 429);
      });

      final service = GroqLlmService(
        client: mockClient,
        apiKey: 'gsk_test_valid_key',
      );

      final action = await service.parseUserIntent('Tarea rápida');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'http_error_429');
      expect(unknown.reason, contains('HTTP 429'));
    });

    test('Maneja excepciones de red o timeout', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Fallo de resolución DNS');
      });

      final service = GroqLlmService(
        client: mockClient,
        apiKey: 'gsk_test_valid_key',
      );

      final action = await service.parseUserIntent('Crea una nota');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'network_exception');
    });
  });

  group('MockLlmService Tests', () {
    test('Despacha acciones encoladas con prioridad', () async {
      final service = MockLlmService();
      const enqueued = CreateNoteAction(
        title: 'Nota de prueba',
        content: 'Contenido forzado',
      );

      service.enqueueResponse(enqueued);

      final action = await service.parseUserIntent('Cualquier texto');
      expect(action, same(enqueued));
    });

    test('Aplica heurísticas locales inteligentes ante palabras clave', () async {
      final service = MockLlmService();

      final finance = await service.parseUserIntent('Gasté \$45.00 en almuerzo');
      expect(finance, isA<LogFinanceAction>());
      expect((finance as LogFinanceAction).amount, 45.0);

      final event = await service.parseUserIntent('Cita con el médico mañana');
      expect(event, isA<CreateCalendarEventAction>());

      final note = await service.parseUserIntent('Apunta esta idea de negocio');
      expect(note, isA<CreateNoteAction>());

      final project = await service.parseUserIntent('Nuevo proyecto de domótica');
      expect(project, isA<CreateProjectAction>());

      final query = await service.parseUserIntent('¿Qué tengo pendiente hoy?');
      expect(query, isA<QueryAction>());

      final task = await service.parseUserIntent('Comprar pan en la panadería');
      expect(task, isA<CreateTaskAction>());
    });
  });
}
