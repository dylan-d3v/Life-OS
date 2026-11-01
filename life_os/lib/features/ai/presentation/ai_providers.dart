import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/groq_llm_service.dart';
import '../data/kev_llm_service.dart';
import '../data/mock_llm_service.dart';

/// Proveedor del servicio de inferencia de Kev.
///
/// Si la clave `GROQ_API_KEY` está configurada en `.env`, inicializa [GroqLlmService]
/// con conexión a la nube de ultrabaja latencia. De lo contrario, provee [MockLlmService]
/// como respaldo funcional local.
final kevLlmServiceProvider = Provider<KevLlmService>((ref) {
  String? apiKey;
  try {
    apiKey = dotenv.env['GROQ_API_KEY'];
  } catch (_) {
    apiKey = null;
  }

  if (apiKey != null &&
      apiKey.isNotEmpty &&
      apiKey != 'your-groq-api-key-here') {
    return GroqLlmService(apiKey: apiKey);
  }

  return MockLlmService();
});

