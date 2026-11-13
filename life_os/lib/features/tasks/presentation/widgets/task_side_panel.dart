import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../ai/presentation/ai_providers.dart';
import '../../../ai/presentation/kev_command_bar_dialog.dart';
import '../../../projects/presentation/projects_provider.dart';
import '../../domain/task_item.dart';
import '../tasks_provider.dart';

/// Panel lateral derecho inteligente y dinámico del Task Workspace.
///
/// Presenta dos estados principales alternados con animación suave:
/// - **Estado A (por defecto):** Briefing Diario compacto de Kev con tareas de hoy,
///   próximas y progreso general.
/// - **Estado B:** Detalle completo de la tarea seleccionada con acciones directas
///   (marcar completada, editar, eliminar y volver).
class TaskSidePanel extends ConsumerWidget {
  const TaskSidePanel({
    super.key,
    required this.onEditTask,
  });

  final void Function(TaskItem task) onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTask = ref.watch(selectedTaskItemProvider);

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900
        border: Border(
          left: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: selectedTask == null
            ? const _DailyBriefingSubPanel(key: ValueKey('panel_briefing'))
            : _TaskDetailSubPanel(
                key: ValueKey('panel_detail_${selectedTask.id}'),
                task: selectedTask,
                onEditTask: onEditTask,
              ),
      ),
    );
  }
}

// =============================================================================
// SUB-PANEL A: BRIEFING DIARIO COMPACTO
// =============================================================================

class _DailyBriefingSubPanel extends ConsumerWidget {
  const _DailyBriefingSubPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(dailyBriefingProvider);
    final isLocked = briefingAsync.value?.isLocked ?? false;
    final metrics = ref.watch(taskSummaryMetricsProvider);
    final tasksAsync = ref.watch(taskListProvider);
    final allTasks = tasksAsync.value ?? [];

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM').format(now);
    final capitalizedDate = dateStr.isNotEmpty
        ? dateStr[0].toUpperCase() + dateStr.substring(1)
        : dateStr;

    // Tareas para hoy y próximas
    final todayTasks = allTasks.where((t) {
      if (t.status == TaskStatus.done || t.dueDate == null) return false;
      final due = t.dueDate!;
      return due.year == now.year && due.month == now.month && due.day == now.day;
    }).toList();

