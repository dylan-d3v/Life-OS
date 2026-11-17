import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/shell/presentation/adaptive_scaffold.dart';

void main() {
  testWidgets('AdaptiveScaffold conmuta a MobileScaffold en pantallas compactas',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdaptiveScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Debe renderizar el FAB móvil y el badge E2EE
    expect(find.byKey(const Key('kev_mobile_fab')), findsOneWidget);
    expect(find.text('E2EE'), findsOneWidget);
  });

  testWidgets('AdaptiveScaffold conmuta a DesktopScaffold en pantallas panorámicas',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdaptiveScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // En escritorio debe estar presente el botón con atajo de teclado Ctrl + K
    expect(find.byKey(const Key('kev_assistant_shortcut_button')),
        findsOneWidget);
  });
}
