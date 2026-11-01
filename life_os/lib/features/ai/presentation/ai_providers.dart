import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../calendar/presentation/calendar_provider.dart';
import '../../finance/presentation/finance_provider.dart';
import '../../notes/presentation/notes_provider.dart';
import '../../projects/presentation/projects_provider.dart';
import '../../tasks/presentation/tasks_provider.dart';
import '../data/daily_briefing_service.dart';
import '../data/gemini_llm_service.dart';
import '../data/groq_llm_service.dart';
import '../data/kev_action_dispatcher.dart';
import '../data/kev_llm_service.dart';
import '../data/mock_llm_service.dart';
import '../domain/daily_briefing.dart';

/// Proveedor del servicio de inferencia de Kev.
///
/// Prioridad de conexión:
/// 1. Si `GEMINI_API_KEY` está configurada en `.env`, utiliza Google Gemini API (AI Studio).
/// 2. Si `GROQ_API_KEY` está configurada en `.env`, utiliza Groq Cloud API (LLaMA 3.3).
/// 3. De lo contrario, provee [MockLlmService] como respaldo funcional local offline.
final kevLlmServiceProvider = Provider<KevLlmService>((ref) {
  // 1. Google Gemini (Google AI Studio)
  String? geminiKey;
  try {
    geminiKey = dotenv.env['GEMINI_API_KEY'];
  } catch (_) {
    geminiKey = null;
  }

  if (geminiKey != null &&
      geminiKey.isNotEmpty &&
      geminiKey != 'your-gemini-api-key-here') {
    debugPrint('✨ [Kev AI] Conectado a Google Gemini API');
    return GeminiLlmService(apiKey: geminiKey);
  }

  // 2. Groq Cloud (LLaMA 3.3)
  String? groqKey;
  try {
    groqKey = dotenv.env['GROQ_API_KEY'];
  } catch (_) {
    groqKey = null;
  }

  if (groqKey != null &&
      groqKey.isNotEmpty &&
      groqKey != 'your-groq-api-key-here') {
    debugPrint('🚀 [Kev AI] Conectado a Groq Cloud API (LLaMA 3.3 70B)');
    return GroqLlmService(apiKey: groqKey);
  }

  // 3. Mock Local
  debugPrint('📦 [Kev AI] Sin claves de API configuradas -> Modo Mock Local (Offline)');
  return MockLlmService();
});

/// Retorna el nombre del motor de inferencia activo para visualización en la UI.
final activeLlmProviderNameProvider = Provider<String>((ref) {
  final service = ref.watch(kevLlmServiceProvider);
  return service.providerName;
});

/// Proveedor del servicio de síntesis de briefing diario.
final dailyBriefingServiceProvider = Provider<DailyBriefingService>((ref) {
  return DailyBriefingService(
    taskRepository: ref.watch(taskRepositoryProvider),
    calendarRepository: ref.watch(calendarRepositoryProvider),
    financeRepository: ref.watch(financeRepositoryProvider),
    vault: ref.watch(keyVaultServiceProvider),
  );
});

/// Proveedor del resumen matutino inteligente (Daily Briefing) para el día actual.
final dailyBriefingProvider = FutureProvider<DailyBriefing>((ref) async {
  final service = ref.watch(dailyBriefingServiceProvider);
  return service.generateBriefing();
});

/// Proveedor del despachador de acciones tipadas de Kev.
///
/// Conecta la intención interpretada por Kev con los repositorios criptográficos
/// E2EE del sistema (`TaskRepository`, `NoteRepository`, `ProjectRepository`,
/// `CalendarRepository`, `FinanceRepository`), utilizando la clave activa
/// de la sesión provista por [keyVaultServiceProvider].
final kevActionDispatcherProvider = Provider<KevActionDispatcher>((ref) {
  return KevActionDispatcher(
    taskRepository: ref.watch(taskRepositoryProvider),
    noteRepository: ref.watch(noteRepositoryProvider),
    projectRepository: ref.watch(projectRepositoryProvider),
    calendarRepository: ref.watch(calendarRepositoryProvider),
    financeRepository: ref.watch(financeRepositoryProvider),
    vault: ref.watch(keyVaultServiceProvider),
    dailyBriefingService: ref.watch(dailyBriefingServiceProvider),
  );
});