    final upcomingTasks = allTasks.where((t) {
      if (t.status == TaskStatus.done || t.dueDate == null) return false;
      final due = t.dueDate!;
      final isToday =
          due.year == now.year && due.month == now.month && due.day == now.day;
      return due.isAfter(now) && !isToday;
    }).take(4).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header del Briefing ──
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Briefing Diario',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF94A3B8)),
                tooltip: 'Actualizar briefing',
                splashRadius: 16,
                onPressed: () => ref.refresh(dailyBriefingProvider),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            capitalizedDate,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // ── Tarjeta de Estado / Motivacional ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF162032)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 16, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isLocked
                            ? 'Bóveda protegida'
                            : (metrics.pendingCount == 0
                                ? '¡Todo bajo control!'
                                : '${metrics.pendingCount} pendientes'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isLocked
                      ? 'Desbloquea con tu clave maestra para ver el resumen completo de hoy.'
                      : (metrics.pendingCount == 0
                          ? 'No tienes tareas pendientes por ahora.'
                          : 'Tienes ${metrics.pendingCount} tarea${metrics.pendingCount == 1 ? "" : "s"} por cumplir en tu lista.'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                if (metrics.totalCount > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progreso general',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                      Text(
                        '${metrics.progressPercentage}%',
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: metrics.completionRatio,
                      minHeight: 5,
                      backgroundColor: const Color(0xFF0F172A),
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Lista deslizable de Tareas de Hoy y Próximamente ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HOY
                  Row(
                    children: [
                      const Text(
                        'HOY',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          todayTasks.length.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (todayTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No hay tareas programadas para hoy.',
                        style: TextStyle(
                          color: const Color(0xFF64748B).withValues(alpha: 0.8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...todayTasks.map((task) => _BriefingTaskTile(task: task)),

                  const SizedBox(height: 18),

                  // PRÓXIMAMENTE
                  Row(
                    children: [
                      const Text(
                        'PRÓXIMAMENTE',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          upcomingTasks.length.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (upcomingTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Sin tareas programadas para los próximos días.',
                        style: TextStyle(
                          color: const Color(0xFF64748B).withValues(alpha: 0.8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...upcomingTasks.map((task) => _BriefingTaskTile(task: task)),
                ],
              ),
            ),
          ),

          // ── Botón Asistente Kev ──
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showKevCommandBar(context),
              icon: const Icon(Icons.auto_awesome,
                  size: 14, color: Color(0xFF818CF8)),
              label: const Text(
                'Consultar a Kev (Ctrl + K)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF334155)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefingTaskTile extends ConsumerWidget {
  const _BriefingTaskTile({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            ref.read(selectedTaskIdProvider.notifier).select(task.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    ref.read(taskListProvider.notifier).toggleStatus(task.id);
                  },
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF64748B), width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (task.dueDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d MMM').format(task.dueDate!),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUB-PANEL B: DETALLE DE TAREA SELECCIONADA
// =============================================================================

class _TaskDetailSubPanel extends ConsumerWidget {
  const _TaskDetailSubPanel({
    super.key,
    required this.task,
    required this.onEditTask,
  });

  final TaskItem task;
  final void Function(TaskItem task) onEditTask;

  Color _priorityColor(int priority) {
    return switch (priority) {
      1 => const Color(0xFF64748B), // Baja
      2 => const Color(0xFF3B82F6), // Media
      3 => const Color(0xFFF59E0B), // Alta
      4 => const Color(0xFFEF4444), // Urgente
      _ => const Color(0xFF64748B),
    };
  }

  String _priorityLabel(int priority) {
    return switch (priority) {
      1 => 'Baja',
      2 => 'Media',
      3 => 'Alta',
      4 => 'Urgente',
      _ => 'Media',
    };
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return const Color(0xFF0284C7);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = task.status == TaskStatus.done;
    final priorityColor = _priorityColor(task.priority);
    final priorityLabel = _priorityLabel(task.priority);
    final projectMap = ref.watch(projectMapProvider);
    final project = task.projectId != null ? projectMap[task.projectId] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Botón Volver ──
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      ref.read(selectedTaskIdProvider.notifier).clear();
                    },
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Volver al Briefing'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFF94A3B8)),
                tooltip: 'Editar tarea',
                splashRadius: 16,
                onPressed: () => onEditTask(task),
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Color(0xFFEF4444)),
                tooltip: 'Eliminar tarea',
                splashRadius: 16,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 16),

          // ── Encabezado y Título de la Tarea ──
          Text(
            'DETALLE DE TAREA',
            style: TextStyle(
              color: const Color(0xFF94A3B8).withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: TextStyle(
              color: isDone ? const Color(0xFF94A3B8) : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: isDone ? TextDecoration.lineThrough : null,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // ── Badge de Prioridad ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Prioridad $priorityLabel',
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 16),

          // ── Atributos (Fecha y Proyecto) ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fecha
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fecha límite',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.dueDate != null
                                ? DateFormat('EEEE, d MMMM yyyy')
                                    .format(task.dueDate!)
                                : 'Sin fecha asignada',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Proyecto
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.folder_outlined,
                          size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Proyecto asociado',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (project != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _parseColor(project.colorHex),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  project.name,
                                  style: TextStyle(
                                    color: _parseColor(project.colorHex),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text(
                              'Ninguno',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 16),

                  // Descripción / Notas
                  const Text(
                    'Descripción / Notas',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      task.notes.isNotEmpty
                          ? task.notes
                          : 'Sin notas adicionales.',
                      style: TextStyle(
                        color: task.notes.isNotEmpty
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Botones de Acción Rápida al fondo ──
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(taskListProvider.notifier).toggleStatus(task.id);
              },
              icon: Icon(
                isDone ? Icons.refresh : Icons.check_circle_outline,
                size: 18,
              ),
              label: Text(
                isDone ? 'Marcar como pendiente' : 'Marcar como completada',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone
                    ? const Color(0xFF334155)
                    : const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onEditTask(task),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar tarea completa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                side: const BorderSide(color: Color(0xFF334155)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar tarea', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar "${task.title}"? Esta acción se sincronizará con la nube cifrada.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(taskListProvider.notifier).deleteTask(task.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}
