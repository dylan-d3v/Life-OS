import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/supabase_providers.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_event_item.dart';

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
// Filtro de Vista
// =============================================================================

enum CalendarFilter { upcoming, all, past }

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

// =============================================================================
// Lista de Eventos
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
  }) async {
    final repo = ref.read(calendarRepositoryProvider);
    final newEvent = await repo.createEvent(
      title: title,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      description: description,
      location: location,
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

/// Proveedor filtrado según la opción seleccionada (Próximos, Todos, Pasados).
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

