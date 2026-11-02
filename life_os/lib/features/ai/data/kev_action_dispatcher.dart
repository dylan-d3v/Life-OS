import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/crypto/crypto.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/domain/calendar_event_item.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_transaction_item.dart';
import '../../notes/data/note_repository.dart';
import '../../notes/domain/note_item.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_item.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task_item.dart';
import '../domain/kev_action.dart';
import 'daily_briefing_service.dart';
import 'local_entity_resolver.dart';

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
        UpdateTaskAction a => await _handleUpdateTask(a),
        DeleteTaskAction a => await _handleDeleteTask(a),
        CreateNoteAction a => await _handleCreateNote(a),
        UpdateNoteAction a => await _handleUpdateNote(a),
        DeleteNoteAction a => await _handleDeleteNote(a),
        CreateProjectAction a => await _handleCreateProject(a),
        UpdateProjectAction a => await _handleUpdateProject(a),
        DeleteProjectAction a => await _handleDeleteProject(a),
        CreateCalendarEventAction a => await _handleCreateCalendarEvent(a),
        UpdateCalendarEventAction a => await _handleUpdateCalendarEvent(a),
        DeleteCalendarEventAction a => await _handleDeleteCalendarEvent(a),
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
      category: action.category,
    );

    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(action.startTime);
    final locPart =
        action.location.isNotEmpty ? ' en ${action.location}' : '';
    final catPart = action.category.isNotEmpty && action.category != 'Personal'
        ? ' [${action.category}]'
        : '';

    return KevExecutionResult.success(
      userMessage: 'Evento agendado: "${event.title}"$catPart ($dateStr$locPart).',
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

  // ===========================================================================
  // Handlers CRUD con Resolución Semántica Local (Fase 3)
  // ===========================================================================

  Future<KevExecutionResult> _handleUpdateTask(UpdateTaskAction action) async {
    final tasks = await taskRepository.fetchTasks();
    final match = LocalEntityResolver.findBestMatch<TaskItem>(
      query: action.query,
      items: tasks,
      titleExtractor: (t) => t.title,
    );

    if (match == null) {
      return KevExecutionResult.failure(
        userMessage:
            'No encontré ninguna tarea que coincida con "${action.query}".',
        actionType: action.actionName,
      );
    }

    final newStatus = action.isCompleted != null
        ? (action.isCompleted! ? TaskStatus.done : TaskStatus.todo)
        : match.status;

    final updatedTask = match.copyWith(
      title: action.newTitle ?? match.title,
      notes: action.notes ?? match.notes,
      priority: action.priority ?? match.priority,
      dueDate: action.dueDate ?? match.dueDate,
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    await taskRepository.updateTask(updatedTask);

    final String message;
    if (action.isCompleted != null) {
      message = action.isCompleted!
          ? 'Tarea "${match.title}" marcada como completada.'
          : 'Tarea "${match.title}" reabierta.';
    } else if (action.priority != null) {
      message =
          'Prioridad de la tarea "${match.title}" actualizada a ${action.priority}.';
    } else if (action.dueDate != null) {
      message =
          'Tarea "${match.title}" reprogramada para el ${DateFormat('dd/MM/yyyy').format(action.dueDate!)}.';
    } else if (action.newTitle != null) {
      message = 'Tarea "${match.title}" renombrada a "${action.newTitle}".';
    } else {
      message = 'Tarea "${match.title}" actualizada exitosamente.';
    }

    return KevExecutionResult.success(
      userMessage: message,
      actionType: action.actionName,
      entityId: match.id,
      createdItem: updatedTask,
    );
  }

  Future<KevExecutionResult> _handleDeleteTask(DeleteTaskAction action) async {
    final tasks = await taskRepository.fetchTasks();
    final match = LocalEntityResolver.findBestMatch<TaskItem>(
      query: action.query,
      items: tasks,
      titleExtractor: (t) => t.title,
    );

    if (match == null) {
      return KevExecutionResult.failure(
        userMessage:
            'No encontré ninguna tarea que coincida con "${action.query}".',
        actionType: action.actionName,
      );
    }

    await taskRepository.softDeleteTask(match.id);

    return KevExecutionResult.success(
      userMessage: 'Tarea "${match.title}" eliminada.',
      actionType: action.actionName,
      entityId: match.id,
    );
  }

  Future<KevExecutionResult> _handleUpdateNote(UpdateNoteAction action) async {
    final notes = await noteRepository.fetchNotes();
    final match = LocalEntityResolver.findBestMatch<NoteItem>(
      query: action.query,
      items: notes,
      titleExtractor: (n) => n.title,
    );

    if (match == null) {
      return KevExecutionResult.failure(
        userMessage:
            'No encontré ninguna nota que coincida con "${action.query}".',
        actionType: action.actionName,
      );
    }

    if (action.isArchived == true) {
      await noteRepository.softDeleteNote(match.id);
      return KevExecutionResult.success(
        userMessage: 'Nota "${match.title}" archivada.',
        actionType: action.actionName,
        entityId: match.id,
      );
    }

    final newContent =
        action.appendContent != null && action.appendContent!.isNotEmpty
            ? (match.content.isEmpty
                ? action.appendContent!
                : '${match.content}\n${action.appendContent!}')
            : match.content;

    final updatedNote = match.copyWith(
      title: action.newTitle ?? match.title,
      content: newContent,
      isPinned: action.isPinned ?? match.isPinned,
      updatedAt: DateTime.now(),
    );

    await noteRepository.updateNote(updatedNote);

    final String message;
    if (action.isPinned != null) {
      message = action.isPinned!
          ? 'Nota "${match.title}" fijada al inicio.'
          : 'Nota "${match.title}" desfijada.';
    } else if (action.appendContent != null &&
        action.appendContent!.isNotEmpty) {
      message = 'Contenido agregado a la nota "${match.title}".';
    } else if (action.newTitle != null) {
      message = 'Nota "${match.title}" renombrada a "${action.newTitle}".';
    } else {
      message = 'Nota "${match.title}" actualizada exitosamente.';
    }

    return KevExecutionResult.success(
      userMessage: message,
      actionType: action.actionName,
      entityId: match.id,
      createdItem: updatedNote,
    );
  }

  Future<KevExecutionResult> _handleDeleteNote(DeleteNoteAction action) async {
    final notes = await noteRepository.fetchNotes();
    final match = LocalEntityResolver.findBestMatch<NoteItem>(
      query: action.query,
      items: notes,
      titleExtractor: (n) => n.title,
    );

    if (match == null) {
      return KevExecutionResult.failure(
        userMessage:
            'No encontré ninguna nota que coincida con "${action.query}".',
        actionType: action.actionName,
      );
    }

    await noteRepository.softDeleteNote(match.id);

    return KevExecutionResult.success(
      userMessage: 'Nota "${match.title}" eliminada.',
      actionType: action.actionName,
      entityId: match.id,
    );
  }

  Future<KevExecutionResult> _handleUpdateCalendarEvent(
      UpdateCalendarEventAction action) async {
    final events = await calendarRepository.fetchEvents();
    final match = LocalEntityResolver.findBestMatch<CalendarEventItem>(
      query: action.query,
      items: events,
      titleExtractor: (e) => e.title,
    );

    if (match == null) {
      return KevExecutionResult.failure(
        userMessage:
            'No encontré ningún evento que coincida con "${action.query}".',
        actionType: action.actionName,
      );
    }

    final newStartTime = action.newStartTime ?? match.startTime;
    DateTime newEndTime;
    if (action.newEndTime != null) {
      newEndTime = action.newEndTime!;
    } else if (action.newStartTime != null) {
      final prevDuration = match.endTime.difference(match.startTime);
      newEndTime = newStartTime.add(prevDuration > Duration.zero
          ? prevDuration
          : const Duration(hours: 1));
    } else {
      newEndTime = match.endTime;
    }

    if (newEndTime.isBefore(newStartTime)) {
      newEndTime = newStartTime.add(const Duration(hours: 1));
    }

    final updatedEvent = match.copyWith(
      title: action.newTitle ?? match.title,
      startTime: newStartTime,
      endTime: newEndTime,
      isAllDay: action.isAllDay ?? match.isAllDay,
      location: action.location ?? match.location,
      category: action.category ?? match.category,
      updatedAt: DateTime.now(),
    );

    await calendarRepository.updateEvent(updatedEvent);

    final String message;
    if (action.newStartTime != null) {
      message =
          'Evento "${match.title}" reprogramado para el ${DateFormat('dd/MM/yyyy HH:mm').format(newStartTime)}.';
    } else if (action.location != null) {
      message =
          'Ubicación del evento "${match.title}" cambiada a "${action.location}".';
    } else if (action.category != null) {
      message =
          'Categoría del evento "${match.title}" cambiada a "${action.category}".';
    } else {
      message = 'Evento "${match.title}" actualizado exitosamente.';
    }

    return KevExecutionResult.success(
      userMessage: message,
      actionType: action.actionName,
      entityId: match.id,
      createdItem: updatedEvent,
    );
  }

  Future<KevExecutionResult> _handleDeleteCalendarEvent(
      DeleteCalendarEventAction action) async {
    final events = await calendarRepository.fetchEvents();
    final match = LocalEntityResolver.findBestMatch<CalendarEventItem>(
      query: action.query,
      items: events,
      titleExtractor: (e) => e.title,
    );

    if (match == null) {
      return KevExecutionResult.failure(
        userMessage:
            'No encontré ningún evento que coincida con "${action.query}".',
        actionType: action.actionName,
      );
    }

    await calendarRepository.softDeleteEvent(match.id);

    return KevExecutionResult.success(
      userMessage: 'Evento "${match.title}" eliminado del calendario.',
      actionType: action.actionName,
      entityId: match.id,
    );
  }

  Future<KevExecutionResult> _handleUpdateProject(
      UpdateProjectAction action) async {
    final projects = await projectRepository.fetchProjects();
    final match = LocalEntityResolver.findBestMatch<ProjectItem>(
      query: action.query,
      items: projects,
      titleExtractor: (p) => p.name,
    );

    if (match == null) {
      return KevExecutionResult.failure(
        userMessage:
            'No encontré ningún proyecto que coincida con "${action.query}".',
        actionType: action.actionName,
      );
    }

    final updatedProject = match.copyWith(
      name: action.newName ?? match.name,
      description: action.description ?? match.description,
      colorHex: action.colorHex ?? match.colorHex,
      status: action.status ?? match.status,
      updatedAt: DateTime.now(),
    );

    await projectRepository.updateProject(updatedProject);

    final String message;
    if (action.status != null) {
      message =
          'Proyecto "${match.name}" cambiado a estado ${action.status!.label}.';
    } else if (action.newName != null) {
      message = 'Proyecto "${match.name}" renombrado a "${action.newName}".';
    } else {
      message = 'Proyecto "${match.name}" actualizado exitosamente.';
    }

    return KevExecutionResult.success(
      userMessage: message,
      actionType: action.actionName,
      entityId: match.id,
      createdItem: updatedProject,
    );
  }

  Future<KevExecutionResult> _handleDeleteProject(
      DeleteProjectAction action) async {
    final projects = await projectRepository.fetchProjects();
    final match = LocalEntityResolver.findBestMatch<ProjectItem>(
      query: action.query,
      items: projects,
      titleExtractor: (p) => p.name,
    );

    if (match == null) {
      return KevExecutionResult.failure(
        userMessage:
            'No encontré ningún proyecto que coincida con "${action.query}".',
        actionType: action.actionName,
      );
    }

    await projectRepository.softDeleteProject(match.id);

    return KevExecutionResult.success(
      userMessage: 'Proyecto "${match.name}" eliminado.',
      actionType: action.actionName,
      entityId: match.id,
    );
  }
}
