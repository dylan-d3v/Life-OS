import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/calendar_event_item.dart';
import 'calendar_provider.dart';
import 'calendar_theme.dart';
import 'widgets/calendar_agenda_panel.dart';
import 'widgets/calendar_day_view.dart';
import 'widgets/calendar_event_dialog.dart';
import 'widgets/calendar_month_view.dart';
import 'widgets/calendar_sidebar.dart';
import 'widgets/calendar_toolbar.dart';
import 'widgets/calendar_week_view.dart';

/// Vista principal del Workspace de Calendario en Dark Mode (Life-OS).
///
/// Implementa una arquitectura moderna de 3 columnas de escritorio:
/// 1. Columna Izquierda (Sidebar): Mini calendario, filtros por categoría y estado temporal.
/// 2. Columna Central (Workspace): Toolbar de navegación y cuadrícula interactiva (Mes, Semana, Día).
/// 3. Columna Derecha (Agenda Panel): Información del día seleccionado, línea de tiempo y próximos eventos.
class CalendarView extends ConsumerWidget {
  const CalendarView({super.key});

  void _openEventDialog(
    BuildContext context, {
    CalendarEventItem? eventToEdit,
    DateTime? initialDate,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => CalendarEventDialog(
        eventToEdit: eventToEdit,
        initialDate: initialDate,
      ),
    );
  }

  void _confirmDeleteEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEventItem event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CalendarTheme.panelBg,
        title: const Text(
          '¿Eliminar evento?',
          style: TextStyle(color: CalendarTheme.textPrimary),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${event.title}"?',
          style: const TextStyle(color: CalendarTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: CalendarTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(calendarEventListProvider.notifier).deleteEvent(event.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEventsAsync = ref.watch(calendarEventListProvider);
    final workspaceEventsAsync = ref.watch(calendarWorkspaceEventsProvider);
    final viewMode = ref.watch(calendarViewModeProvider);

    return Container(
      color: CalendarTheme.mainBg,
      child: allEventsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: CalendarTheme.accent,
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 12),
                Text(
                  'Error al cargar el calendario: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CalendarTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(calendarEventListProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CalendarTheme.accent,
                    foregroundColor: const Color(0xFF111318),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (allEvents) {
          final workspaceEvents = workspaceEventsAsync.value ?? allEvents;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Barra Lateral Izquierda (Sidebar) ──
              CalendarSidebar(allEvents: allEvents),

              // ── 2. Espacio Central de Trabajo (Workspace) ──
              Expanded(
                child: Column(
                  children: [
                    // Toolbar Superior
                    CalendarToolbar(
                      onNewEventPressed: () => _openEventDialog(context),
                    ),

                    // Mensaje de estado vacío si no hay eventos registrados
                    if (workspaceEvents.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: CalendarTheme.elevatedSurface.withValues(alpha: 0.5),
                          border: const Border(
                            bottom: BorderSide(
                                color: CalendarTheme.borderSubtle, width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: CalendarTheme.accentLight,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'No tienes eventos registrados para los filtros actuales.',
                              style: TextStyle(
                                color: CalendarTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Vistas Centrales (Mes, Semana, Día)
                    Expanded(
                      child: _buildCenterCalendar(
                        context,
                        ref,
                        viewMode: viewMode,
                        events: workspaceEvents,
                      ),
                    ),
                  ],
                ),
              ),

              // ── 3. Panel Lateral Derecho (Agenda y Timeline) ──
              CalendarAgendaPanel(
                allEvents: workspaceEvents,
                onEditEvent: (event) =>
                    _openEventDialog(context, eventToEdit: event),
                onDeleteEvent: (event) =>
                    _confirmDeleteEvent(context, ref, event),
                onAddEventForDay: () {
                  final selectedDate = ref.read(calendarSelectedDateProvider);
                  _openEventDialog(context, initialDate: selectedDate);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCenterCalendar(
    BuildContext context,
    WidgetRef ref, {
    required CalendarViewMode viewMode,
    required List<CalendarEventItem> events,
  }) {
    switch (viewMode) {
      case CalendarViewMode.month:
        return CalendarMonthView(
          events: events,
          onEventTap: (event) => _openEventDialog(context, eventToEdit: event),
          onDateDoubleTap: (date) =>
              _openEventDialog(context, initialDate: date),
        );
      case CalendarViewMode.week:
        return CalendarWeekView(
          events: events,
          onEventTap: (event) => _openEventDialog(context, eventToEdit: event),
          onSlotTap: (slotDateTime) =>
              _openEventDialog(context, initialDate: slotDateTime),
        );
      case CalendarViewMode.day:
        return CalendarDayView(
          events: events,
          onEventTap: (event) => _openEventDialog(context, eventToEdit: event),
          onSlotTap: (slotDateTime) =>
              _openEventDialog(context, initialDate: slotDateTime),
        );
    }
  }
}
