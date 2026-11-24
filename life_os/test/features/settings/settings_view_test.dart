import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/core/providers/crypto_providers.dart';
import 'package:life_os/features/settings/presentation/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnlockedVaultNotifier extends KeyVaultNotifier {
  final KeyVaultService unlockedVault;
  _UnlockedVaultNotifier(this.unlockedVault);

  @override
  KeyVaultService build() => unlockedVault;
}

void main() {
  testWidgets(
      'SettingsView permite al usuario revelar y ocultar su clave criptográfica guardada (B2)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final vault = KeyVaultService();
    final keyBytes = List<int>.generate(32, (i) => i + 1);
    final secretKey = SecretKey(keyBytes);
    final expectedBase64 = base64Encode(keyBytes);

    vault.setActiveKey(
      secretKey,
      masterPassword: 'MiClaveSecretaUsuario2026',
      derivedKeyBase64: expectedBase64,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyVaultServiceProvider.overrideWith(
            () => _UnlockedVaultNotifier(vault),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SettingsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Por defecto la clave está oculta por seguridad
    expect(find.text('ESTADO: DESBLOQUEADA'), findsOneWidget);
    expect(find.text('Mostrar Clave Guardada'), findsOneWidget);
    expect(find.byKey(const Key('revealed_master_password')), findsNothing);
    expect(find.byKey(const Key('revealed_derived_key')), findsNothing);

    // Al pulsar "Mostrar Clave Guardada", se revela tanto la contraseña maestra como la clave derivada AES-256
    await tester.tap(find.byKey(const Key('toggle_show_saved_key_button')));
    await tester.pumpAndSettle();

    expect(find.text('Ocultar Clave'), findsOneWidget);
    expect(find.text('MiClaveSecretaUsuario2026'), findsOneWidget);
    expect(find.text(expectedBase64), findsOneWidget);

    // Al volver a pulsar, se oculta nuevamente
    await tester.tap(find.byKey(const Key('toggle_show_saved_key_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('revealed_master_password')), findsNothing);
  });
}
