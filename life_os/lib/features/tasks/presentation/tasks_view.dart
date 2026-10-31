import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/task_item.dart';
import 'tasks_provider.dart';

/// Vista principal del Gestor de Tareas con cifrado E2EE.
/// Muestra la lista de tareas descifradas, filtros rápidos y
/// permite crear, completar y eliminar tareas.
class TasksView extends ConsumerWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTasks = ref.watch(filteredTasksProvider);
    final activeFilter = ref.watch(taskFilterProvider);

    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestor de Tareas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tareas cifradas de extremo a extremo con AES-256-GCM',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreateTaskDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Tarea'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Filtros rápidos ──
          Row(
            children: [
              _FilterChip(
                label: 'Todas',
                selected: activeFilter == TaskFilter.all,
                onTap: () => ref
                    .read(taskFilterProvider.notifier)
                    .setFilter(TaskFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pendientes',
                selected: activeFilter == TaskFilter.pending,
                onTap: () => ref
                    .read(taskFilterProvider.notifier)
                    .setFilter(TaskFilter.pending),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Completadas',
                selected: activeFilter == TaskFilter.done,
                onTap: () => ref
                    .read(taskFilterProvider.notifier)
                    .setFilter(TaskFilter.done),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                tooltip: 'Recargar tareas',
                onPressed: () => ref.read(taskListProvider.notifier).refresh(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Lista de tareas ──
          Expanded(
            child: filteredTasks.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF38BDF8),
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 12),
                    Text(
                      'Error al cargar tareas',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(taskListProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return _buildEmptyState(activeFilter);
                }
                return ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskCard(task: task);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TaskFilter filter) {
    final message = switch (filter) {
      TaskFilter.all => 'No tienes tareas aún.\nCrea tu primera tarea cifrada.',
      TaskFilter.pending => 'No hay tareas pendientes.\n¡Buen trabajo!',
      TaskFilter.done => 'No hay tareas completadas aún.',
    };

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.checklist_rounded,
              size: 56,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTaskDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateTaskDialog(ref: ref),
    );
  }
}

// =============================================================================
// Widget: Chip de filtro
// =============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? const Color(0xFF0284C7) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widget: Tarjeta de tarea
// =============================================================================

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = task.status == TaskStatus.done;
    final priorityColor = _priorityColor(task.priority);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone
              ? const Color(0xFF334155)
              : const Color(0xFF334155).withValues(alpha: 0.8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {}, // Futura: abrir detalle de tarea
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () =>
                      ref.read(taskListProvider.notifier).toggleStatus(task.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF22C55E)
                          : Colors.transparent,
                      border: Border.all(
                        color: isDone
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF64748B),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isDone
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),

                // Indicador de prioridad
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),

                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: isDone
                              ? const Color(0xFF64748B)
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (task.notes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.notes,
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),

                // Fecha de vencimiento
                if (task.dueDate != null) ...[
                  const SizedBox(width: 12),
                  _DueDateBadge(dueDate: task.dueDate!),
                ],

                // Prioridad badge
                const SizedBox(width: 8),
                _PriorityBadge(priority: task.priority),

                // Botón eliminar
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Eliminar tarea',
                  onPressed: () => _confirmDelete(context, ref),
                  splashRadius: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _priorityColor(int priority) {
    return switch (priority) {
      1 => const Color(0xFF64748B), // Baja
      2 => const Color(0xFF3B82F6), // Media
      3 => const Color(0xFFF59E0B), // Alta
      4 => const Color(0xFFEF4444), // Urgente
      _ => const Color(0xFF64748B),
    };
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar tarea',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar "${task.title}"? Esta acción es reversible internamente.',
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
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget: Badge de fecha de vencimiento
// =============================================================================

class _DueDateBadge extends StatelessWidget {
  const _DueDateBadge({required this.dueDate});

  final DateTime dueDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now);
    final isToday = dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;

    final Color bgColor;
    final Color textColor;
    if (isOverdue && !isToday) {
      bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
      textColor = const Color(0xFFEF4444);
    } else if (isToday) {
      bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      textColor = const Color(0xFFF59E0B);
    } else {
      bgColor = const Color(0xFF334155);
      textColor = const Color(0xFF94A3B8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            DateFormat('dd MMM', 'es').format(dueDate),
            style: TextStyle(color: textColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget: Badge de prioridad
// =============================================================================

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final label = switch (priority) {
      1 => 'Baja',
      2 => 'Media',
      3 => 'Alta',
      4 => 'Urgente',
      _ => '?',
    };

    final color = switch (priority) {
      1 => const Color(0xFF64748B),
      2 => const Color(0xFF3B82F6),
      3 => const Color(0xFFF59E0B),
      4 => const Color(0xFFEF4444),
      _ => const Color(0xFF64748B),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// =============================================================================
// Dialog: Crear nueva tarea
// =============================================================================

class _CreateTaskDialog extends ConsumerStatefulWidget {
  const _CreateTaskDialog({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<_CreateTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int _priority = 2;
  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 20),
          SizedBox(width: 8),
          Text('Nueva Tarea Cifrada',
              style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              _buildTextField(
                controller: _titleCtrl,
                label: 'Título',
                hint: 'Ej: Estudiar para el examen de cálculo',
                autofocus: true,
              ),
              const SizedBox(height: 14),

              // Notas
              _buildTextField(
                controller: _notesCtrl,
                label: 'Notas (opcional)',
                hint: 'Detalles adicionales...',
                maxLines: 3,
              ),
              const SizedBox(height: 14),

              // Prioridad
              const Text('Prioridad',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildPriorityOption(1, 'Baja', const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  _buildPriorityOption(2, 'Media', const Color(0xFF3B82F6)),
                  const SizedBox(width: 6),
                  _buildPriorityOption(3, 'Alta', const Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  _buildPriorityOption(4, 'Urgente', const Color(0xFFEF4444)),
                ],
              ),
              const SizedBox(height: 14),

              // Fecha de vencimiento
              Row(
                children: [
                  const Text('Fecha límite:',
                      style:
                          TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      _dueDate != null
                          ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                          : 'Seleccionar',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() => _dueDate = null),
                      splashRadius: 14,
                      tooltip: 'Quitar fecha',
                    ),
                ],
              ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 14, color: Color(0xFF22C55E)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'El título y las notas se cifran localmente con AES-256-GCM antes de enviarse al servidor.',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Crear Tarea'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintStyle: const TextStyle(color: Color(0xFF475569)),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0284C7)),
        ),
      ),
    );
  }

  Widget _buildPriorityOption(int value, String label, Color color) {
    final selected = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.2) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : const Color(0xFF334155),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? color : const Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0284C7),
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(taskListProvider.notifier).addTask(
            title: title,
            notes: _notesCtrl.text.trim(),
            priority: _priority,
            dueDate: _dueDate,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear tarea: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
