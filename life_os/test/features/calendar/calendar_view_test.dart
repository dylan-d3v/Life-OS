import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/calendar/domain/calendar_event_item.dart';
import 'package:life_os/features/calendar/presentation/calendar_provider.dart';
import 'package:life_os/features/calendar/presentation/calendar_view.dart';
import 'package:life_os/features/calendar/presentation/widgets/calendar_event_dialog.dart';

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
    expect(find.text('Presentación de Proyecto Life-OS'), findsAtLeastNWidgets(1));
    expect(find.text('Reunión de Retrospectiva Pasada'), findsNothing);

    // Cambiar a "Todos"
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();

    expect(find.text('Presentación de Proyecto Life-OS'), findsAtLeastNWidgets(1));
    expect(find.text('Reunión de Retrospectiva Pasada'), findsAtLeastNWidgets(1));

    // Cambiar a "Pasados"
    await tester.tap(find.text('Pasados'));
    await tester.pumpAndSettle();

    expect(find.text('Presentación de Proyecto Life-OS'), findsNothing);
    expect(find.text('Reunión de Retrospectiva Pasada'), findsAtLeastNWidgets(1));
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

  testWidgets(
      'CalendarView en móvil (360x780) muestra flechas de navegación (<, >, Hoy), botón Nuevo Evento y diálogo de edición sin desbordamiento (C1, C2, H1)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
    });

    final now = DateTime.now();
    final sampleEvent = CalendarEventItem(
      id: 'evt-mobile-1',
      title: 'Revisión de arquitectura móvil Life-OS',
      description: 'Validar barra de herramientas y formulario de edición',
      location: 'Remoto',
      // Usamos 22:00 a 23:59 del día actual para que sea un evento activo/próximo en el mismo día
      startTime: DateTime(now.year, now.month, now.day, 22, 0),
      endTime: DateTime(now.year, now.month, now.day, 23, 59),
      isAllDay: false,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventListProvider
              .overrideWith(() => MockCalendarEventListNotifier([sampleEvent])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CalendarView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // H1: Flechas de período anterior/siguiente, Hoy y selector Mes/Semana/Día visibles en móvil
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Mes'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Día'), findsOneWidget);

    // C2: Botón Nuevo Evento visible y accesible dentro de la pantalla móvil
    final newEventBtn = find.byKey(const Key('calendar_new_event_button'));
    expect(newEventBtn, findsOneWidget);

    // Navegar al período siguiente y regresar a Hoy funciona sin errores
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();

    // Cambiar a vista Día sin ningún overflow
    await tester.tap(find.text('Día'));
    await tester.pumpAndSettle();

    // C1: Abrir CalendarEventDialog en modo edición en pantalla móvil de 360px
    final BuildContext innerContext = tester.element(find.byType(CalendarView));
    showDialog(
      context: innerContext,
      builder: (_) => CalendarEventDialog(eventToEdit: sampleEvent),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar Evento Cifrado'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Guardar Cambios'), findsOneWidget);
  });
}

