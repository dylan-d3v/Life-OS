import 'package:intl/intl.dart';
import '../../../core/crypto/crypto.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/domain/calendar_event_item.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_transaction_item.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task_item.dart';
import '../domain/daily_briefing.dart';

/// Servicio responsable de generar el briefing matutino y resúmenes diarios inteligentes.
///
/// Consulta los repositorios de tareas, calendario y finanzas, descifrando la
/// información sensible en memoria mediante la clave activa del usuario en [vault],
/// y sintetiza un informe conciso apto para pantalla o voz TTS (ESP32).
class DailyBriefingService {
  final TaskRepository taskRepository;
  final CalendarRepository calendarRepository;
  final FinanceRepository financeRepository;
  final KeyVaultService vault;

  DailyBriefingService({
    required this.taskRepository,
    required this.calendarRepository,
    required this.financeRepository,
    required this.vault,
  });

  /// Genera el briefing diario para la fecha indicada (por defecto hoy).
  Future<DailyBriefing> generateBriefing({DateTime? forDate}) async {
    final target = forDate ?? DateTime.now();

    // 1. Verificación de seguridad E2EE
    if (!vault.isUnlocked) {
      return DailyBriefing.locked(target);
    }

    try {
      // 2. Cargar y filtrar tareas pendientes
      final allTasks = await taskRepository.fetchTasks();
      final pendingTasks =
          allTasks.where((t) => t.status != TaskStatus.done).toList();
      final urgentTasks =
          pendingTasks.where((t) => t.priority >= 3).toList();

      // 3. Cargar y filtrar eventos del calendario para la fecha objetivo
      final allEvents = await calendarRepository.fetchEvents();
      final todayEvents = allEvents.where((e) {
        return e.startTime.year == target.year &&
            e.startTime.month == target.month &&
            e.startTime.day == target.day;
      }).toList();
      todayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      // 4. Cargar y filtrar transacciones financieras del día
      final allTransactions = await financeRepository.fetchTransactions();
      final todayTransactions = allTransactions.where((tx) {
        return tx.transactionDate.year == target.year &&
            tx.transactionDate.month == target.month &&
            tx.transactionDate.day == target.day;
      }).toList();

      double todayExpenses = 0.0;
      double todayIncome = 0.0;
      for (final tx in todayTransactions) {
        if (tx.type == TransactionType.expense) {
          todayExpenses += tx.amount;
        } else if (tx.type == TransactionType.income) {
          todayIncome += tx.amount;
        }
      }

      // 5. Sintetizar resúmenes (texto estructurado y voz TTS)
      final summary = _buildStructuredSummary(
        target: target,
        pendingTasks: pendingTasks,
        urgentTasks: urgentTasks,
        todayEvents: todayEvents,
        todayExpenses: todayExpenses,
      );

      final tts = _buildTtsMessage(
        pendingTasks: pendingTasks,
        urgentTasks: urgentTasks,
        todayEvents: todayEvents,
      );

      return DailyBriefing(
        date: target,
        pendingTasks: pendingTasks,
        urgentTasks: urgentTasks,
        todayEvents: todayEvents,
        todayExpenses: todayExpenses,
        todayIncome: todayIncome,
        formattedSummary: summary,
        ttsMessage: tts,
      );
    } catch (_) {
      return DailyBriefing.empty(target);
    }
  }

  String _buildStructuredSummary({
    required DateTime target,
    required List<TaskItem> pendingTasks,
    required List<TaskItem> urgentTasks,
    required List<CalendarEventItem> todayEvents,
    required double todayExpenses,
  }) {
    final buffer = StringBuffer();
    final dateStr = DateFormat('dd/MM/yyyy').format(target);
    buffer.writeln('📋 Resumen del día ($dateStr):');

    if (pendingTasks.isEmpty) {
      buffer.writeln('• No tienes tareas pendientes.');
    } else {
      final urgentPart = urgentTasks.isNotEmpty
          ? ' (${urgentTasks.length} de alta prioridad)'
          : '';
      buffer.writeln(
          '• ${pendingTasks.length} tarea(s) pendiente(s)$urgentPart.');
    }

    if (todayEvents.isEmpty) {
      buffer.writeln('• No tienes eventos agendados para hoy.');
    } else {
      buffer.writeln('• ${todayEvents.length} evento(s) hoy:');
      for (final event in todayEvents.take(3)) {
        final timeStr = DateFormat('HH:mm').format(event.startTime);
        buffer.writeln('  - $timeStr: "${event.title}"');
      }
    }

    if (todayExpenses > 0) {
      buffer.writeln(
          '• Gastos registrados hoy: \$${todayExpenses.toStringAsFixed(2)}.');
    }

    return buffer.toString().trim();
  }

  String _buildTtsMessage({
    required List<TaskItem> pendingTasks,
    required List<TaskItem> urgentTasks,
    required List<CalendarEventItem> todayEvents,
  }) {
    final taskPart = pendingTasks.isEmpty
        ? 'No tienes tareas pendientes'
        : 'Tienes ${pendingTasks.length} tareas pendientes, ${urgentTasks.length} urgentes';

    final eventPart = todayEvents.isEmpty
        ? 'y ningún evento en el calendario'
        : 'y ${todayEvents.length} eventos hoy, el próximo a las ${DateFormat('HH:mm').format(todayEvents.first.startTime)}';

    return '$taskPart $eventPart.';
  }
}

