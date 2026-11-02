import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/calendar_event_item.dart';
import '../calendar_provider.dart';
import '../calendar_theme.dart';

/// Vista diaria detallada con línea de tiempo horaria.
class CalendarDayView extends ConsumerWidget {
  final List<CalendarEventItem> events;
  final void Function(CalendarEventItem event) onEventTap;
  final void Function(DateTime dateTime) onSlotTap;

  const CalendarDayView({
    super.key,
    required this.events,
    required this.onEventTap,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final dayEvents = events.where((e) {
      return e.startTime.year == selectedDate.year &&
          e.startTime.month == selectedDate.month &&
          e.startTime.day == selectedDate.day;
    }).toList();

    const startHour = 6;
    const endHour = 23;
    const hourHeight = 65.0;

    final capitalizedHeader =
        CalendarTheme.formatFullDateWithWeekday(selectedDate);

    return Container(
      color: CalendarTheme.mainBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera del Día Seleccionado ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: CalendarTheme.panelBg,
              border: Border(
                bottom: BorderSide(color: CalendarTheme.border, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  capitalizedHeader,
                  style: const TextStyle(
                    color: CalendarTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CalendarTheme.accentMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayEvents.length} eventos programados',
                    style: const TextStyle(
                      color: CalendarTheme.accentLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista Horaria ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                height: (endHour - startHour + 1) * hourHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna de Horas
                    SizedBox(
                      width: 55,
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Área de contenido del día
                    Expanded(
                      child: Stack(
                        children: [
                          // Filas horarias clickeables
                          Column(
                            children: List.generate(endHour - startHour + 1, (index) {
                              final hour = startHour + index;
                              return InkWell(
                                onTap: () {
                                  final slotTime = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    hour,
                                  );
                                  onSlotTap(slotTime);
                                },
                                child: Container(
                                  height: hourHeight,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: CalendarTheme.borderSubtle,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          // Eventos posicionados
                          ...dayEvents.map((event) {
                            final start = event.startTime.hour + (event.startTime.minute / 60.0);
                            final end = event.endTime.hour + (event.endTime.minute / 60.0);
                            final durationHours = (end - start).clamp(0.5, 6.0);

                            final topOffset = ((start - startHour) * hourHeight).clamp(0.0, double.infinity);
                            final blockHeight = durationHours * hourHeight;
                            final catColor = CalendarTheme.colorForCategory(event.category);

                            return Positioned(
                              top: topOffset,
                              left: 8,
                              right: 8,
                              height: blockHeight.clamp(45.0, 400.0),
                              child: InkWell(
                                onTap: () => onEventTap(event),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: catColor.withValues(alpha: 0.6),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: catColor,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              event.title,
                                              style: const TextStyle(
                                                color: CalendarTheme.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${CalendarTheme.formatTimeRange(event.startTime, event.endTime)}  •  ${event.category}',
                                              style: TextStyle(
                                                color: catColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (event.location.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_outlined,
                                                    size: 11,
                                                    color: CalendarTheme.textSecondary,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Expanded(
                                                    child: Text(
                                                      event.location,
                                                      style: const TextStyle(
                                                        color: CalendarTheme.textSecondary,
                                                        fontSize: 10,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
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
