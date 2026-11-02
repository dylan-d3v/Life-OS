import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/calendar_event_item.dart';
import '../calendar_provider.dart';
import '../calendar_theme.dart';

/// Vista mensual tradicional (Cuadrícula de 7 columnas).
class CalendarMonthView extends ConsumerWidget {
  final List<CalendarEventItem> events;
  final void Function(CalendarEventItem event) onEventTap;
  final void Function(DateTime date) onDateDoubleTap;

  const CalendarMonthView({
    super.key,
    required this.events,
    required this.onEventTap,
    required this.onDateDoubleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMonth = ref.watch(calendarActiveMonthProvider);
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateUtils.getDaysInMonth(activeMonth.year, activeMonth.month);
    final firstDayWeekday = DateTime(activeMonth.year, activeMonth.month, 1).weekday; // 1=Lun, 7=Dom

    // Días del mes anterior para rellenar
    final prevMonth = DateTime(activeMonth.year, activeMonth.month - 1, 1);
    final daysInPrevMonth = DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);

    return Container(
      color: CalendarTheme.mainBg,
      child: Column(
        children: [
          // ── Fila de nombres de días de la semana ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: CalendarTheme.panelBg,
              border: Border(
                bottom: BorderSide(color: CalendarTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: const [
                _HeaderWeekdayCell('Lunes'),
                _HeaderWeekdayCell('Martes'),
                _HeaderWeekdayCell('Miércoles'),
                _HeaderWeekdayCell('Jueves'),
                _HeaderWeekdayCell('Viernes'),
                _HeaderWeekdayCell('Sábado'),
                _HeaderWeekdayCell('Domingo'),
              ],
            ),
          ),

          // ── Cuadrícula de Días (6 filas x 7 columnas) ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const totalCells = 42;
                final cellWidth = constraints.maxWidth / 7;
                final cellHeight = constraints.maxHeight / 6;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalCells,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: cellWidth / cellHeight,
                  ),
                  itemBuilder: (context, index) {
                    final isLeadingDay = index < (firstDayWeekday - 1);
                    final dayOffset = index - (firstDayWeekday - 1);
                    final isTrailingDay = dayOffset >= daysInMonth;

                    final DateTime cellDate;
                    final bool isCurrentMonth;

                    if (isLeadingDay) {
                      final prevDayNum = daysInPrevMonth - ((firstDayWeekday - 2) - index);
                      cellDate = DateTime(prevMonth.year, prevMonth.month, prevDayNum);
                      isCurrentMonth = false;
                    } else if (isTrailingDay) {
                      final nextDayNum = dayOffset - daysInMonth + 1;
                      cellDate = DateTime(activeMonth.year, activeMonth.month + 1, nextDayNum);
                      isCurrentMonth = false;
                    } else {
                      cellDate = DateTime(activeMonth.year, activeMonth.month, dayOffset + 1);
                      isCurrentMonth = true;
                    }

                    final isToday = cellDate.year == today.year &&
                        cellDate.month == today.month &&
                        cellDate.day == today.day;

                    final isSelected = cellDate.year == selectedDate.year &&
                        cellDate.month == selectedDate.month &&
                        cellDate.day == selectedDate.day;

                    // Eventos en este día
                    final dayEvents = events.where((e) {
                      return e.startTime.year == cellDate.year &&
                          e.startTime.month == cellDate.month &&
                          e.startTime.day == cellDate.day;
                    }).toList();

                    return _MonthDayCell(
                      date: cellDate,
                      isCurrentMonth: isCurrentMonth,
                      isToday: isToday,
                      isSelected: isSelected,
                      events: dayEvents,
                      onTap: () {
                        ref.read(calendarSelectedDateProvider.notifier).selectDate(cellDate);
                        if (!isCurrentMonth) {
                          ref.read(calendarActiveMonthProvider.notifier).setMonth(cellDate);
                        }
                      },
                      onDoubleTap: () => onDateDoubleTap(cellDate),
                      onEventTap: onEventTap,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderWeekdayCell extends StatelessWidget {
  final String title;
  const _HeaderWeekdayCell(this.title);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: CalendarTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final List<CalendarEventItem> events;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(CalendarEventItem event) onEventTap;

  const _MonthDayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isSelected
              ? CalendarTheme.elevatedSurface.withValues(alpha: 0.6)
              : (isCurrentMonth ? CalendarTheme.mainBg : const Color(0xFF0D0F13)),
          border: Border.all(
            color: isSelected
                ? CalendarTheme.accent
                : CalendarTheme.borderSubtle,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Número de Día y Distintivo de Hoy ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday
                        ? CalendarTheme.accent
                        : (isSelected
                            ? CalendarTheme.accentMuted
                            : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF111318)
                          : (isCurrentMonth
                              ? CalendarTheme.textPrimary
                              : CalendarTheme.textDisabled),
                      fontSize: 11,
                      fontWeight: isToday || isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (events.length > 2)
                  Text(
                    '+${events.length - 2}',
                    style: const TextStyle(
                      color: CalendarTheme.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),

            // ── Tarjetas de Eventos (Máximo 2 visibles por celda de mes) ──
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length > 2 ? 2 : events.length,
                itemBuilder: (context, idx) {
                  final event = events[idx];
                  final catColor = CalendarTheme.colorForCategory(event.category);
                  final timeStr = event.isAllDay
                      ? 'Día'
                      : CalendarTheme.formatTime(event.startTime);

                  return InkWell(
                    onTap: () => onEventTap(event),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                        border: Border(
                          left: BorderSide(color: catColor, width: 2.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: catColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CalendarTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
