import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/supabase_providers.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_event_item.dart';
import 'calendar_theme.dart';

// =============================================================================
// Repositorio de Calendario
// =============================================================================

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    client: ref.watch(supabaseClientProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    vault: ref.watch(keyVaultServiceProvider),
  );
});

// =============================================================================
// Modos de Vista y Filtros
// =============================================================================

enum CalendarFilter { upcoming, all, past }

enum CalendarViewMode { month, week, day }

class CalendarFilterNotifier extends Notifier<CalendarFilter> {
  @override
  CalendarFilter build() => CalendarFilter.upcoming;

  void setFilter(CalendarFilter filter) {
    state = filter;
  }
}

final calendarFilterProvider =
    NotifierProvider<CalendarFilterNotifier, CalendarFilter>(
  CalendarFilterNotifier.new,
);

class CalendarViewModeNotifier extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.month;

  void setMode(CalendarViewMode mode) {
    state = mode;
  }
}

final calendarViewModeProvider =
    NotifierProvider<CalendarViewModeNotifier, CalendarViewMode>(
  CalendarViewModeNotifier.new,
);

// =============================================================================
// Fechas Activas y Seleccionadas
// =============================================================================

class CalendarSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void selectDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final calendarSelectedDateProvider =
    NotifierProvider<CalendarSelectedDateNotifier, DateTime>(
  CalendarSelectedDateNotifier.new,
);

class CalendarActiveMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month, 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1, 1);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void goToToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, 1);
  }
}

final calendarActiveMonthProvider =
    NotifierProvider<CalendarActiveMonthNotifier, DateTime>(
  CalendarActiveMonthNotifier.new,
);

// =============================================================================
// Filtros de Categorías y Búsqueda
// =============================================================================

class CalendarCategoryFilterNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => Set<String>.from(CalendarTheme.allCategories);

  void toggleCategory(String category) {
    final updated = Set<String>.from(state);
    if (updated.contains(category)) {
      if (updated.length > 1) {
        updated.remove(category);
      }
    } else {
      updated.add(category);
    }
    state = updated;
  }

  void selectAll() {
    state = Set<String>.from(CalendarTheme.allCategories);
  }
}

final calendarCategoryFilterProvider =
    NotifierProvider<CalendarCategoryFilterNotifier, Set<String>>(
  CalendarCategoryFilterNotifier.new,
);

class CalendarSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) {
    state = query;
  }
}

final calendarSearchQueryProvider =
    NotifierProvider<CalendarSearchQueryNotifier, String>(
  CalendarSearchQueryNotifier.new,
);

// =============================================================================
// Lista de Eventos y Repositorio
// =============================================================================

class CalendarEventListNotifier
    extends AsyncNotifier<List<CalendarEventItem>> {
  @override
  Future<List<CalendarEventItem>> build() => _loadEvents();

  Future<List<CalendarEventItem>> _loadEvents() async {
    final repo = ref.read(calendarRepositoryProvider);
    return repo.fetchEvents();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadEvents);
  }

  Future<void> addEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String description = '',
    String location = '',
    String category = 'Personal',
  }) async {
    final repo = ref.read(calendarRepositoryProvider);
    final newEvent = await repo.createEvent(
      title: title,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      description: description,
      location: location,
      category: category,
    );

    state = state.whenData((events) {
      final updated = [...events, newEvent];
      updated.sort((a, b) => a.startTime.compareTo(b.startTime));
      return updated;
    });
  }

  Future<void> updateEvent(CalendarEventItem event) async {
    final repo = ref.read(calendarRepositoryProvider);
    await repo.updateEvent(event);

    state = state.whenData((events) {
      final updated =
          events.map((e) => e.id == event.id ? event : e).toList();
      updated.sort((a, b) => a.startTime.compareTo(b.startTime));
      return updated;
    });
  }

  Future<void> deleteEvent(String eventId) async {
    final repo = ref.read(calendarRepositoryProvider);

    state = state.whenData(
      (events) => events.where((e) => e.id != eventId).toList(),
    );

    await repo.softDeleteEvent(eventId);
  }
}

final calendarEventListProvider = AsyncNotifierProvider<
    CalendarEventListNotifier, List<CalendarEventItem>>(
  CalendarEventListNotifier.new,
);

// =============================================================================
// Proveedores de Filtrado Combinado
// =============================================================================

/// Proveedor filtrado según la opción seleccionada (Próximos, Todos, Pasados).
/// Mantiene total compatibilidad con las pruebas unitarias existentes.
final filteredCalendarEventsProvider =
    Provider<AsyncValue<List<CalendarEventItem>>>((ref) {
  final filter = ref.watch(calendarFilterProvider);
  final eventsAsync = ref.watch(calendarEventListProvider);
  final now = DateTime.now();

  return eventsAsync.whenData((events) {
    switch (filter) {
      case CalendarFilter.upcoming:
        return events
            .where((e) => e.endTime.isAfter(now) || e.startTime.isAfter(now))
            .toList();
      case CalendarFilter.all:
        return events;
      case CalendarFilter.past:
        return events
            .where((e) => e.endTime.isBefore(now))
            .toList();
    }
  });
});

/// Proveedor principal del Workspace con filtrado por categoría y búsqueda textual.
final calendarWorkspaceEventsProvider =
    Provider<AsyncValue<List<CalendarEventItem>>>((ref) {
  final baseEventsAsync = ref.watch(filteredCalendarEventsProvider);
  final selectedCategories = ref.watch(calendarCategoryFilterProvider);
  final searchQuery = ref.watch(calendarSearchQueryProvider).trim().toLowerCase();

  return baseEventsAsync.whenData((events) {
    return events.where((event) {
      // Filtro de categorías
      final matchesCategory = selectedCategories.isEmpty ||
          selectedCategories.contains(event.category) ||
          (event.category.isEmpty && selectedCategories.contains('Personal'));

      if (!matchesCategory) return false;

      // Filtro de búsqueda
      if (searchQuery.isNotEmpty) {
        final title = event.title.toLowerCase();
        final desc = event.description.toLowerCase();
        final loc = event.location.toLowerCase();
        return title.contains(searchQuery) ||
            desc.contains(searchQuery) ||
            loc.contains(searchQuery);
      }

      return true;
    }).toList();
  });
});
