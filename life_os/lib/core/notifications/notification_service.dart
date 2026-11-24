import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/calendar/domain/calendar_event_item.dart';
import '../../features/calendar/presentation/calendar_provider.dart';
import '../../features/settings/presentation/settings_provider.dart';
import '../../features/tasks/domain/task_item.dart';
import '../../features/tasks/presentation/tasks_provider.dart';
import '../providers/crypto_providers.dart';

/// Tipo de origen de un recordatorio programado.
enum ReminderKind {
  task,
  calendarEvent,
  dailySummary,
}

/// Representa un recordatorio programado localmente en el dispositivo.
class ScheduledReminder {
  final int notificationId;
  final String entityKey;
  final ReminderKind kind;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String signature;

  const ScheduledReminder({
    required this.notificationId,
    required this.entityKey,
    required this.kind,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.signature,
  });
}

/// Evento emitido cuando llega la fecha y hora de un recordatorio.
class TriggeredNotification {
  final int notificationId;
  final String entityKey;
  final ReminderKind kind;
  final String title;
  final String body;
  final DateTime triggeredAt;
  final String tone;

  const TriggeredNotification({
    required this.notificationId,
    required this.entityKey,
    required this.kind,
    required this.title,
    required this.body,
    required this.triggeredAt,
    required this.tone,
  });
}

/// Servicio Multiplataforma de Notificaciones Locales (Fase 5 - E1).
///
/// Cumple con el principio Zero-Knowledge: las notificaciones se programan
/// exclusivamente en memoria local una vez que las tareas y eventos han sido
/// descifrados en el dispositivo.
///
/// Garantías:
/// 1. Deduplicación estricta mediante firmas deterministas (`entityKey|timestamp|title`).
/// 2. Cancelación automática inmediata cuando una tarea pasa a completada, se elimina
///    o se desactivan las notificaciones en Ajustes.
/// 3. Reprogramación limpia si la fecha/hora (`dueDate` / `startTime`) o el título cambian.
/// 4. Soporte de tonos configurables (`default`, `chime`, `urgent`, `silent`).
class NotificationService {
  final Map<String, ScheduledReminder> _scheduled = {};
  final Map<String, Timer> _timers = {};
  final Set<String> _firedSignatures = {};
  final List<TriggeredNotification> _triggeredHistory = [];
  final StreamController<TriggeredNotification> _controller =
      StreamController<TriggeredNotification>.broadcast();

  bool _enabled = true;
  String _tone = 'default';
  final DateTime Function() _nowProvider;
  final void Function(TriggeredNotification)? onNotificationTriggered;

