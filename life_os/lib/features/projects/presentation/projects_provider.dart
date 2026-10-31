import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/supabase_providers.dart';
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

