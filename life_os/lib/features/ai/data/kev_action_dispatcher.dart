import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/crypto/crypto.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_transaction_item.dart';
import '../../notes/data/note_repository.dart';
import '../../projects/data/project_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task_item.dart';
import '../domain/kev_action.dart';
import 'daily_briefing_service.dart';

/// Resultado de la ejecución de una acción interpretada por Kev.
class KevExecutionResult {
  final bool success;
  final String userMessage;
  final String? entityId;
  final String actionType;
  final Object? createdItem;
  final String? error;

  const KevExecutionResult({
    required this.success,
    required this.userMessage,
    this.entityId,
    required this.actionType,
    this.createdItem,
    this.error,
  });

  factory KevExecutionResult.success({
    required String userMessage,
    required String actionType,
    String? entityId,
    Object? createdItem,
  }) {
    return KevExecutionResult(
      success: true,
      userMessage: userMessage,
      entityId: entityId,
      actionType: actionType,
      createdItem: createdItem,
    );
  }

  factory KevExecutionResult.failure({
    required String userMessage,
    required String actionType,
    String? error,
  }) {
    return KevExecutionResult(
      success: false,
      userMessage: userMessage,
      actionType: actionType,
      error: error,
    );
  }
}

/// Despachador de acciones tipadas de Kev.
///
/// Recibe una [KevAction], valida el estado de la bóveda de claves E2EE
/// y delega la operación al repositorio correspondiente. Garantiza que
/// todos los datos persistidos se cifren localmente con AES-256-GCM
/// antes de sincronizarse con Supabase.
class KevActionDispatcher {
  final TaskRepository taskRepository;
  final NoteRepository noteRepository;
  final ProjectRepository projectRepository;
  final CalendarRepository calendarRepository;
  final FinanceRepository financeRepository;
  final KeyVaultService vault;
  final DailyBriefingService? dailyBriefingService;

  KevActionDispatcher({
    required this.taskRepository,
    required this.noteRepository,
    required this.projectRepository,
    required this.calendarRepository,
    required this.financeRepository,
    required this.vault,
    this.dailyBriefingService,
  });

  /// Ejecuta la acción tipada y retorna un resultado estructurado con
  /// mensaje apto para notificación visual o síntesis de voz (TTS).
  Future<KevExecutionResult> dispatch(KevAction action) async {
    // 1. Verificación de seguridad E2EE: La bóveda debe estar desbloqueada.
    if (!vault.isUnlocked) {
      debugPrint('   🔒 [Kev E2EE] Error de seguridad: Bóveda de claves bloqueada.');
      return KevExecutionResult.failure(
        userMessage:
            'La bóveda de seguridad está bloqueada. Desbloquéala con tu contraseña maestra para guardar información cifrada.',
        actionType: action.actionName,
        error: 'KeyVault locked',
      );
    }

    try {
      return switch (action) {
        CreateTaskAction a => await _handleCreateTask(a),
        CreateNoteAction a => await _handleCreateNote(a),
        CreateProjectAction a => await _handleCreateProject(a),
        CreateCalendarEventAction a => await _handleCreateCalendarEvent(a),
        LogFinanceAction a => await _handleLogFinance(a),
        QueryAction a => await _handleQuery(a),
        UnknownAction a => _handleUnknown(a),
      };
    } catch (e) {
      return KevExecutionResult.failure(
        userMessage: 'Ocurrió un error al ejecutar la acción: $e',
        actionType: action.actionName,
        error: e.toString(),
      );
    }
  }

  // ===========================================================================
  // Handlers individuales
  // ===========================================================================

  Future<KevExecutionResult> _handleCreateTask(CreateTaskAction action) async {
    String? projectId;

    // Si la acción especifica nombre de proyecto, intentamos resolver el ID
    if (action.projectName != null && action.projectName!.isNotEmpty) {
      try {
        final projects = await projectRepository.fetchProjects();
        final match = projects.where(
          (p) => p.name.toLowerCase() == action.projectName!.toLowerCase(),
        ).firstOrNull ?? projects.where(
          (p) => p.name.toLowerCase().contains(action.projectName!.toLowerCase()),
        ).firstOrNull;
        if (match != null && match.id.isNotEmpty) {
          projectId = match.id;
        }
      } catch (_) {
        // Si no se puede resolver el proyecto, continuamos sin asociarlo
        projectId = null;
      }
    }

    final task = await taskRepository.createTask(
      title: action.title,
      notes: action.notes,
      priority: action.priority,
      dueDate: action.dueDate,
      projectId: projectId,
    );

    final duePart = action.dueDate != null
        ? ' para el ${DateFormat('dd/MM/yyyy').format(action.dueDate!)}'
        : '';

    return KevExecutionResult.success(
      userMessage: 'Tarea agregada: "${task.title}"$duePart.',
      actionType: action.actionName,
      entityId: task.id,
      createdItem: task,
    );
  }

