import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/supabase_providers.dart';
import '../data/task_repository.dart';
import '../domain/task_item.dart';

// =============================================================================
// Repositorio
// =============================================================================

/// Proveedor del repositorio de tareas con inyección de dependencias E2EE.
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    client: ref.watch(supabaseClientProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    vault: ref.watch(keyVaultServiceProvider),
  );
});

// =============================================================================
// Filtro activo y Búsqueda
// =============================================================================

/// Filtro seleccionado actualmente en la vista de tareas.
enum TaskFilter {
  all,
  pending,
  done,
  today,
  overdue,
}

/// Notifier para el filtro activo de tareas.
class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void setFilter(TaskFilter filter) {
    state = filter;
  }
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

/// Notifier para el filtro por proyecto asociado (null = todos los proyectos).
class TaskProjectFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setProject(String? projectId) {
    state = projectId;
  }
}

final taskProjectFilterProvider =
    NotifierProvider<TaskProjectFilterNotifier, String?>(
  TaskProjectFilterNotifier.new,
);

/// Notifier para el texto de búsqueda de tareas.
class TaskSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final taskSearchQueryProvider =
    NotifierProvider<TaskSearchQueryNotifier, String>(
  TaskSearchQueryNotifier.new,
);

/// Notifier para la tarea seleccionada en el panel lateral derecho (null = Daily Briefing).
class SelectedTaskIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? taskId) {
    state = taskId;
  }

  void clear() {
    state = null;
  }
}

final selectedTaskIdProvider =
    NotifierProvider<SelectedTaskIdNotifier, String?>(
  SelectedTaskIdNotifier.new,
);

/// Proveedor de la tarea seleccionada actualmente en el panel lateral.
final selectedTaskItemProvider = Provider<TaskItem?>((ref) {
  final selectedId = ref.watch(selectedTaskIdProvider);
  if (selectedId == null) return null;
  final tasksAsync = ref.watch(taskListProvider);
  return tasksAsync.value?.where((t) => t.id == selectedId).firstOrNull;
});

// =============================================================================
// Métricas y Resumen de Tareas
// =============================================================================

/// Métricas calculadas para las tarjetas de resumen compactas del gestor de tareas.
class TaskSummaryMetrics {
  final int totalCount;
  final int pendingCount;
  final int completedCount;
  final int todayCount;
  final int overdueCount;

  const TaskSummaryMetrics({
    this.totalCount = 0,
    this.pendingCount = 0,
    this.completedCount = 0,
    this.todayCount = 0,
    this.overdueCount = 0,
  });

  double get completionRatio =>
      totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);

  int get progressPercentage => (completionRatio * 100).round();
}

/// Proveedor derivado que calcula las métricas de resumen para las tareas
/// teniendo en cuenta el filtro por proyecto activo.
final taskSummaryMetricsProvider = Provider<TaskSummaryMetrics>((ref) {
  final tasksAsync = ref.watch(taskListProvider);
  final tasks = tasksAsync.value ?? [];
  final projectFilter = ref.watch(taskProjectFilterProvider);

  final scopedTasks = projectFilter != null
      ? tasks.where((t) => t.projectId == projectFilter).toList()
      : tasks;

  final now = DateTime.now();
  int pending = 0;
  int completed = 0;
  int today = 0;
  int overdue = 0;

  for (final t in scopedTasks) {
    final isDone = t.status == TaskStatus.done;
    if (isDone) {
      completed++;
    } else {
      pending++;
      if (t.dueDate != null) {
        final due = t.dueDate!;
        final isDueToday = due.year == now.year &&
            due.month == now.month &&
            due.day == now.day;
        if (isDueToday) {
          today++;
        } else if (due.isBefore(now)) {
          overdue++;
        }
      }
    }
  }

  return TaskSummaryMetrics(
    totalCount: scopedTasks.length,
    pendingCount: pending,
    completedCount: completed,
    todayCount: today,
    overdueCount: overdue,
  );
});

// =============================================================================
// Lista de tareas
// =============================================================================

/// Notifier asíncrono que gestiona la lista de tareas del usuario.
/// Carga las tareas desde Supabase, las descifra localmente, y expone
/// operaciones CRUD seguras.
class TaskListNotifier extends AsyncNotifier<List<TaskItem>> {
  @override
  Future<List<TaskItem>> build() => _loadTasks();

