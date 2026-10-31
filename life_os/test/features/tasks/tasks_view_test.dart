import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Prioridad'), findsOneWidget);
    expect(find.text('Crear Tarea'), findsOneWidget);
  });
}
