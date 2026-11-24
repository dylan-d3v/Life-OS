import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/notifications/notification_service.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Tests (Fase 5 - E1)', () {
    late DateTime currentNow;
    late List<TriggeredNotification> triggered;
    late NotificationService service;

    setUp(() {
      currentNow = DateTime(2026, 11, 24, 10, 0, 0);
      triggered = [];
      service = NotificationService(
        nowProvider: () => currentNow,
        onNotificationTriggered: triggered.add,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test(
        'programa recordatorios futuros, evita duplicados con la misma firma y cancela al completarse la tarea',
        () {
      final futureDue = currentNow.add(const Duration(minutes: 30));
      final task = TaskItem(
        id: 'task-notif-1',
        title: 'Llamar al proveedor de PCB',
        notes: 'Confirmar espesor 1.6mm',
        status: TaskStatus.todo,
        dueDate: futureDue,
        createdAt: currentNow,
        updatedAt: currentNow,
      );

      // 1. Sincronizamos la lista con 1 tarea pendiente con recordatorio futuro
      service.syncTaskReminders([task]);
      expect(service.scheduledReminders.length, equals(1));
      final firstId = service.scheduledReminders.first.notificationId;

      // 2. Si volvemos a sincronizar la misma tarea sin cambios, NO se duplica
      service.syncTaskReminders([task]);
      expect(service.scheduledReminders.length, equals(1));
      expect(service.scheduledReminders.first.notificationId, equals(firstId));

      // 3. Si la tarea se marca como completada (TaskStatus.done), se cancela automáticamente su recordatorio
      final completedTask = task.copyWith(status: TaskStatus.done);
      service.syncTaskReminders([completedTask]);
      expect(service.scheduledReminders, isEmpty);
    });

    test(
        'dispara la notificación al llegar la hora programada y no vuelve a programarla como duplicada',
        () async {
      final dueSoon = currentNow.add(const Duration(milliseconds: 40));
      final task = TaskItem(
        id: 'task-fire-1',
        title: 'Revisar batería LiPo del ESP32',
        status: TaskStatus.todo,
        dueDate: dueSoon,
        createdAt: currentNow,
        updatedAt: currentNow,
      );

      service.syncTaskReminders([task]);
      expect(service.scheduledReminders.length, equals(1));

      // Esperamos a que llegue el momento del recordatorio
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(triggered.length, equals(1));
      expect(triggered.first.title, contains('Revisar batería LiPo del ESP32'));
      expect(service.scheduledReminders, isEmpty);

      // Si se intenta volver a sincronizar exactamente la misma tarea ya disparada, se ignora para evitar duplicados
      service.syncTaskReminders([task]);
      expect(service.scheduledReminders, isEmpty);
    });

    test('desactivar notificaciones en Ajustes cancela todos los avisos pendientes',
        () {
      final task = TaskItem(
        id: 'task-cfg-1',
        title: 'Tarea con aviso',
        status: TaskStatus.todo,
        dueDate: currentNow.add(const Duration(hours: 2)),
        createdAt: currentNow,
        updatedAt: currentNow,
      );

      service.syncTaskReminders([task]);
      service.scheduleDailySummary(
        hour: 9,
        minute: 0,
        pendingTasksCount: 1,
      );
      expect(service.scheduledReminders.length, equals(2));

      // Desactivamos las notificaciones (F1 Parte 2)
      service.configure(enabled: false, tone: 'silent');
      expect(service.scheduledReminders, isEmpty);
    });
  });
}
