import '../domain/kev_action.dart';

/// Interfaz abstracta para cualquier proveedor de inferencia LLM del asistente Kev.
/// Permite desacoplar completamente el motor de decisiones de un proveedor concreto
/// (Groq, OpenAI, Ollama o Mocks de pruebas).
abstract class KevLlmService {
  /// Nombre identificador del proveedor de inferencia activo.
  String get providerName;

  /// Interpreta la entrada en lenguaje natural del usuario y retorna
  /// una acción estrictamente tipada ([KevAction]).
  ///
  /// [referenceDateTime] es la fecha y hora de referencia para resolver
  /// expresiones relativas ("mañana a las 4pm", "este viernes", "hace 2 horas").
  /// Si se omite, se utiliza [DateTime.now()].
  Future<KevAction> parseUserIntent(
    String userInput, {
    DateTime? referenceDateTime,
  });
}

