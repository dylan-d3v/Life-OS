import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tasks_provider.dart';

/// Tarjetas compactas de resumen métrico que actúan también como filtros rápidos.
///
/// Muestra:
/// - [✓ X Pendientes]
/// - [✓ Y Completadas]
/// - [📅 Z Vencen hoy]
/// - [! W Atrasadas]
class TaskSummaryCards extends ConsumerWidget {
  const TaskSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(taskSummaryMetricsProvider);
    final activeFilter = ref.watch(taskFilterProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // En pantallas muy estrechas permitimos scroll horizontal o grid
        final isNarrow = constraints.maxWidth < 450;

        final items = [
          _SummaryCardData(
            filter: TaskFilter.pending,
            count: metrics.pendingCount,
            label: 'Pendientes',
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFF38BDF8), // Sky
          ),
          _SummaryCardData(
            filter: TaskFilter.done,
            count: metrics.completedCount,
            label: 'Completadas',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF22C55E), // Emerald Green
          ),
          _SummaryCardData(
            filter: TaskFilter.today,
            count: metrics.todayCount,
            label: 'Vencen hoy',
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFFF59E0B), // Amber
          ),
          _SummaryCardData(
            filter: TaskFilter.overdue,
            count: metrics.overdueCount,
            label: 'Atrasadas',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFEF4444), // Rose Red
          ),
        ];

        if (isNarrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items.map((item) {
                final isSelected = activeFilter == item.filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 140,
                    child: _TaskSummaryCard(
                      data: item,
                      isSelected: isSelected,
                      onTap: () => _toggleFilter(ref, item.filter, activeFilter),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }

        return Row(
          children: items.map((item) {
            final isSelected = activeFilter == item.filter;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _TaskSummaryCard(
                  data: item,
                  isSelected: isSelected,
                  onTap: () => _toggleFilter(ref, item.filter, activeFilter),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _toggleFilter(
      WidgetRef ref, TaskFilter targetFilter, TaskFilter currentFilter) {
    if (currentFilter == targetFilter) {
      ref.read(taskFilterProvider.notifier).setFilter(TaskFilter.all);
    } else {
      ref.read(taskFilterProvider.notifier).setFilter(targetFilter);
    }
  }
}

class _SummaryCardData {
  final TaskFilter filter;
  final int count;
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryCardData({
    required this.filter,
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _TaskSummaryCard extends StatefulWidget {
  const _TaskSummaryCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _SummaryCardData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_TaskSummaryCard> createState() => _TaskSummaryCardState();
}

class _TaskSummaryCardState extends State<_TaskSummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.data.color;
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : (_isHovered
                    ? const Color(0xFF24324A)
                    : const Color(0xFF1E293B)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color
                  : (_isHovered
                      ? const Color(0xFF475569)
                      : const Color(0xFF334155)),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.data.icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.data.count.toString(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.data.label,
                      style: TextStyle(
                        color: isSelected ? color : const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
