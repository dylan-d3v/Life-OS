import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/shell/presentation/mobile_scaffold.dart';
import 'package:life_os/features/shell/presentation/navigation_provider.dart';

void main() {
  testWidgets('MobileScaffold renderiza NavigationBar M3 y FAB de Kev',
      (tester) async {
    // Configurar viewport de smartphone (400 x 800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MobileScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Validar encabezado móvil y badge E2EE
    expect(find.text('E2EE'), findsOneWidget);

    // Validar Floating Action Button de Kev
    final fabFinder = find.byKey(const Key('kev_mobile_fab'));
    expect(fabFinder, findsOneWidget);

    // Validar los destinos de la NavigationBar inferior M3
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Tareas'), findsWidgets);
    expect(find.text('Notas'), findsOneWidget);
    expect(find.text('Finanzas'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);
  });

  testWidgets('MobileScaffold permite alternar secciones desde la NavigationBar',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MobileScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navegar a Hoy
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(container.read(activeSectionProvider), NavSection.today);

    // Navegar a Finanzas
    await tester.tap(find.text('Finanzas'));
    await tester.pumpAndSettle();
    expect(container.read(activeSectionProvider), NavSection.finance);

    // Abrir "Más" para desplegar modal bottom sheet
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    expect(find.text('Más Secciones'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Proyectos y Metas'), findsOneWidget);
    expect(find.text('Ajustes del Sistema'), findsOneWidget);

    // Seleccionar Ajustes del Sistema
    await tester.tap(find.text('Ajustes del Sistema'));
    await tester.pumpAndSettle();
    expect(container.read(activeSectionProvider), NavSection.settings);
  });
}
