import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/shell/presentation/desktop_scaffold.dart';

void main() {
  testWidgets('DesktopScaffold renderiza sidebar y permite alternar secciones', (tester) async {
    // Establecer tamaño de pantalla de escritorio para el test
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verificación inicial: Sección Tareas por defecto
    expect(find.text('Tareas'), findsWidgets);
    expect(find.text('Gestor de Tareas'), findsOneWidget);

    // Navegar a Notas
    await tester.tap(find.text('Notas'));
    await tester.pumpAndSettle();
    expect(find.text('Notas Diarias'), findsWidgets);

    // Navegar a Ajustes
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Ajustes del Sistema'), findsOneWidget);
  });
}

