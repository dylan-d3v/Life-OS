import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../calendar/presentation/calendar_provider.dart';
import '../../tasks/domain/task_item.dart';
import '../../tasks/presentation/tasks_provider.dart';
import 'kev_command_bar_dialog.dart';
import 'widgets/daily_briefing_card.dart';

/// Vista de "Hoy / Briefing" optimizada para smartphones y resumen diario.
///
/// Presenta:
/// 1. Saludo matutino con fecha actual.
/// 2. Tarjeta interactiva del Briefing Inteligente de Kev (E2EE descifrado local).
/// 3. Lista táctil de tareas urgentes y que vencen hoy.
/// 4. Eventos programados para la jornada.
class TodayBriefingView extends ConsumerWidget {
  const TodayBriefingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM').format(now);
    final capitalizedDate = dateStr.isNotEmpty
        ? dateStr[0].toUpperCase() + dateStr.substring(1)
        : dateStr;

    final tasksAsync = ref.watch(taskListProvider);
    final calendarEventsAsync = ref.watch(calendarWorkspaceEventsProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado de Bienvenida ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Life-OS • Hoy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      capitalizedDate,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Preguntar a Kev',
                icon: const Icon(Icons.auto_awesome, color: Color(0xFF818CF8)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                ),
                onPressed: () => showKevCommandBar(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Tarjeta de Briefing Diario E2EE ──
          const DailyBriefingCard(),

          const SizedBox(height: 8),

          // ── Tareas Prioritarias de Hoy ──
          const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text(
                'Tareas Prioritarias',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          tasksAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Error al cargar tareas: $err',
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
              ),
            ),
            data: (tasks) {
              final todayTasks = tasks.where((t) {
                if (t.status == TaskStatus.done) return false;
                if (t.priority >= 3) return true;
                if (t.dueDate != null) {
                  final due = t.dueDate!;
                  return due.year == now.year &&
                      due.month == now.month &&
                      due.day == now.day;
                }
                return false;
              }).toList();

              if (todayTasks.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Center(
                    child: Text(
                      'No tienes tareas urgentes pendientes para hoy. ¡Excelente!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                );
              }

              return Column(
                children: todayTasks.map((t) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: t.priority >= 4
                            ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: t.status == TaskStatus.done,
                          activeColor: const Color(0xFF22C55E),
                          onChanged: (_) {
                            ref
                                .read(taskListProvider.notifier)
                                .toggleStatus(t.id);
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (t.dueDate != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Vence: ${DateFormat('d MMM, HH:mm').format(t.dueDate!)}',
                                  style: TextStyle(
                                    color: t.dueDate!.isBefore(now)
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Eventos de la Jornada ──
          const Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 18, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text(
                'Eventos de Hoy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          calendarEventsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => const SizedBox.shrink(),
            data: (events) {
              final todayEvents = events.where((e) {
                final d = e.startTime;
                return d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;
              }).toList();

              if (todayEvents.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Center(
                    child: Text(
                      'No hay eventos programados en el calendario para hoy.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                );
              }

              return Column(
                children: todayEvents.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${DateFormat('HH:mm').format(e.startTime)} - ${DateFormat('HH:mm').format(e.endTime)}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
