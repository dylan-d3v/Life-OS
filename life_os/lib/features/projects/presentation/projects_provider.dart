import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../notes/presentation/notes_provider.dart';
import '../../tasks/domain/task_item.dart';
import '../../tasks/presentation/tasks_provider.dart';
import '../data/project_repository.dart';
import '../domain/project_item.dart';

// =============================================================================
// Repositorio
// =============================================================================

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(
    client: ref.watch(supabaseClientProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    vault: ref.watch(keyVaultServiceProvider),
  );
});

// =============================================================================
// Filtro Activo
// =============================================================================

enum ProjectFilter { all, active, paused, completed }

class ProjectFilterNotifier extends Notifier<ProjectFilter> {
  @override
  ProjectFilter build() => ProjectFilter.all;

  void setFilter(ProjectFilter filter) {
    state = filter;
  }
}

final projectFilterProvider =
    NotifierProvider<ProjectFilterNotifier, ProjectFilter>(
  ProjectFilterNotifier.new,
);

// =============================================================================
// Lista de Proyectos
// =============================================================================

class ProjectListNotifier extends AsyncNotifier<List<ProjectItem>> {
  @override
  Future<List<ProjectItem>> build() => _loadProjects();

  Future<List<ProjectItem>> _loadProjects() async {
    final repo = ref.read(projectRepositoryProvider);
    return repo.fetchProjects();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadProjects);
  }

  Future<void> addProject({
    required String name,
    String description = '',
    String colorHex = '#0284C7',
    ProjectStatus status = ProjectStatus.active,
  }) async {
    final repo = ref.read(projectRepositoryProvider);
    final newProject = await repo.createProject(
      name: name,
      description: description,
      colorHex: colorHex,
      status: status,
    );

    state = state.whenData((projects) => [newProject, ...projects]);
  }

  Future<void> updateStatus(String projectId, ProjectStatus newStatus) async {
    final repo = ref.read(projectRepositoryProvider);

    state = state.whenData((projects) {
      return projects.map((p) {
        if (p.id == projectId) return p.copyWith(status: newStatus);
        return p;
      }).toList();
    });

    await repo.updateStatus(projectId, newStatus);
  }

  Future<void> updateProject(ProjectItem project) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.updateProject(project);

    state = state.whenData((projects) {
      return projects.map((p) => p.id == project.id ? project : p).toList();
    });
  }

  Future<void> deleteProject(String projectId) async {
    final repo = ref.read(projectRepositoryProvider);

    state = state.whenData(
      (projects) => projects.where((p) => p.id != projectId).toList(),
    );

    await repo.softDeleteProject(projectId);
  }
}

final projectListProvider =
    AsyncNotifierProvider<ProjectListNotifier, List<ProjectItem>>(
  ProjectListNotifier.new,
);

/// Proveedor filtrado de proyectos según la pestaña seleccionada.
final filteredProjectsProvider =
    Provider<AsyncValue<List<ProjectItem>>>((ref) {
  final filter = ref.watch(projectFilterProvider);
  final projectsAsync = ref.watch(projectListProvider);

  return projectsAsync.whenData((projects) {
    switch (filter) {
      case ProjectFilter.all:
        return projects;
      case ProjectFilter.active:
        return projects
            .where((p) => p.status == ProjectStatus.active)
            .toList();
      case ProjectFilter.paused:
        return projects
            .where((p) => p.status == ProjectStatus.paused)
            .toList();
      case ProjectFilter.completed:
        return projects
            .where((p) => p.status == ProjectStatus.completed)
            .toList();
    }
  });
});

/// Proveedor que indexa los proyectos por su ID en memoria para búsquedas O(1).
final projectMapProvider = Provider<Map<String, ProjectItem>>((ref) {
  final projectsAsync = ref.watch(projectListProvider);
  final projects = projectsAsync.value ?? [];
  return {for (final p in projects) p.id: p};
});

/// Métricas calculadas para un proyecto a partir de sus tareas y notas vinculadas.
class ProjectMetrics {
  final int totalTasks;
  final int completedTasks;
  final int linkedNotes;

  const ProjectMetrics({
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.linkedNotes = 0,
  });

  /// Progreso de tareas entre 0.0 y 1.0
  double get progress =>
      totalTasks == 0 ? 0.0 : (completedTasks / totalTasks).clamp(0.0, 1.0);

  /// Porcentaje de progreso redondeado (0 a 100)
  int get progressPercentage => (progress * 100).round();
}

/// Proveedor reactivo que calcula métricas (tareas totales, tareas completadas, notas)
/// para cada proyecto en memoria sin consultas adicionales a Supabase.
final projectMetricsMapProvider =
    Provider<Map<String, ProjectMetrics>>((ref) {
  final tasks = ref.watch(taskListProvider).value ?? [];
  final notes = ref.watch(noteListProvider).value ?? [];

  final Map<String, int> totalTasks = {};
  final Map<String, int> completedTasks = {};
  final Map<String, int> linkedNotes = {};

  for (final task in tasks) {
    final pid = task.projectId;
    if (pid != null) {
      totalTasks[pid] = (totalTasks[pid] ?? 0) + 1;
      if (task.status == TaskStatus.done) {
        completedTasks[pid] = (completedTasks[pid] ?? 0) + 1;
      }
    }
  }

  for (final note in notes) {
    final pid = note.projectId;
    if (pid != null) {
      linkedNotes[pid] = (linkedNotes[pid] ?? 0) + 1;
    }
  }

  final allProjectIds = {
    ...totalTasks.keys,
    ...completedTasks.keys,
    ...linkedNotes.keys,
  };

  final Map<String, ProjectMetrics> result = {};
  for (final pid in allProjectIds) {
    result[pid] = ProjectMetrics(
      totalTasks: totalTasks[pid] ?? 0,
      completedTasks: completedTasks[pid] ?? 0,
      linkedNotes: linkedNotes[pid] ?? 0,
    );
  }
  return result;
});

