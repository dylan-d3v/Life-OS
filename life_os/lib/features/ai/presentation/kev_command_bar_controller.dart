import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../calendar/presentation/calendar_provider.dart';
import '../../finance/presentation/finance_provider.dart';
import '../../notes/presentation/notes_provider.dart';
import '../../projects/presentation/projects_provider.dart';
import '../../tasks/presentation/tasks_provider.dart';
import '../data/kev_action_dispatcher.dart';
import 'ai_providers.dart';

/// Elemento del historial de comandos procesados en la sesión activa.
class KevCommandHistoryItem {
  final String query;
  final KevExecutionResult result;
  final DateTime timestamp;

  const KevCommandHistoryItem({
    required this.query,
    required this.result,
    required this.timestamp,
  });
}

/// Estado inmutable de la barra de comandos de Kev.
class KevCommandBarState {
  final bool isProcessing;
  final KevExecutionResult? lastResult;
  final List<KevCommandHistoryItem> history;
  final String? errorMessage;

  const KevCommandBarState({
    this.isProcessing = false,
    this.lastResult,
    this.history = const [],
    this.errorMessage,
  });

  KevCommandBarState copyWith({
    bool? isProcessing,
    KevExecutionResult? lastResult,
    List<KevCommandHistoryItem>? history,
    String? errorMessage,
    bool clearLastResult = false,
  }) {
    return KevCommandBarState(
      isProcessing: isProcessing ?? this.isProcessing,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      history: history ?? this.history,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier que orquesta la ejecución interactiva desde la barra de comandos Desktop.
class KevCommandBarNotifier extends Notifier<KevCommandBarState> {
  @override
  KevCommandBarState build() => const KevCommandBarState();

  /// Interpreta la orden en lenguaje natural con el LLM y la despacha al
  /// repositorio criptográfico E2EE correspondiente.
  Future<KevExecutionResult> executePrompt(String prompt) async {
    final query = prompt.trim();
    if (query.isEmpty) {
      final emptyResult = KevExecutionResult.failure(
        userMessage: 'Por favor, escribe una instrucción para Kev.',
        actionType: 'empty',
      );
      state = state.copyWith(
        lastResult: emptyResult,
        errorMessage: emptyResult.userMessage,
      );
      return emptyResult;
    }

    state = state.copyWith(isProcessing: true, errorMessage: null);

    debugPrint('\n═══════════════════════════════════════════════════════════');
    debugPrint('▶️ [PASO 1/4] Entrada recibida en Command Bar: "$query"');

    try {
      final llmService = ref.read(kevLlmServiceProvider);
      final dispatcher = ref.read(kevActionDispatcherProvider);

      debugPrint('▶️ [PASO 2/4] Enviando al motor LLM: ${llmService.providerName}...');
      // 1. Interpretar lenguaje natural con LLM y Structured Tool Calling
      final action = await llmService.parseUserIntent(query);
      debugPrint('   🎯 Acción tipada identificada: ${action.actionName}');

      debugPrint('▶️ [PASO 3/4] Despachando acción hacia repositorios con E2EE...');
      // 2. Ejecutar la acción tipada con cifrado E2EE
      final result = await dispatcher.dispatch(action);
      debugPrint('   ${result.success ? "✅ Éxito" : "❌ Fallo"}: "${result.userMessage}"');

      // 3. Si la persistencia fue exitosa, invalidar los proveedores para actualizar la UI en vivo
      if (result.success) {
        debugPrint('▶️ [PASO 4/4] Refrescando listas de la interfaz en tiempo real (${result.actionType})...');
        switch (result.actionType) {
          case 'create_task':
            ref.invalidate(taskListProvider);
            break;
          case 'create_note':
            ref.invalidate(noteListProvider);
            break;
          case 'create_project':
            ref.invalidate(projectListProvider);
            break;
          case 'create_calendar_event':
            ref.invalidate(calendarEventListProvider);
            break;
          case 'log_finance':
            ref.invalidate(financeTransactionListProvider);
            break;
        }
      }
      debugPrint('═══════════════════════════════════════════════════════════\n');

      // 4. Agregar la interacción al historial de la sesión
      final historyItem = KevCommandHistoryItem(
        query: query,
        result: result,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        isProcessing: false,
        lastResult: result,
        history: [historyItem, ...state.history],
        errorMessage: result.success ? null : result.userMessage,
      );

      return result;
    } catch (e) {
      final errorResult = KevExecutionResult.failure(
        userMessage: 'Ocurrió un error inesperado al procesar tu orden: $e',
        actionType: 'error',
        error: e.toString(),
      );
      state = state.copyWith(
        isProcessing: false,
        lastResult: errorResult,
        errorMessage: errorResult.userMessage,
      );
      return errorResult;
    }
  }

  /// Limpia el último resultado mostrado.
  void clearLastResult() {
    state = state.copyWith(clearLastResult: true, errorMessage: null);
  }
}

/// Proveedor del estado y controlador de la barra de comandos de Kev.
final kevCommandBarProvider =
    NotifierProvider<KevCommandBarNotifier, KevCommandBarState>(
  KevCommandBarNotifier.new,
);

