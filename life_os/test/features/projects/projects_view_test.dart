import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/notes/domain/note_item.dart';
import 'package:life_os/features/notes/presentation/notes_provider.dart';
import 'package:life_os/features/projects/domain/project_item.dart';
import 'package:life_os/features/projects/presentation/projects_provider.dart';
import 'package:life_os/features/projects/presentation/projects_view.dart';
import 'package:life_os/features/shell/presentation/navigation_provider.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';
import 'package:life_os/features/tasks/presentation/tasks_provider.dart';

class MockProjectListNotifier extends ProjectListNotifier {
  final List<ProjectItem> _initialProjects;

  MockProjectListNotifier([this._initialProjects = const []]);

  @override
  Future<List<ProjectItem>> build() async => _initialProjects;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> updateStatus(String projectId, ProjectStatus newStatus) async {
    state = state.whenData((projects) {
      return projects.map((p) {
        if (p.id == projectId) return p.copyWith(status: newStatus);
        return p;
      }).toList();
    });
  }

  @override
  Future<void> deleteProject(String projectId) async {
    state = state.whenData(
      (projects) => projects.where((p) => p.id != projectId).toList(),
    );
  }
}

class MockTaskListNotifier extends TaskListNotifier {
  final List<TaskItem> _tasks;
  MockTaskListNotifier([this._tasks = const []]);

  @override
  Future<List<TaskItem>> build() async => _tasks;
}

class MockNoteListNotifier extends NoteListNotifier {
  final List<NoteItem> _notes;
  MockNoteListNotifier([this._notes = const []]);

  @override
  Future<List<NoteItem>> build() async => _notes;
}

void main() {
  testWidgets('ProjectsView muestra encabezado, filtros y estado vacío inicial',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider
              .overrideWith(() => MockProjectListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProjectsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Proyectos y Metas'), findsOneWidget);
    expect(find.text('Nuevo Proyecto'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Activos'), findsOneWidget);
    expect(find.text('Pausados'), findsOneWidget);
    expect(find.text('Completados'), findsOneWidget);
    expect(find.textContaining('No tienes proyectos aún'), findsOneWidget);
  });

  testWidgets('ProjectsView muestra tarjetas de proyectos y filtra por estado',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleProjects = [
      ProjectItem(
        id: '1',
        name: 'MVP de Escritorio Flutter',
        description: 'Construcción de interfaz y capa E2EE',
        colorHex: '#0284C7',
        status: ProjectStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProjectItem(
        id: '2',
        name: 'Fase 2 de Base de Datos',
        description: 'Configuración de tablas y RLS en Supabase',
        colorHex: '#10B981',
        status: ProjectStatus.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider
              .overrideWith(() => MockProjectListNotifier(sampleProjects)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProjectsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Filtro "Todos" muestra ambos
    expect(find.text('MVP de Escritorio Flutter'), findsOneWidget);
    expect(find.text('Fase 2 de Base de Datos'), findsOneWidget);

    // Filtrar por "Activos"
    await tester.tap(find.text('Activos'));
    await tester.pumpAndSettle();

    expect(find.text('MVP de Escritorio Flutter'), findsOneWidget);
    expect(find.text('Fase 2 de Base de Datos'), findsNothing);

    // Filtrar por "Completados"
    await tester.tap(find.text('Completados'));
    await tester.pumpAndSettle();

    expect(find.text('MVP de Escritorio Flutter'), findsNothing);
    expect(find.text('Fase 2 de Base de Datos'), findsOneWidget);
  });

  testWidgets('ProjectsView abre diálogo modal al pulsar "Nuevo Proyecto"',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider
              .overrideWith(() => MockProjectListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProjectsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo Proyecto'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo Proyecto Cifrado'), findsOneWidget);
    expect(find.text('Nombre del proyecto'), findsOneWidget);
    expect(find.text('Descripción y objetivos'), findsOneWidget);
    expect(find.text('Color distintivo'), findsOneWidget);
    expect(find.text('Crear Proyecto'), findsOneWidget);
  });

  testWidgets(
      'ProjectsView muestra barra de progreso de tareas y pills de métricas vinculadas',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleProject = ProjectItem(
      id: 'proj-10',
      name: 'Sistema Satelital',
      description: 'Control de telemetría',
      colorHex: '#38BDF8',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleTasks = [
      TaskItem(
        id: 't1',
        title: 'Diseño PCB',
        status: TaskStatus.done,
        projectId: 'proj-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      TaskItem(
        id: 't2',
        title: 'Soldar componentes',
        status: TaskStatus.todo,
        projectId: 'proj-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final sampleNotes = [
      NoteItem(
        id: 'n1',
        title: 'Frecuencias de radio',
        content: 'Banda UHF 437MHz',
        projectId: 'proj-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      NoteItem(
        id: 'n2',
        title: 'Esquema de pines',
        content: 'I2C en GPIO 21 y 22',
        projectId: 'proj-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider
              .overrideWith(() => MockProjectListNotifier([sampleProject])),
          taskListProvider
              .overrideWith(() => MockTaskListNotifier(sampleTasks)),
          noteListProvider
              .overrideWith(() => MockNoteListNotifier(sampleNotes)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProjectsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Validar nombre del proyecto
    expect(find.text('Sistema Satelital'), findsOneWidget);

    // Validar progreso calculado (1 de 2 = 50%)
    expect(find.text('Progreso: 50% (1/2 tareas)'), findsOneWidget);

    // Validar pills de conteo
    expect(find.text('1/2 tareas'), findsOneWidget);
    expect(find.text('2 notas'), findsOneWidget);
  });

  testWidgets(
      'ProjectsView al pulsar pill de tareas o notas pre-filtra y navega a la sección',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleProject = ProjectItem(
      id: 'proj-20',
      name: 'Life-OS Desktop',
      colorHex: '#0284C7',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleTasks = [
      TaskItem(
        id: 't1',
        title: 'Test Task',
        status: TaskStatus.done,
        projectId: 'proj-20',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final sampleNotes = [
      NoteItem(
        id: 'n1',
        title: 'Test Note',
        projectId: 'proj-20',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        projectListProvider
            .overrideWith(() => MockProjectListNotifier([sampleProject])),
        taskListProvider.overrideWith(() => MockTaskListNotifier(sampleTasks)),
        noteListProvider.overrideWith(() => MockNoteListNotifier(sampleNotes)),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ProjectsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Pulsar en el pill de tareas
    await tester.tap(find.text('1/1 tareas'));
    await tester.pumpAndSettle();

    // Validar cambio de sección y filtro activo
    expect(container.read(activeSectionProvider), NavSection.tasks);
    expect(container.read(taskProjectFilterProvider), 'proj-20');

    // 2. Pulsar en el pill de notas
    await tester.tap(find.text('1 notas'));
    await tester.pumpAndSettle();

    // Validar cambio de sección y filtro activo
    expect(container.read(activeSectionProvider), NavSection.notes);
    expect(container.read(noteProjectFilterProvider), 'proj-20');
  });
}