  Future<List<TaskItem>> _loadTasks() async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.fetchTasks();
  }

  /// Recarga la lista completa desde Supabase.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadTasks);
  }

  /// Crea una nueva tarea, la cifra y la envía a Supabase.
  Future<void> addTask({
    required String title,
    String notes = '',
    int priority = 2,
    DateTime? dueDate,
    String? projectId,
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    final newTask = await repo.createTask(
      title: title,
      notes: notes,
      priority: priority,
      dueDate: dueDate,
      projectId: projectId,
    );

    // Añadir al inicio de la lista local sin recargar todo
    state = state.whenData((tasks) => [newTask, ...tasks]);
  }

  /// Alterna el estado de una tarea entre pendiente y completada.
  Future<void> toggleStatus(String taskId) async {
    final repo = ref.read(taskRepositoryProvider);

    state = state.whenData((tasks) {
      return tasks.map((t) {
        if (t.id != taskId) return t;
        final newStatus =
            t.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done;
        return t.copyWith(status: newStatus);
      }).toList();
    });

    // Encontrar el estado actualizado y persistirlo
    final currentTasks = state.value ?? [];
    final updated = currentTasks.where((t) => t.id == taskId).firstOrNull;
    if (updated != null) {
      await repo.updateStatus(taskId, updated.status);
    }
  }

  /// Elimina una tarea de forma suave (soft delete).
  Future<void> deleteTask(String taskId) async {
    final repo = ref.read(taskRepositoryProvider);

    // Si la tarea eliminada estaba abierta en el panel de detalle, deseleccionarla
    if (ref.read(selectedTaskIdProvider) == taskId) {
      ref.read(selectedTaskIdProvider.notifier).clear();
    }

    // Remover localmente de inmediato para UX responsiva
    state = state.whenData(
      (tasks) => tasks.where((t) => t.id != taskId).toList(),
    );

    await repo.softDeleteTask(taskId);
  }

  /// Actualiza una tarea existente re-cifrando sus campos sensibles.
  Future<void> updateTask(TaskItem task) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.updateTask(task);

    state = state.whenData((tasks) {
      return tasks.map((t) => t.id == task.id ? task : t).toList();
    });
  }
}

final taskListProvider =
    AsyncNotifierProvider<TaskListNotifier, List<TaskItem>>(
  TaskListNotifier.new,
);

/// Proveedor derivado que aplica el filtro activo, filtro de proyecto y búsqueda a la lista de tareas.
final filteredTasksProvider = Provider<AsyncValue<List<TaskItem>>>((ref) {
  final filter = ref.watch(taskFilterProvider);
  final projectFilter = ref.watch(taskProjectFilterProvider);
  final searchQuery = ref.watch(taskSearchQueryProvider).trim().toLowerCase();
  final tasksAsync = ref.watch(taskListProvider);

  return tasksAsync.whenData((tasks) {
    var result = tasks;

    // 1. Filtro por estado / categoría
    final now = DateTime.now();
    switch (filter) {
      case TaskFilter.all:
        break;
      case TaskFilter.pending:
        result = result
            .where((t) =>
                t.status == TaskStatus.todo ||
                t.status == TaskStatus.inProgress)
            .toList();
        break;
      case TaskFilter.done:
        result = result.where((t) => t.status == TaskStatus.done).toList();
        break;
      case TaskFilter.today:
        result = result.where((t) {
          if (t.status == TaskStatus.done || t.dueDate == null) return false;
          final due = t.dueDate!;
          return due.year == now.year &&
              due.month == now.month &&
              due.day == now.day;
        }).toList();
        break;
      case TaskFilter.overdue:
        result = result.where((t) {
          if (t.status == TaskStatus.done || t.dueDate == null) return false;
          final due = t.dueDate!;
          final isToday = due.year == now.year &&
              due.month == now.month &&
              due.day == now.day;
          return due.isBefore(now) && !isToday;
        }).toList();
        break;
    }

    // 2. Filtro por proyecto
    if (projectFilter != null) {
      result = result.where((t) => t.projectId == projectFilter).toList();
    }

    // 3. Filtro por búsqueda textual
    if (searchQuery.isNotEmpty) {
      result = result.where((t) {
        final titleMatch = t.title.toLowerCase().contains(searchQuery);
        final notesMatch = t.notes.toLowerCase().contains(searchQuery);
        return titleMatch || notesMatch;
      }).toList();
    }

    return result;
  });
});

