import 'package:flutter/foundation.dart';
import '../../finance/domain/finance_transaction_item.dart';
import '../domain/kev_action.dart';
import 'kev_llm_service.dart';

/// Servicio simulado (Mock) para pruebas unitarias y desarrollo offline sin consumo de API.
class MockLlmService implements KevLlmService {
  final List<KevAction> _mockQueue = [];

  MockLlmService();

  @override
  String get providerName => 'Mock Local (Offline)';

  /// Encola una acción que será retornada en la siguiente llamada a [parseUserIntent].
  void enqueueResponse(KevAction action) {
    _mockQueue.add(action);
  }

  /// Limpia las respuestas encoladas.
  void clearQueue() {
    _mockQueue.clear();
  }

  @override
  Future<KevAction> parseUserIntent(
    String userInput, {
    DateTime? referenceDateTime,
  }) async {
    debugPrint('📦 [Kev AI] Proveedor: Mock Local (Heurístico / Offline)');
    debugPrint('📤 [Kev AI] Analizando: "$userInput"');

    // 1. Si hay una respuesta encolada explícitamente, la despachamos
    if (_mockQueue.isNotEmpty) {
      final queued = _mockQueue.removeAt(0);
      debugPrint('🎯 [Kev AI] Respuesta encolada despachada: ${queued.actionName}');
      return queued;
    }

    final lower = userInput.trim().toLowerCase();
    final now = referenceDateTime ?? DateTime.now();

    // 2. Heurística simulada para desarrollo local rápido
    if (lower.contains('gasté') ||
        lower.contains('gasto') ||
        lower.contains('compré') ||
        lower.contains('pagué') ||
        lower.contains('\$')) {
      final amountMatch = RegExp(r'\$?(\d+([.,]\d+)?)').firstMatch(lower);
      final amount = amountMatch != null
          ? double.tryParse(amountMatch.group(1)!.replaceAll(',', '.')) ?? 10.0
          : 10.0;

      return LogFinanceAction(
        type: TransactionType.expense,
        amount: amount,
        category: 'Alimentación',
        notes: userInput,
        transactionDate: now,
      );
    }

    if (lower.contains('reunión') ||
        lower.contains('cita') ||
        lower.contains('evento') ||
        lower.contains('doctor') ||
        lower.contains('médico')) {
      return CreateCalendarEventAction(
        title: userInput,
        startTime: now.add(const Duration(days: 1, hours: 2)),
        endTime: now.add(const Duration(days: 1, hours: 3)),
        location: 'Virtual',
      );
    }

    if (lower.contains('nota') ||
        lower.contains('idea') ||
        lower.contains('apunta') ||
        lower.contains('apunte')) {
      return CreateNoteAction(
        title: 'Nota rápida',
        content: userInput,
        tags: const ['ideas'],
      );
    }

    if (lower.contains('proyecto') || lower.contains('meta')) {
      return CreateProjectAction(
        name: userInput,
        description: 'Proyecto creado mediante asistente',
      );
    }

    if (lower.contains('resumen') ||
        lower.contains('qué tengo') ||
        lower.contains('agenda')) {
      return QueryAction(
        queryTopic: 'daily_briefing',
        targetDate: now,
      );
    }

    // Por defecto: crear tarea
    return CreateTaskAction(
      title: userInput,
      priority: 2,
      dueDate: now.add(const Duration(days: 1)),
    );
  }
}

