import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';
import 'package:life_os/features/tasks/presentation/tasks_provider.dart';
import 'package:life_os/features/tasks/presentation/tasks_view.dart';

class MockTaskListNotifierMobile extends TaskListNotifier {
  final List<TaskItem> _initialTasks;
  MockTaskListNotifierMobile([this._initialTasks = const []]);

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
  testWidgets(
      'TasksView en pantalla móvil abre Modal Bottom Sheet al tocar una tarea',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
    });

    final sampleTask = TaskItem(
      id: 'task-mobile-1',
      title: 'Soldar módulo I2S del ESP32',
      notes: 'Verificar pines BCLK y LRCK',
      status: TaskStatus.todo,
      priority: 3,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider
              .overrideWith(() => MockTaskListNotifierMobile([sampleTask])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TasksView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // La tarea está visible en la lista
    expect(find.text('Soldar módulo I2S del ESP32'), findsOneWidget);

    // Al tocar la tarea en móvil, se despliega el Modal Bottom Sheet con opciones táctiles
    await tester.tap(find.text('Soldar módulo I2S del ESP32'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verificamos elementos del Bottom Sheet
    expect(find.text('Marcar como Completada'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    expect(find.text('Verificar pines BCLK y LRCK'), findsWidgets);
  });
}