  Future<KevExecutionResult> _handleCreateNote(CreateNoteAction action) async {
    final note = await noteRepository.createNote(
      title: action.title,
      content: action.content,
      tags: action.tags,
      isPinned: action.isPinned,
    );

    final tagPart =
        action.tags.isNotEmpty ? ' con etiquetas [${action.tags.join(', ')}]' : '';

    return KevExecutionResult.success(
      userMessage: 'Nota guardada: "${note.title}"$tagPart.',
      actionType: action.actionName,
      entityId: note.id,
      createdItem: note,
    );
  }

  Future<KevExecutionResult> _handleCreateProject(
    CreateProjectAction action,
  ) async {
    final project = await projectRepository.createProject(
      name: action.name,
      description: action.description,
      colorHex: action.colorHex,
      status: action.status,
    );

    return KevExecutionResult.success(
      userMessage: 'Proyecto creado: "${project.name}".',
      actionType: action.actionName,
      entityId: project.id,
      createdItem: project,
    );
  }

  Future<KevExecutionResult> _handleCreateCalendarEvent(
    CreateCalendarEventAction action,
  ) async {
    final event = await calendarRepository.createEvent(
      title: action.title,
      startTime: action.startTime,
      endTime: action.endTime,
      isAllDay: action.isAllDay,
      location: action.location,
      description: action.description,
    );

    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(action.startTime);
    final locPart =
        action.location.isNotEmpty ? ' en ${action.location}' : '';

    return KevExecutionResult.success(
      userMessage: 'Evento agendado: "${event.title}" ($dateStr$locPart).',
      actionType: action.actionName,
      entityId: event.id,
      createdItem: event,
    );
  }

  Future<KevExecutionResult> _handleLogFinance(LogFinanceAction action) async {
    final transaction = await financeRepository.createTransaction(
      type: action.type,
      amount: action.amount,
      transactionDate: action.transactionDate,
      currency: action.currency,
      category: action.category,
      notes: action.notes,
    );

    final typeLabel = switch (action.type) {
      TransactionType.income => 'Ingreso',
      TransactionType.expense => 'Gasto',
      TransactionType.transfer => 'Transferencia',
    };

    final amountStr =
        '${action.currency} \$${action.amount.toStringAsFixed(2)}';

    return KevExecutionResult.success(
      userMessage:
          '$typeLabel de $amountStr registrado en "${action.category}".',
      actionType: action.actionName,
      entityId: transaction.id,
      createdItem: transaction,
    );
  }

  Future<KevExecutionResult> _handleQuery(QueryAction action) async {
    if (dailyBriefingService != null) {
      final briefing = await dailyBriefingService!.generateBriefing(
        forDate: action.targetDate,
      );
      return KevExecutionResult.success(
        userMessage: briefing.formattedSummary,
        actionType: action.actionName,
        createdItem: briefing,
      );
    }

    try {
      final tasks = await taskRepository.fetchTasks();
      final pendingCount =
          tasks.where((t) => t.status != TaskStatus.done).length;

      final events = await calendarRepository.fetchEvents();
      final todayEvents = events.where((e) {
        return e.startTime.year == action.targetDate.year &&
            e.startTime.month == action.targetDate.month &&
            e.startTime.day == action.targetDate.day;
      }).length;

      final summary =
          'Resumen para ${DateFormat('dd/MM/yyyy').format(action.targetDate)}: '
          '$pendingCount tareas pendientes y $todayEvents eventos agendados.';

      return KevExecutionResult.success(
        userMessage: summary,
        actionType: action.actionName,
      );
    } catch (_) {
      return KevExecutionResult.success(
        userMessage:
            'Consulta de "${action.queryTopic}" procesada para el ${DateFormat('dd/MM/yyyy').format(action.targetDate)}.',
        actionType: action.actionName,
      );
    }
  }

  KevExecutionResult _handleUnknown(UnknownAction action) {
    return KevExecutionResult.failure(
      userMessage:
          'No pude determinar la acción a ejecutar. ${action.reason}',
      actionType: action.actionName,
      error: action.reason,
    );
  }
}
