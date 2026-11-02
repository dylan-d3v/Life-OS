import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/calendar_event_item.dart';
import '../calendar_provider.dart';
import '../calendar_theme.dart';

/// Mini calendario compacto para la barra lateral izquierda.
///
/// Permite navegar entre meses, seleccionar una fecha activa y
/// muestra indicadores visuales (puntos de colores) en los días con eventos.
class CalendarMiniMonth extends ConsumerWidget {
  final List<CalendarEventItem> events;

  const CalendarMiniMonth({
    super.key,
    required this.events,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMonth = ref.watch(calendarActiveMonthProvider);
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Formatear mes y año en español
    final capitalizedMonth = CalendarTheme.formatMonthYear(activeMonth);

    // Días del mes actual
    final daysInMonth =
        DateUtils.getDaysInMonth(activeMonth.year, activeMonth.month);
    final firstDayWeekday =
        DateTime(activeMonth.year, activeMonth.month, 1).weekday; // 1 = Lun, 7 = Dom

    return Container(
      decoration: BoxDecoration(
        color: CalendarTheme.sidebarBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera del Mini Calendario: Mes y Controles < > ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  capitalizedMonth,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CalendarTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => ref
                        .read(calendarActiveMonthProvider.notifier)
                        .previousMonth(),
                  ),
                  const SizedBox(width: 2),
                  _NavIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => ref
                        .read(calendarActiveMonthProvider.notifier)
                        .nextMonth(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Días de la semana (L, M, M, J, V, S, D) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _WeekdayLabel('L'),
              _WeekdayLabel('M'),
              _WeekdayLabel('M'),
              _WeekdayLabel('J'),
              _WeekdayLabel('V'),
              _WeekdayLabel('S'),
              _WeekdayLabel('D'),
            ],
          ),
          const SizedBox(height: 6),

          // ── Cuadrícula de Días ──
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 semanas fijas para alineación consistente
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - (firstDayWeekday - 1);
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox.shrink();
              }

              final dayNumber = dayOffset + 1;
              final cellDate = DateTime(
                  activeMonth.year, activeMonth.month, dayNumber);
              final isToday = cellDate.year == today.year &&
                  cellDate.month == today.month &&
                  cellDate.day == today.day;
              final isSelected = cellDate.year == selectedDate.year &&
                  cellDate.month == selectedDate.month &&
                  cellDate.day == selectedDate.day;

              // Comprobar eventos en este día
              final dayEvents = events.where((e) {
                return e.startTime.year == cellDate.year &&
                    e.startTime.month == cellDate.month &&
                    e.startTime.day == cellDate.day;
              }).toList();
              final hasEvents = dayEvents.isNotEmpty;

              return InkWell(
                onTap: () {
                  ref
                      .read(calendarSelectedDateProvider.notifier)
                      .selectDate(cellDate);
                  ref
                      .read(calendarActiveMonthProvider.notifier)
                      .setMonth(cellDate);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CalendarTheme.accent
                        : (isToday ? CalendarTheme.accentMuted : Colors.transparent),
                    borderRadius: BorderRadius.circular(6),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: CalendarTheme.accent.withValues(alpha: 0.6),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF111318)
                              : (isToday
                                  ? CalendarTheme.accentLight
                                  : CalendarTheme.textPrimary),
                          fontSize: 11,
                          fontWeight:
                              isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (hasEvents) ...[
                        const SizedBox(height: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 3.5,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF111318)
                                    : CalendarTheme.colorForCategory(
                                        dayEvents.first.category),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: CalendarTheme.textDisabled,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          icon,
          size: 16,
          color: CalendarTheme.textSecondary,
        ),
      ),
    );
  }
}
