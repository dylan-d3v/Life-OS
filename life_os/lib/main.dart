import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/crypto/crypto.dart';
import 'core/providers/crypto_providers.dart';
import 'core/providers/supabase_providers.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/shell/presentation/adaptive_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno desde .env
  await dotenv.load(fileName: '.env');

  var supabaseUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
  final supabaseAnonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

  // Sanitizar URL base de Supabase (remover /rest/v1 o trailing slash si se copiaron de PostgREST)
  if (supabaseUrl.endsWith('/')) {
    supabaseUrl = supabaseUrl.substring(0, supabaseUrl.length - 1);
  }
  if (supabaseUrl.endsWith('/rest/v1')) {
    supabaseUrl = supabaseUrl.substring(0, supabaseUrl.length - '/rest/v1'.length);
  }

  // 2. Inicializar cliente de Supabase y restaurar bóveda cifrada local (B2)
  final initialVault = KeyVaultService();
  KeyVaultNotifier.initialInstance = initialVault;

  if (supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project-id')) {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;
    await initialVault.restoreSessionFromKeystore(expectedEmail: currentEmail);
  } else {
    await initialVault.restoreSessionFromKeystore();
  }

  // 3. Configurar ventana nativa en escritorio (Windows / macOS / Linux)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 640),
      center: true,
      backgroundColor: Color(0xFF0F172A),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Life-OS — Ecosistema Personal E2EE',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    const ProviderScope(
      child: LifeOSApp(),
    ),
  );
}

class LifeOSApp extends ConsumerWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authStateProvider);
    final vault = ref.watch(keyVaultServiceProvider);
    // Escucha cambios en el ciclo de vida del controlador de autenticación
    ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Life-OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8), // Sky 400
          surface: Color(0xFF1E293B), // Slate 800
        ),
      ),
      home: authStateAsync.when(
        data: (authState) {
          final user = authState.session?.user ??
              ref.watch(supabaseClientProvider)?.auth.currentUser;
          // Si hay usuario autenticado pero la bóveda aún no intentó restaurarse en memoria, restaurar del keystore
          if (user != null && !vault.isUnlocked && !vault.restoreAttempted) {
            vault.restoreSessionFromKeystore(expectedEmail: user.email);
          }
          // El usuario solo accede si tiene sesión en Supabase y la bóveda E2EE está desbloqueada
          if (user != null && vault.isUnlocked) {
            return const AdaptiveScaffold();
          }
          return const AuthScreen();
        },
        loading: () {
          final directUser =
              ref.watch(supabaseClientProvider)?.auth.currentUser;
          if (directUser != null && !vault.isUnlocked && !vault.restoreAttempted) {
            vault.restoreSessionFromKeystore(expectedEmail: directUser.email);
          }
          if (directUser != null && vault.isUnlocked) {
            return const AdaptiveScaffold();
          }
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            ),
          );
        },
        error: (error, stack) => const AuthScreen(),
      ),
    );
  }
}
