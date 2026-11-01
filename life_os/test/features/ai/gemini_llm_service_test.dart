import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/features/ai/data/gemini_llm_service.dart';
import 'package:life_os/features/ai/domain/kev_action.dart';

void main() {
  group('GeminiLlmService Tests', () {
    test('retorna auth_error si no se configura la API Key', () async {
      final service = GeminiLlmService(apiKey: '');
      final action = await service.parseUserIntent('Comprar pan');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'auth_error');
      expect(unknown.reason, contains('GEMINI_API_KEY no configurada'));
    });

    test('retorna empty_input si el prompt del usuario está en blanco', () async {
      final service = GeminiLlmService(apiKey: 'dummy-key');
      final action = await service.parseUserIntent('   ');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'empty_input');
    });

    test('procesa respuesta de Gemini con tool_call para create_task', () async {
      final mockResponse = {
        'id': 'chatcmpl-test',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'tool_calls': [
                {
                  'id': 'call-1',
                  'type': 'function',
                  'function': {
                    'name': 'create_task',
                    'arguments': jsonEncode({
                      'title': 'Comprar sensores para el ESP32',
                      'priority': 3,
                      'notes': 'Revisar MAX30102',
                    }),
                  },
                }
              ],
            },
          }
        ],
      };

      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.url.toString(), contains('openai/chat/completions'));

        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiLlmService(
        apiKey: 'test-key',
        client: client,
      );

      final action = await service.parseUserIntent('Anota comprar sensores');

      expect(action, isA<CreateTaskAction>());
      final taskAction = action as CreateTaskAction;
      expect(taskAction.title, 'Comprar sensores para el ESP32');
      expect(taskAction.priority, 3);
      expect(taskAction.notes, 'Revisar MAX30102');
      expect(service.providerName, contains('Google Gemini'));
    });

    test('procesa respuesta de Gemini con tool_call para log_finance', () async {
      final mockResponse = {
        'id': 'chatcmpl-test2',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'tool_calls': [
                {
                  'id': 'call-2',
                  'type': 'function',
                  'function': {
                    'name': 'log_finance',
                    'arguments': jsonEncode({
                      'type': 'expense',
                      'amount': 18.50,
                      'category': 'Transporte',
                      'notes': 'Gasolina para el auto',
                    }),
                  },
                }
              ],
            },
          }
        ],
      };

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiLlmService(
        apiKey: 'test-key',
        client: client,
      );

      final action = await service.parseUserIntent('Gasté 18.50 en gasolina');

      expect(action, isA<LogFinanceAction>());
      final financeAction = action as LogFinanceAction;
      expect(financeAction.amount, 18.50);
      expect(financeAction.category, 'Transporte');
      expect(financeAction.notes, 'Gasolina para el auto');
    });

    test('captura errores HTTP (401 o 429) de Gemini y retorna UnknownAction', () async {
      final client = MockClient((request) async {
        return http.Response('Invalid API key', 401);
      });

      final service = GeminiLlmService(
        apiKey: 'invalid-key',
        client: client,
      );

      final action = await service.parseUserIntent('Cualquier orden');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'http_error_401');
      expect(unknown.reason, contains('401'));
    });

    test('procesa respuesta puramente conversacional cuando no hay herramientas', () async {
      final mockResponse = {
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': 'Hola Dylan, ¿en qué te puedo ayudar hoy con Life-OS?',
            },
          }
        ],
      };

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiLlmService(
        apiKey: 'test-key',
        client: client,
      );

      final action = await service.parseUserIntent('Hola Kev');

      expect(action, isA<UnknownAction>());
      final unknown = action as UnknownAction;
      expect(unknown.rawName, 'conversation');
      expect(unknown.reason, contains('Hola Dylan'));
    });
  });
}

