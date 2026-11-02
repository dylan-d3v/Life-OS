import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar_provider.dart';
import '../calendar_theme.dart';

/// Barra de herramientas superior del Workspace de Calendario.
///
/// Incluye:
/// - Selector de período / Rango de fechas con controles de navegación (<, >, Hoy).
/// - Campo de búsqueda de eventos.
/// - Selector de vista (Mes, Semana, Día).
/// - Botón principal "+ Nuevo Evento".
class CalendarToolbar extends ConsumerWidget {
  final VoidCallback onNewEventPressed;

  const CalendarToolbar({
    super.key,
    required this.onNewEventPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(calendarViewModeProvider);
    final activeMonth = ref.watch(calendarActiveMonthProvider);
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final searchQuery = ref.watch(calendarSearchQueryProvider);

    // Título según la vista activa
    final String periodTitle;
    switch (viewMode) {
      case CalendarViewMode.month:
        periodTitle = CalendarTheme.formatMonthYear(activeMonth);
        break;
      case CalendarViewMode.week:
        // Calcular inicio y fin de semana
        final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final fStart = CalendarTheme.formatDayMonthShort(startOfWeek);
        final fEnd = CalendarTheme.formatDayMonthYearShort(endOfWeek);
        periodTitle = '$fStart – $fEnd';
        break;
      case CalendarViewMode.day:
        periodTitle = CalendarTheme.formatFullDateWithWeekday(selectedDate);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: CalendarTheme.panelBg,
        border: Border(
          bottom: BorderSide(color: CalendarTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // ── Controles de Período y Título (Flexible / Expanded) ──
          Expanded(
            child: Row(
              children: [
                _ToolbarNavButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Período anterior',
                  onTap: () {
                    if (viewMode == CalendarViewMode.month) {
                      ref.read(calendarActiveMonthProvider.notifier).previousMonth();
                    } else if (viewMode == CalendarViewMode.week) {
                      final newDate = selectedDate.subtract(const Duration(days: 7));
                      ref.read(calendarSelectedDateProvider.notifier).selectDate(newDate);
                      ref.read(calendarActiveMonthProvider.notifier).setMonth(newDate);
                    } else {
                      final newDate = selectedDate.subtract(const Duration(days: 1));
                      ref.read(calendarSelectedDateProvider.notifier).selectDate(newDate);
                      ref.read(calendarActiveMonthProvider.notifier).setMonth(newDate);
                    }
                  },
                ),
                const SizedBox(width: 4),
                _ToolbarNavButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Período siguiente',
                  onTap: () {
                    if (viewMode == CalendarViewMode.month) {
                      ref.read(calendarActiveMonthProvider.notifier).nextMonth();
                    } else if (viewMode == CalendarViewMode.week) {
                      final newDate = selectedDate.add(const Duration(days: 7));
                      ref.read(calendarSelectedDateProvider.notifier).selectDate(newDate);
                      ref.read(calendarActiveMonthProvider.notifier).setMonth(newDate);
                    } else {
                      final newDate = selectedDate.add(const Duration(days: 1));
                      ref.read(calendarSelectedDateProvider.notifier).selectDate(newDate);
                      ref.read(calendarActiveMonthProvider.notifier).setMonth(newDate);
                    }
                  },
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () {
                    final now = DateTime.now();
                    ref.read(calendarSelectedDateProvider.notifier).selectDate(now);
                    ref.read(calendarActiveMonthProvider.notifier).goToToday();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CalendarTheme.textPrimary,
                    backgroundColor: CalendarTheme.elevatedSurface,
                    side: const BorderSide(color: CalendarTheme.border, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Hoy',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    periodTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CalendarTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Controles de la Derecha: Búsqueda, Vistas y Nuevo Evento ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo de Búsqueda
              SizedBox(
                width: 110,
                height: 30,
                child: TextField(
                  onChanged: (val) => ref
                      .read(calendarSearchQueryProvider.notifier)
                      .setSearch(val),
                  style: const TextStyle(
                    color: CalendarTheme.textPrimary,
                    fontSize: 11,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    hintStyle: const TextStyle(
                      color: CalendarTheme.textDisabled,
                      fontSize: 11,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: CalendarTheme.textSecondary,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? InkWell(
                            onTap: () => ref
                                .read(calendarSearchQueryProvider.notifier)
                                .setSearch(''),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: CalendarTheme.textSecondary,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: CalendarTheme.mainBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: CalendarTheme.border, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: CalendarTheme.accent, width: 1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Selector de Vista (Mes, Semana, Día)
              Container(
                height: 30,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: CalendarTheme.mainBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: CalendarTheme.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ViewTabButton(
                      label: 'Mes',
                      isSelected: viewMode == CalendarViewMode.month,
                      onTap: () => ref
                          .read(calendarViewModeProvider.notifier)
                          .setMode(CalendarViewMode.month),
                    ),
                    _ViewTabButton(
                      label: 'Semana',
                      isSelected: viewMode == CalendarViewMode.week,
                      onTap: () => ref
                          .read(calendarViewModeProvider.notifier)
                          .setMode(CalendarViewMode.week),
                    ),
                    _ViewTabButton(
                      label: 'Día',
                      isSelected: viewMode == CalendarViewMode.day,
                      onTap: () => ref
                          .read(calendarViewModeProvider.notifier)
                          .setMode(CalendarViewMode.day),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Botón Principal: + Nuevo Evento
              ElevatedButton.icon(
                onPressed: onNewEventPressed,
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Nuevo Evento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CalendarTheme.accent,
                  foregroundColor: const Color(0xFF111318),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 30),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: CalendarTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: CalendarTheme.border, width: 1),
          ),
          child: Icon(
            icon,
            size: 18,
            color: CalendarTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ViewTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? CalendarTheme.elevatedSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: CalendarTheme.borderAccent, width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? CalendarTheme.textPrimary
                : CalendarTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
