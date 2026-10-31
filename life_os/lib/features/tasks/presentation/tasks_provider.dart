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
// Filtro activo
// =============================================================================

/// Filtro seleccionado actualmente en la vista de tareas.
enum TaskFilter { all, pending, done }

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
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    final newTask = await repo.createTask(
      title: title,
      notes: notes,
      priority: priority,
      dueDate: dueDate,
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

/// Proveedor derivado que aplica el filtro activo a la lista de tareas.
final filteredTasksProvider = Provider<AsyncValue<List<TaskItem>>>((ref) {
  final filter = ref.watch(taskFilterProvider);
  final tasksAsync = ref.watch(taskListProvider);

  return tasksAsync.whenData((tasks) {
    switch (filter) {
      case TaskFilter.all:
        return tasks;
      case TaskFilter.pending:
        return tasks
            .where((t) =>
                t.status == TaskStatus.todo ||
                t.status == TaskStatus.inProgress)
            .toList();
      case TaskFilter.done:
        return tasks.where((t) => t.status == TaskStatus.done).toList();
    }
  });
});

