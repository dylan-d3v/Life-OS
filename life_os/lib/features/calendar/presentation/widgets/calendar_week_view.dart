import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/calendar_event_item.dart';
import '../calendar_provider.dart';
import '../calendar_theme.dart';

/// Vista semanal de 7 columnas con cuadrícula vertical basada en horas.
class CalendarWeekView extends ConsumerWidget {
  final List<CalendarEventItem> events;
  final void Function(CalendarEventItem event) onEventTap;
  final void Function(DateTime dateTime) onSlotTap;

  const CalendarWeekView({
    super.key,
    required this.events,
    required this.onEventTap,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calcular lunes de la semana actual
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    // Rango de horas a renderizar (desde las 06:00 hasta las 23:00)
    const startHour = 6;
    const endHour = 23;
    const hourHeight = 54.0;

    return Container(
      color: CalendarTheme.mainBg,
      child: Column(
        children: [
          // ── Encabezado de los 7 días de la semana ──
          Container(
            padding: const EdgeInsets.only(left: 50), // Margen para columna de horas
            decoration: const BoxDecoration(
              color: CalendarTheme.panelBg,
              border: Border(
                bottom: BorderSide(color: CalendarTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: weekDays.map((day) {
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final isSelected = day.year == selectedDate.year &&
                    day.month == selectedDate.month &&
                    day.day == selectedDate.day;

                final weekdayStr =
                    CalendarTheme.formatWeekdayShort(day, uppercase: true);

                return Expanded(
                  child: InkWell(
                    onTap: () => ref
                        .read(calendarSelectedDateProvider.notifier)
                        .selectDate(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? CalendarTheme.accent : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            weekdayStr,
                            style: TextStyle(
                              color: isSelected
                                  ? CalendarTheme.accent
                                  : CalendarTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? CalendarTheme.accent
                                  : (isSelected
                                      ? CalendarTheme.accentMuted
                                      : Colors.transparent),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isToday
                                    ? const Color(0xFF111318)
                                    : (isSelected
                                        ? CalendarTheme.accentLight
                                        : CalendarTheme.textPrimary),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Cuadrícula Horaria con Scroll Vertical ──
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: (endHour - startHour + 1) * hourHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna de Horas (06:00, 07:00, ...)
                    SizedBox(
                      width: 50,
                      child: Column(
                        children: List.generate(endHour - startHour + 1, (index) {
                          final hour = startHour + index;
                          return SizedBox(
                            height: hourHeight,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                style: const TextStyle(
                                  color: CalendarTheme.textDisabled,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Columnas de los 7 días
                    Expanded(
                      child: Row(
                        children: weekDays.map((day) {
                          // Filtrar eventos correspondientes a este día
                          final dayEvents = events.where((e) {
                            return e.startTime.year == day.year &&
                                e.startTime.month == day.month &&
                                e.startTime.day == day.day;
                          }).toList();

                          return Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: CalendarTheme.borderSubtle,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Líneas horizontales de división horaria
                                  Column(
                                    children: List.generate(
                                        endHour - startHour + 1, (index) {
                                      final hour = startHour + index;
                                      return InkWell(
                                        onTap: () {
                                          final slotTime = DateTime(
                                              day.year, day.month, day.day, hour);
                                          onSlotTap(slotTime);
                                        },
                                        child: Container(
                                          height: hourHeight,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: CalendarTheme.borderSubtle,
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),

                                  // Tarjetas de Eventos posicionadas en el tiempo
                                  ...dayEvents.map((event) {
                                    final start = event.startTime.hour +
                                        (event.startTime.minute / 60.0);
                                    final end = event.endTime.hour +
                                        (event.endTime.minute / 60.0);
                                    final durationHours = (end - start).clamp(0.5, 6.0);

                                    final topOffset =
                                        ((start - startHour) * hourHeight)
                                            .clamp(0.0, double.infinity);
                                    final blockHeight =
                                        durationHours * hourHeight;

                                    final catColor = CalendarTheme.colorForCategory(
                                        event.category);

                                    return Positioned(
                                      top: topOffset,
                                      left: 2,
                                      right: 2,
                                      height: blockHeight.clamp(26.0, 300.0),
                                      child: InkWell(
                                        onTap: () => onEventTap(event),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.22),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: catColor.withValues(alpha: 0.7),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                event.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: CalendarTheme.textPrimary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                CalendarTheme.formatTimeRange(
                                                    event.startTime,
                                                    event.endTime),
                                                style: TextStyle(
                                                  color: catColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
