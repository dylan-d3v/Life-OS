import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../domain/kev_action.dart';
import '../domain/kev_tool_definitions.dart';
import 'kev_llm_service.dart';
import 'kev_system_prompt.dart';

/// Implementación del servicio de inferencia de Kev utilizando la API de Google Gemini
/// (a través del endpoint compatible con OpenAI de Google AI Studio).
///
/// Soporta modelos como `gemini-2.0-flash` y `gemini-1.5-flash` con Function Calling nativo,
/// ultrabaja latencia y alta precisión en español.
class GeminiLlmService implements KevLlmService {
  final http.Client _client;
  final String? _apiKeyOverride;
  final String model;

  static const String _defaultEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
  static const String _defaultModel = 'gemini-3.5-flash';

  @override
  String get providerName => 'Google Gemini ($model)';

  GeminiLlmService({
    http.Client? client,
    String? apiKey,
    String? model,
  })  : _client = client ?? http.Client(),
        _apiKeyOverride = apiKey,
        model = model ?? _resolveModel();

  static String _resolveModel() {
    try {
      final envModel = dotenv.env['GEMINI_MODEL'];
      if (envModel != null && envModel.trim().isNotEmpty) {
        return envModel.trim();
      }
    } catch (_) {}
    return _defaultModel;
  }

  String? get _resolvedApiKey {
    final key = _apiKeyOverride;
    if (key != null && key.isNotEmpty) {
      return key;
    }
    try {
      return dotenv.env['GEMINI_API_KEY'];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<KevAction> parseUserIntent(
    String userInput, {
    DateTime? referenceDateTime,
  }) async {
    final apiKey = _resolvedApiKey;
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your-gemini-api-key-here') {
      return const UnknownAction(
        rawName: 'auth_error',
        rawArguments: {},
        reason:
            'GEMINI_API_KEY no configurada. Agrega tu clave de Google AI Studio en el archivo .env para habilitar Kev.',
      );
    }

    final cleanInput = userInput.trim();
    if (cleanInput.isEmpty) {
      return const UnknownAction(
        rawName: 'empty_input',
        rawArguments: {},
        reason: 'El mensaje del usuario está vacío.',
      );
    }

    final now = referenceDateTime ?? DateTime.now();
    final systemPrompt = KevSystemPrompt.buildSystemPrompt(now);

    debugPrint('✨ [Kev AI] Proveedor: Google Gemini ($model)');
    debugPrint('📤 [Kev AI] Enviando prompt: "$cleanInput"');

    final payload = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': cleanInput},
      ],
      'tools': KevToolDefinitions.allTools,
      'tool_choice': 'auto',
      'temperature': 0.0,
      'max_tokens': 250,
      'extra_body': {
        'google': {
          'thinking_config': {
            'thinking_budget': 0,
          },
        },
      },
    };

    try {
      final response = await _client.post(
        Uri.parse(_defaultEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('   🌐 [Gemini HTTP] Código de respuesta: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('   ⚠️ [Gemini HTTP Error]: ${response.body}');
        return UnknownAction(
          rawName: 'http_error_${response.statusCode}',
          rawArguments: {'body': response.body},
          reason:
              'Error del servidor de Google Gemini (HTTP ${response.statusCode}): ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return const UnknownAction(
          rawName: 'empty_choices',
          rawArguments: {},
          reason: 'Google Gemini no retornó ninguna opción de respuesta.',
        );
      }

      final message = choices.first['message'] as Map<String, dynamic>? ?? {};
      final toolCalls = message['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty) {
        final firstCall = toolCalls.first as Map<String, dynamic>;
        final function = firstCall['function'] as Map<String, dynamic>? ?? {};
        final functionName = function['name']?.toString() ?? 'unknown';
        final rawArgs = function['arguments']?.toString() ?? '{}';

        final Map<String, dynamic> parsedArgs;
        try {
          parsedArgs = jsonDecode(rawArgs) as Map<String, dynamic>;
        } catch (e) {
          return UnknownAction(
            rawName: functionName,
            rawArguments: {'raw': rawArgs},
            reason: 'Error al decodificar argumentos JSON del tool call: $e',
          );
        }

        final action = KevAction.fromToolCall(functionName, parsedArgs);
        debugPrint(
            '🎯 [Kev AI] Herramienta detectada por Gemini: $functionName -> $parsedArgs');
        return action;
      }

      // Si el modelo respondió conversacionalmente
      final content = message['content']?.toString().trim() ?? '';
      return UnknownAction(
        rawName: 'conversation',
        rawArguments: {'message': content},
        reason: content.isNotEmpty
            ? content
            : 'Gemini respondió sin invocar herramientas ni emitir contenido.',
      );
    } catch (e) {
      return UnknownAction(
        rawName: 'network_exception',
        rawArguments: {'error': e.toString()},
        reason: 'Error de conexión o red con Google Gemini: $e',
      );
    }
  }
}

