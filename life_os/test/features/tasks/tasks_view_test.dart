import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/projects/domain/project_item.dart';
import 'package:life_os/features/projects/presentation/projects_provider.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';
import 'package:life_os/features/tasks/presentation/tasks_provider.dart';
import 'package:life_os/features/tasks/presentation/tasks_view.dart';

// Mock Notifier para pruebas de UI sin necesidad de Supabase activo
class MockTaskListNotifier extends TaskListNotifier {
  final List<TaskItem> _initialTasks;

  MockTaskListNotifier([this._initialTasks = const []]);

  @override
  Future<List<TaskItem>> build() async => _initialTasks;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> toggleStatus(String taskId) async {
    state = state.whenData((tasks) {
      return tasks.map((t) {
        if (t.id != taskId) return t;
        final newStatus =
            t.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done;
        return t.copyWith(status: newStatus);
      }).toList();
    });
  }

  @override
  Future<void> deleteTask(String taskId) async {
    state = state.whenData(
      (tasks) => tasks.where((t) => t.id != taskId).toList(),
    );
  }
}

class MockProjectListNotifier extends ProjectListNotifier {
  final List<ProjectItem> _projects;
  MockProjectListNotifier([this._projects = const []]);

  @override
  Future<List<ProjectItem>> build() async => _projects;
}

void main() {
  testWidgets('TasksView muestra encabezado, filtros y estado vacío inicial',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider.overrideWith(() => MockTaskListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TasksView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Validar encabezado
    expect(find.text('Gestor de Tareas'), findsOneWidget);
    expect(find.text('Nueva Tarea'), findsOneWidget);

    // Validar chips de filtro
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('Completadas'), findsOneWidget);

    // Validar mensaje de estado vacío
    expect(find.textContaining('No tienes tareas aún'), findsOneWidget);
  });

  testWidgets('TasksView muestra lista de tareas y permite interactuar con filtros',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleTasks = [
      TaskItem(
        id: '1',
        title: 'Comprar componentes ESP32',
        notes: 'Buscar display OLED I2C',
        status: TaskStatus.todo,
        priority: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      TaskItem(
        id: '2',
        title: 'Configurar tabla de tareas en Supabase',
        status: TaskStatus.done,
        priority: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider.overrideWith(() => MockTaskListNotifier(sampleTasks)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TasksView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Inicialmente con filtro "Todas", ambas tareas son visibles
    expect(find.text('Comprar componentes ESP32'), findsOneWidget);
    expect(find.text('Configurar tabla de tareas en Supabase'), findsOneWidget);

    // Cambiar filtro a "Pendientes"
    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();

    expect(find.text('Comprar componentes ESP32'), findsOneWidget);
    expect(find.text('Configurar tabla de tareas en Supabase'), findsNothing);

    // Cambiar filtro a "Completadas"
    await tester.tap(find.text('Completadas'));
    await tester.pumpAndSettle();

    expect(find.text('Comprar componentes ESP32'), findsNothing);
    expect(find.text('Configurar tabla de tareas en Supabase'), findsOneWidget);
  });

  testWidgets('TasksView abre diálogo al pulsar "Nueva Tarea"', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider.overrideWith(() => MockTaskListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TasksView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Pulsar botón Nueva Tarea
    await tester.tap(find.text('Nueva Tarea'));
    await tester.pumpAndSettle();

    // Validar que se abrió el modal con los campos
    expect(find.text('Nueva Tarea Cifrada'), findsOneWidget);
    expect(find.text('Título'), findsOneWidget);
    expect(find.text('Notas (opcional)'), findsOneWidget);
    expect(find.text('Proyecto Asociado'), findsOneWidget);
    expect(find.text('Prioridad'), findsOneWidget);
    expect(find.text('Crear Tarea'), findsOneWidget);
  });

  testWidgets('TasksView abre diálogo de edición al hacer doble clic en una tarea',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleTask = TaskItem(
      id: 'task-100',
      title: 'Planificar arquitectura satélite',
      notes: 'Notas de diseño',
      status: TaskStatus.todo,
      priority: 3,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider.overrideWith(() => MockTaskListNotifier([sampleTask])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TasksView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Validar que la tarea aparece
    final taskFinder = find.text('Planificar arquitectura satélite');
    expect(taskFinder, findsOneWidget);

    // Hacer doble clic (doble tap) sobre la tarea
    await tester.tap(taskFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(taskFinder);
    await tester.pumpAndSettle();

    // Validar que se abrió en modo edición
    expect(find.text('Editar Tarea Cifrada'), findsOneWidget);
    expect(find.text('Guardar Cambios'), findsOneWidget);
    expect(find.text('Planificar arquitectura satélite'), findsWidgets);
  });

  testWidgets('TasksView abre diálogo de edición al pulsar el botón de editar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleTask = TaskItem(
      id: 'task-101',
      title: 'Revisar PR de autenticación',
      status: TaskStatus.todo,
      priority: 2,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider.overrideWith(() => MockTaskListNotifier([sampleTask])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TasksView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Pulsar botón de editar (icono edit_outlined)
    final editButton = find.byIcon(Icons.edit_outlined);
    expect(editButton, findsOneWidget);

    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Editar Tarea Cifrada'), findsOneWidget);
    expect(find.text('Guardar Cambios'), findsOneWidget);
  });

  testWidgets(
      'TasksView renderiza badge de proyecto asociado en la tarjeta de tarea',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleProject = ProjectItem(
      id: 'proj-99',
      name: 'Satélite Cubesat',
      colorHex: '#10B981',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleTask = TaskItem(
      id: 'task-303',
      title: 'Soldar módulo de radio',
      status: TaskStatus.todo,
      priority: 3,
      projectId: 'proj-99',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider
              .overrideWith(() => MockTaskListNotifier([sampleTask])),
          projectListProvider
              .overrideWith(() => MockProjectListNotifier([sampleProject])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TasksView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Soldar módulo de radio'), findsOneWidget);
    expect(find.text('Satélite Cubesat'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
  });

  testWidgets('TasksView permite filtrar tareas por proyecto seleccionado',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final projA = ProjectItem(
      id: 'proj-a',
      name: 'Proyecto Alpha',
      colorHex: '#3B82F6',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final projB = ProjectItem(
      id: 'proj-b',
      name: 'Proyecto Beta',
      colorHex: '#10B981',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final taskA = TaskItem(
      id: 'task-1',
      title: 'Tarea del proyecto Alpha',
      status: TaskStatus.todo,
      projectId: 'proj-a',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final taskB = TaskItem(
      id: 'task-2',
      title: 'Tarea del proyecto Beta',
      status: TaskStatus.todo,
      projectId: 'proj-b',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider
              .overrideWith(() => MockTaskListNotifier([taskA, taskB])),
          projectListProvider
              .overrideWith(() => MockProjectListNotifier([projA, projB])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TasksView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Inicialmente ambas tareas visibles
    expect(find.text('Tarea del proyecto Alpha'), findsOneWidget);
    expect(find.text('Tarea del proyecto Beta'), findsOneWidget);

    // Abrir dropdown y seleccionar "Proyecto Alpha"
    await tester.tap(find.text('Todos los proyectos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proyecto Alpha').last);
    await tester.pumpAndSettle();

    // Solo la tarea de Alpha debe ser visible
    expect(find.text('Tarea del proyecto Alpha'), findsOneWidget);
    expect(find.text('Tarea del proyecto Beta'), findsNothing);
  });
}