  NotificationService({
    DateTime Function()? nowProvider,
    this.onNotificationTriggered,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  /// Flujo reactivo de notificaciones disparadas para mostrar alertas en la UI / OS.
  Stream<TriggeredNotification> get onNotificationStream => _controller.stream;

  /// Lista inmutable de recordatorios actualmente pendientes de disparo.
  List<ScheduledReminder> get scheduledReminders =>
      List.unmodifiable(_scheduled.values);

  /// Historial de notificaciones disparadas durante la sesión.
  List<TriggeredNotification> get triggeredHistory =>
      List.unmodifiable(_triggeredHistory);

  bool get isEnabled => _enabled;
  String get currentTone => _tone;

  /// Genera un ID entero positivo determinista de 31 bits a partir de una clave única.
  static int computeDeterministicId(String key) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < key.length; i++) {
      hash ^= key.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Actualiza la configuración global de notificaciones desde Ajustes (F1 Parte 2).
  void configure({
    required bool enabled,
    required String tone,
  }) {
    _tone = tone;
    if (_enabled != enabled) {
      _enabled = enabled;
      if (!_enabled) {
        cancelAll();
      }
    }
  }

  /// Programa o actualiza un recordatorio individual evitando duplicados.
  /// Retorna `true` si el recordatorio quedó programado, o `false` si fue omitido.
  bool scheduleReminder({
    required String entityKey,
    required ReminderKind kind,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) {
    if (!_enabled) {
      cancelReminder(entityKey);
      return false;
    }

    final now = _nowProvider();
    if (!scheduledAt.isAfter(now)) {
      // No programar recordatorios cuya fecha ya expiró
      cancelReminder(entityKey);
      return false;
    }

    final signature =
        '$entityKey|${scheduledAt.toUtc().toIso8601String()}|$title|$body';

    // Si ya se disparó exactamente esta versión del recordatorio, no duplicar
    if (_firedSignatures.contains(signature)) {
      return false;
    }

    // Si ya está programado con exactamente la misma firma, conservar el timer actual sin duplicar
    final existing = _scheduled[entityKey];
    if (existing != null && existing.signature == signature) {
      return true;
    }

    // Si existía con otra fecha o título, cancelar el anterior antes de reprogramar
    cancelReminder(entityKey);

    final notificationId = computeDeterministicId(entityKey);
    final reminder = ScheduledReminder(
      notificationId: notificationId,
      entityKey: entityKey,
      kind: kind,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      signature: signature,
    );

    _scheduled[entityKey] = reminder;
    final delay = scheduledAt.difference(now);
    _timers[entityKey] = Timer(delay, () {
      _fireReminder(entityKey);
    });

    return true;
  }

  /// Sincroniza la lista completa de tareas con los recordatorios activos:
  /// - Cancela tareas completadas, canceladas, eliminadas o sin `dueDate`.
  /// - Programa o reprograma tareas pendientes con `dueDate` futura.
  void syncTaskReminders(List<TaskItem> tasks) {
    if (!_enabled) {
      cancelByKind(ReminderKind.task);
      return;
    }

    final activeKeys = <String>{};

    for (final task in tasks) {
      final key = 'task:${task.id}';
      final isPending = task.status == TaskStatus.todo ||
          task.status == TaskStatus.inProgress;

      if (isPending && task.dueDate != null && task.deletedAt == null) {
        final scheduled = scheduleReminder(
          entityKey: key,
          kind: ReminderKind.task,
          title: 'Recordatorio de Tarea: ${task.title}',
          body: task.notes.isNotEmpty
              ? task.notes
              : 'Tienes una tarea programada para este momento.',
          scheduledAt: task.dueDate!,
        );
        if (scheduled) {
          activeKeys.add(key);
        }
      } else {
        cancelReminder(key);
      }
    }

    // Cancelar recordatorios de tareas que hayan sido eliminadas de la lista
    final staleKeys = _scheduled.values
        .where((r) => r.kind == ReminderKind.task && !activeKeys.contains(r.entityKey))
        .map((r) => r.entityKey)
        .toList();

    for (final k in staleKeys) {
      cancelReminder(k);
    }
  }

  /// Sincroniza la lista de eventos de calendario con los recordatorios activos.
  void syncCalendarReminders(List<CalendarEventItem> events) {
    if (!_enabled) {
      cancelByKind(ReminderKind.calendarEvent);
      return;
    }

    final activeKeys = <String>{};

    for (final event in events) {
      final key = 'event:${event.id}';
      if (event.deletedAt == null) {
        final scheduled = scheduleReminder(
          entityKey: key,
          kind: ReminderKind.calendarEvent,
          title: 'Evento: ${event.title}',
          body: event.location.isNotEmpty
              ? 'Ubicación: ${event.location}'
              : (event.description.isNotEmpty
                  ? event.description
                  : 'Tu evento programado está por comenzar.'),
          scheduledAt: event.startTime,
        );
        if (scheduled) {
          activeKeys.add(key);
        }
      } else {
        cancelReminder(key);
      }
    }

    final staleKeys = _scheduled.values
        .where((r) =>
            r.kind == ReminderKind.calendarEvent &&
            !activeKeys.contains(r.entityKey))
        .map((r) => r.entityKey)
        .toList();

    for (final k in staleKeys) {
      cancelReminder(k);
    }
  }

  /// Programa el aviso de resumen diario a la hora configurada por el usuario en Ajustes.
  bool scheduleDailySummary({
    required int hour,
    required int minute,
    required int pendingTasksCount,
  }) {
    const key = 'daily:summary';
    if (!_enabled) {
      cancelReminder(key);
      return false;
    }

    final now = _nowProvider();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    return scheduleReminder(
      entityKey: key,
      kind: ReminderKind.dailySummary,
      title: 'Resumen Diario de Life-OS',
      body: pendingTasksCount > 0
          ? 'Tienes $pendingTasksCount tareas pendientes en tu bóveda para hoy.'
          : 'No tienes tareas pendientes acumuladas. ¡Excelente día!',
      scheduledAt: target,
    );
  }

  /// Dispara inmediatamente una notificación de prueba (para verificar tono y alerta desde Ajustes).
  TriggeredNotification triggerTestNotification() {
    final notification = TriggeredNotification(
      notificationId: computeDeterministicId('test:notification'),
      entityKey: 'test:notification',
      kind: ReminderKind.task,
      title: 'Notificación de Prueba — Life-OS',
      body: 'Los recordatorios locales E2EE están activos (Tono: $_tone).',
      triggeredAt: _nowProvider(),
      tone: _tone,
    );
    _deliverNotification(notification);
    return notification;
  }

  void _fireReminder(String entityKey) {
    final reminder = _scheduled.remove(entityKey);
    _timers.remove(entityKey)?.cancel();
    if (reminder == null || !_enabled) return;

    _firedSignatures.add(reminder.signature);

    final notification = TriggeredNotification(
      notificationId: reminder.notificationId,
      entityKey: reminder.entityKey,
      kind: reminder.kind,
      title: reminder.title,
      body: reminder.body,
      triggeredAt: _nowProvider(),
      tone: _tone,
    );

    _deliverNotification(notification);
  }

  void _deliverNotification(TriggeredNotification notification) {
    _triggeredHistory.add(notification);
    _playConfiguredTone(notification.tone);
    onNotificationTriggered?.call(notification);
    if (!_controller.isClosed) {
      _controller.add(notification);
    }
  }

  void _playConfiguredTone(String tone) {
    if (tone == 'silent') return;
    try {
      if (tone == 'urgent' || tone == 'default') {
        SystemSound.play(SystemSoundType.alert).ignore();
      } else {
        SystemSound.play(SystemSoundType.click).ignore();
      }
    } catch (_) {}
  }

  /// Cancela un recordatorio específico por su `entityKey` (ej. `'task:123'`).
  bool cancelReminder(String entityKey) {
    _timers.remove(entityKey)?.cancel();
    return _scheduled.remove(entityKey) != null;
  }

  /// Cancela todos los recordatorios de un tipo determinado.
  void cancelByKind(ReminderKind kind) {
    final keys = _scheduled.values
        .where((r) => r.kind == kind)
        .map((r) => r.entityKey)
        .toList();
    for (final k in keys) {
      cancelReminder(k);
    }
  }

  /// Cancela absolutamente todos los recordatorios pendientes.
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _scheduled.clear();
  }

  void dispose() {
    cancelAll();
    _controller.close();
  }
}

/// Proveedor singleton para el motor de notificaciones locales.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Coordinador reactivo que sincroniza automáticamente las tareas, eventos y
/// preferencias de Ajustes con [NotificationService] cuando la bóveda está desbloqueada.
final notificationCoordinatorProvider = Provider<NotificationService>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final vault = ref.watch(keyVaultServiceProvider);
  final settings = ref.watch(appSettingsProvider);
  final tasksAsync = ref.watch(taskListProvider);
  final eventsAsync = ref.watch(calendarEventListProvider);

  service.configure(
    enabled: settings.notificationsEnabled,
    tone: settings.notificationTone,
  );

  if (!vault.isUnlocked || !settings.notificationsEnabled) {
    service.cancelAll();
    return service;
  }

  final tasks = tasksAsync.value ?? const [];
  final events = eventsAsync.value ?? const [];

  service.syncTaskReminders(tasks);
  service.syncCalendarReminders(events);

  final pendingCount = tasks
      .where((t) =>
          t.status == TaskStatus.todo || t.status == TaskStatus.inProgress)
      .length;
  service.scheduleDailySummary(
    hour: settings.dailyReminderHour,
    minute: settings.dailyReminderMinute,
    pendingTasksCount: pendingCount,
  );

  return service;
});
