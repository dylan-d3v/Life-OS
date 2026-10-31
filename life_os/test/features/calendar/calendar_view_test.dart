import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/calendar/domain/calendar_event_item.dart';
import 'package:life_os/features/calendar/presentation/calendar_provider.dart';
import 'package:life_os/features/calendar/presentation/calendar_view.dart';

class MockCalendarEventListNotifier extends CalendarEventListNotifier {
  final List<CalendarEventItem> _initialEvents;

  MockCalendarEventListNotifier([this._initialEvents = const []]);

  @override
  Future<List<CalendarEventItem>> build() async => _initialEvents;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> deleteEvent(String eventId) async {
    state = state.whenData(
      (events) => events.where((e) => e.id != eventId).toList(),
    );
  }
}

void main() {
  testWidgets('CalendarView muestra encabezado, filtros y estado vacío inicial',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventListProvider
              .overrideWith(() => MockCalendarEventListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CalendarView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Calendario y Agenda'), findsOneWidget);
    expect(find.text('Nuevo Evento'), findsOneWidget);
    expect(find.text('Próximos'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Pasados'), findsOneWidget);
    expect(find.textContaining('No tienes eventos'), findsOneWidget);
  });

  testWidgets('CalendarView muestra eventos y permite filtrar por pestaña',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final now = DateTime.now();
    final sampleEvents = [
      CalendarEventItem(
        id: '1',
        title: 'Presentación de Proyecto Life-OS',
        description: 'Demostración de cliente Windows nativo',
        location: 'Sala de Conferencias A',
        startTime: now.add(const Duration(days: 3)),
        endTime: now.add(const Duration(days: 3, hours: 2)),
        isAllDay: false,
        createdAt: now,
        updatedAt: now,
      ),
      CalendarEventItem(
        id: '2',
        title: 'Reunión de Retrospectiva Pasada',
        description: 'Cierre de la fase de base de datos',
        location: 'Virtual Meet',
        startTime: now.subtract(const Duration(days: 5, hours: 2)),
        endTime: now.subtract(const Duration(days: 5)),
        isAllDay: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventListProvider
              .overrideWith(() => MockCalendarEventListNotifier(sampleEvents)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CalendarView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Filtro por defecto: "Próximos" (solo el evento futuro visible)
    expect(find.text('Presentación de Proyecto Life-OS'), findsOneWidget);
    expect(find.text('Reunión de Retrospectiva Pasada'), findsNothing);

    // Cambiar a "Todos"
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();

    expect(find.text('Presentación de Proyecto Life-OS'), findsOneWidget);
    expect(find.text('Reunión de Retrospectiva Pasada'), findsOneWidget);

    // Cambiar a "Pasados"
    await tester.tap(find.text('Pasados'));
    await tester.pumpAndSettle();

    expect(find.text('Presentación de Proyecto Life-OS'), findsNothing);
    expect(find.text('Reunión de Retrospectiva Pasada'), findsOneWidget);
  });

  testWidgets('CalendarView abre diálogo modal al pulsar "Nuevo Evento"',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventListProvider
              .overrideWith(() => MockCalendarEventListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CalendarView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo Evento'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo Evento Cifrado'), findsOneWidget);
    expect(find.text('Título del evento'), findsOneWidget);
    expect(find.text('Ubicación o enlace'), findsOneWidget);
    expect(find.text('Descripción / Notas'), findsOneWidget);
    expect(find.text('Evento de todo el día'), findsOneWidget);
    expect(find.text('Crear Evento'), findsOneWidget);
  });
}

