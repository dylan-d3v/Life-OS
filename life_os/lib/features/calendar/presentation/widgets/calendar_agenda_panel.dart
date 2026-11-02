import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/calendar_event_item.dart';
import '../calendar_provider.dart';
import '../calendar_theme.dart';

/// Panel lateral derecho que presenta la Agenda Diaria y Línea de Tiempo.
class CalendarAgendaPanel extends ConsumerWidget {
  final List<CalendarEventItem> allEvents;
  final void Function(CalendarEventItem event) onEditEvent;
  final void Function(CalendarEventItem event) onDeleteEvent;
  final VoidCallback onAddEventForDay;

  const CalendarAgendaPanel({
    super.key,
    required this.allEvents,
    required this.onEditEvent,
    required this.onDeleteEvent,
    required this.onAddEventForDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);

    // Eventos del día seleccionado
    final dayEvents = allEvents.where((e) {
      return e.startTime.year == selectedDate.year &&
          e.startTime.month == selectedDate.month &&
          e.startTime.day == selectedDate.day;
    }).toList();

    dayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    final capitalizedWeekday = CalendarTheme.formatWeekday(selectedDate);
    final formattedDate =
        '${CalendarTheme.formatDayMonth(selectedDate)}, ${selectedDate.year}';

    // Próximos eventos en días siguientes
    final upcomingEvents = allEvents.where((e) {
      return e.startTime.isAfter(selectedDate.add(const Duration(days: 1)));
    }).take(3).toList();

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: CalendarTheme.sidebarBg,
        border: Border(
          left: BorderSide(color: CalendarTheme.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera de la Agenda Diaria ──
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: const BoxDecoration(
              color: CalendarTheme.panelBg,
              border: Border(
                bottom: BorderSide(color: CalendarTheme.borderSubtle, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      capitalizedWeekday,
                      style: const TextStyle(
                        color: CalendarTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: CalendarTheme.accentMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${dayEvents.length} eventos',
                        style: const TextStyle(
                          color: CalendarTheme.accentLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: CalendarTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Línea de Tiempo del Día Seleccionado ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AGENDA DEL DÍA',
                    style: TextStyle(
                      color: CalendarTheme.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (dayEvents.isEmpty)
                    _EmptyDayPlaceholder(onAdd: onAddEventForDay)
                  else
                    ...List.generate(dayEvents.length, (index) {
                      final event = dayEvents[index];
                      final isLast = index == dayEvents.length - 1;
                      return _TimelineEventCard(
                        event: event,
                        isLast: isLast,
                        onEdit: () => onEditEvent(event),
                        onDelete: () => onDeleteEvent(event),
                      );
                    }),

                  if (upcomingEvents.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: CalendarTheme.borderSubtle),
                    const SizedBox(height: 16),
                    const Text(
                      'PRÓXIMAMENTE',
                      style: TextStyle(
                        color: CalendarTheme.textDisabled,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...upcomingEvents.map((event) {
                      final catColor = CalendarTheme.colorForCategory(event.category);
                      final fDay =
                          CalendarTheme.formatDayMonthShort(event.startTime);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CalendarTheme.elevatedSurface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CalendarTheme.borderSubtle, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                fDay,
                                style: TextStyle(
                                  color: catColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: CalendarTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    CalendarTheme.formatTime(event.startTime),
                                    style: const TextStyle(
                                      color: CalendarTheme.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDayPlaceholder extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyDayPlaceholder({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: CalendarTheme.elevatedSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CalendarTheme.borderSubtle, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 32,
            color: CalendarTheme.textDisabled.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sin eventos programados',
            style: TextStyle(
              color: CalendarTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tu agenda está completamente libre para este día.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CalendarTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Agregar evento aquí'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CalendarTheme.accentLight,
              side: const BorderSide(color: CalendarTheme.borderAccent, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 30),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  final CalendarEventItem event;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TimelineEventCard({
    required this.event,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = CalendarTheme.colorForCategory(event.category);
    final catIcon = CalendarTheme.iconForCategory(event.category);
    final timeStr = event.isAllDay
        ? 'Todo el día'
        : CalendarTheme.formatTimeRange(event.startTime, event.endTime);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Nodo y Línea de Tiempo Vertical ──
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: catColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: catColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: CalendarTheme.borderSubtle,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Tarjeta de Contenido del Evento ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CalendarTheme.elevatedSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CalendarTheme.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría e Icono
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catIcon, size: 11, color: catColor),
                            const SizedBox(width: 4),
                            Text(
                              event.category,
                              style: TextStyle(
                                color: catColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: CalendarTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 14,
                                color: Color(0xFFF87171),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Título
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: CalendarTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Hora
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: CalendarTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: CalendarTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Ubicación si está presente
                  if (event.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: CalendarTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                              color: CalendarTheme.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Descripción si está presente
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.description,
                      style: const TextStyle(
                        color: Color(0xFFB0B7C3),
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
