import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/auth/presentation/auth_screen.dart';

void main() {
  testWidgets('AuthScreen renderiza campos de inicio de sesión y clave maestra', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthScreen(),
        ),
      ),
    );

    expect(find.text('Life-OS'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsWidgets);
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Contraseña de Cuenta'), findsOneWidget);
    expect(find.text('Contraseña Maestra E2EE'), findsOneWidget);
  });
}
