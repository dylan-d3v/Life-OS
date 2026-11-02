import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/calendar_event_item.dart';
import '../calendar_provider.dart';
import '../calendar_theme.dart';
import 'calendar_mini_month.dart';

/// Barra lateral izquierda del módulo de Calendario (ancho aproximado: 240px).
///
/// Incluye:
/// 1. Título del módulo y branding.
/// 2. Mini calendario mensual interactivo.
/// 3. Filtros interactivos por categoría con indicadores de color y contadores.
/// 4. Filtros temporales (Próximos, Todos, Pasados).
class CalendarSidebar extends ConsumerWidget {
  final List<CalendarEventItem> allEvents;

  const CalendarSidebar({
    super.key,
    required this.allEvents,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(calendarFilterProvider);
    final selectedCategories = ref.watch(calendarCategoryFilterProvider);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: CalendarTheme.sidebarBg,
        border: Border(
          right: BorderSide(color: CalendarTheme.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado y Título del Módulo ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: CalendarTheme.accentMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CalendarTheme.accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: CalendarTheme.accentLight,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendario y Agenda',
                        style: TextStyle(
                          color: CalendarTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Workspace personal',
                        style: TextStyle(
                          color: CalendarTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: CalendarTheme.borderSubtle),

          // ── Contenido Scrollable ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Mini Calendario Mensual
                  CalendarMiniMonth(events: allEvents),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: CalendarTheme.borderSubtle),
                  const SizedBox(height: 16),

                  // 2. Filtros por Categoría
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CATEGORÍAS',
                        style: TextStyle(
                          color: CalendarTheme.textDisabled,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (selectedCategories.length < CalendarTheme.allCategories.length)
                        InkWell(
                          onTap: () => ref
                              .read(calendarCategoryFilterProvider.notifier)
                              .selectAll(),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              'Ver todas',
                              style: TextStyle(
                                color: CalendarTheme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ...CalendarTheme.allCategories.map((category) {
                    final isSelected = selectedCategories.contains(category);
                    final count = allEvents
                        .where((e) =>
                            e.category.toLowerCase() ==
                            category.toLowerCase())
                        .length;

                    return _CategoryFilterRow(
                      category: category,
                      isSelected: isSelected,
                      count: count,
                      onToggle: () => ref
                          .read(calendarCategoryFilterProvider.notifier)
                          .toggleCategory(category),
                    );
                  }),

                  const SizedBox(height: 20),
                  const Divider(height: 1, color: CalendarTheme.borderSubtle),
                  const SizedBox(height: 16),

                  // 3. Filtros de Estado / Tiempo (Próximos, Todos, Pasados)
                  const Text(
                    'FILTROS',
                    style: TextStyle(
                      color: CalendarTheme.textDisabled,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _StatusFilterItem(
                    label: 'Próximos',
                    icon: Icons.upcoming_outlined,
                    isSelected: activeFilter == CalendarFilter.upcoming,
                    onTap: () => ref
                        .read(calendarFilterProvider.notifier)
                        .setFilter(CalendarFilter.upcoming),
                  ),
                  const SizedBox(height: 4),
                  _StatusFilterItem(
                    label: 'Todos',
                    icon: Icons.clear_all_rounded,
                    isSelected: activeFilter == CalendarFilter.all,
                    onTap: () => ref
                        .read(calendarFilterProvider.notifier)
                        .setFilter(CalendarFilter.all),
                  ),
                  const SizedBox(height: 4),
                  _StatusFilterItem(
                    label: 'Pasados',
                    icon: Icons.history_rounded,
                    isSelected: activeFilter == CalendarFilter.past,
                    onTap: () => ref
                        .read(calendarFilterProvider.notifier)
                        .setFilter(CalendarFilter.past),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  final String category;
  final bool isSelected;
  final int count;
  final VoidCallback onToggle;

  const _CategoryFilterRow({
    required this.category,
    required this.isSelected,
    required this.count,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = CalendarTheme.colorForCategory(category);

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            // Indicador de color redondeado con checkbox visual
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isSelected
                    ? catColor
                    : CalendarTheme.panelBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? catColor
                      : CalendarTheme.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 10,
                      color: Color(0xFF111318),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected
                      ? CalendarTheme.textPrimary
                      : CalendarTheme.textDisabled,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? catColor.withValues(alpha: 0.15)
                      : CalendarTheme.elevatedSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? catColor
                        : CalendarTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilterItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? CalendarTheme.elevatedSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: CalendarTheme.borderAccent, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? CalendarTheme.accent
                  : CalendarTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? CalendarTheme.textPrimary
                    : CalendarTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

