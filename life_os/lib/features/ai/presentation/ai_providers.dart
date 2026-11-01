import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../calendar/presentation/calendar_provider.dart';
import '../../finance/presentation/finance_provider.dart';
import '../../notes/presentation/notes_provider.dart';
import '../../projects/presentation/projects_provider.dart';
import '../../tasks/presentation/tasks_provider.dart';
import '../data/daily_briefing_service.dart';
import '../data/groq_llm_service.dart';
import '../data/kev_action_dispatcher.dart';
import '../data/kev_llm_service.dart';
import '../data/mock_llm_service.dart';
import '../domain/daily_briefing.dart';

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
