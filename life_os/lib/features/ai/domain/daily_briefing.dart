import '../../calendar/domain/calendar_event_item.dart';
import '../../tasks/domain/task_item.dart';

/// Modelo de dominio que representa el resumen diario inteligente (Daily Briefing).
///
/// Agrupa y sintetiza de forma local las tareas pendientes, eventos agendados y
/// actividad financiera del día sin exponer información en claro fuera del dispositivo.
class DailyBriefing {
  final DateTime date;
  final List<TaskItem> pendingTasks;
  final List<TaskItem> urgentTasks;
  final List<CalendarEventItem> todayEvents;
  final double todayExpenses;
  final double todayIncome;
  final String formattedSummary;
  final String ttsMessage;
  final bool isLocked;

  const DailyBriefing({
    required this.date,
    this.pendingTasks = const [],
    this.urgentTasks = const [],
    this.todayEvents = const [],
    this.todayExpenses = 0.0,
    this.todayIncome = 0.0,
    required this.formattedSummary,
    required this.ttsMessage,
    this.isLocked = false,
  });

  factory DailyBriefing.locked(DateTime date) {
    return DailyBriefing(
      date: date,
      isLocked: true,
      formattedSummary:
          'Bóveda de seguridad bloqueada. Desbloquea con tu contraseña maestra para ver el resumen del día.',
      ttsMessage:
          'Bóveda bloqueada. Desbloquea con tu contraseña maestra para escuchar tu resumen.',
    );
  }

  factory DailyBriefing.empty(DateTime date) {
    return DailyBriefing(
      date: date,
      formattedSummary: 'No hay actividades ni eventos registrados para este día.',
      ttsMessage: 'No tienes actividades ni eventos registrados para este día.',
    );
  }
}

