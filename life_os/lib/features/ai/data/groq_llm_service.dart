import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../domain/kev_action.dart';
import '../domain/kev_tool_definitions.dart';
import 'kev_llm_service.dart';
import 'kev_system_prompt.dart';

/// Implementación del servicio de inferencia de Kev utilizando la API de ultrabaja latencia
/// de Groq Cloud (con LLaMA 3.3 70B o Qwen 2.5).
class GroqLlmService implements KevLlmService {
  final http.Client _client;
  final String? _apiKeyOverride;
  final String model;

  static const String _defaultEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _defaultModel = 'llama-3.3-70b-versatile';

  GroqLlmService({
    http.Client? client,
    String? apiKey,
    this.model = _defaultModel,
  })  : _client = client ?? http.Client(),
        _apiKeyOverride = apiKey;

  String? get _resolvedApiKey {
    final key = _apiKeyOverride;
    if (key != null && key.isNotEmpty) {
      return key;
    }
    try {
      return dotenv.env['GROQ_API_KEY'];
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
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your-groq-api-key-here') {
      return UnknownAction(
        rawName: 'auth_error',
        rawArguments: const {},
        reason:
            'GROQ_API_KEY no configurada. Agrega tu clave en el archivo .env para habilitar Kev.',
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

    final payload = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': cleanInput},
      ],
      'tools': KevToolDefinitions.allTools,
      'tool_choice': 'auto',
      'temperature': 0.1,
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

      if (response.statusCode != 200) {
        return UnknownAction(
          rawName: 'http_error_${response.statusCode}',
          rawArguments: {'body': response.body},
          reason: 'Error del servidor de inferencia (HTTP ${response.statusCode}): ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return const UnknownAction(
          rawName: 'empty_choices',
          rawArguments: {},
          reason: 'El modelo no retornó ninguna opción de respuesta.',
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

        return KevAction.fromToolCall(functionName, parsedArgs);
      }

      // Si no emitió un tool_call, extraemos el contenido conversacional
      final content = message['content']?.toString().trim() ?? '';
      return UnknownAction(
        rawName: 'conversation',
        rawArguments: {'message': content},
        reason: content.isNotEmpty
            ? content
            : 'El modelo respondió sin invocar herramientas ni emitir contenido.',
      );
    } catch (e) {
      return UnknownAction(
        rawName: 'network_exception',
        rawArguments: {'error': e.toString()},
        reason: 'Error de conexión o red con el servicio de inferencia: $e',
      );
    }
  }
}
