import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/providers/crypto_providers.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/home/presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno desde .env
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('ADVERTENCIA: SUPABASE_URL o SUPABASE_ANON_KEY no están definidos en .env');
  }

  // 2. Inicializar Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  // 3. Configurar ventana de escritorio en Windows/Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(900, 600),
      center: true,
      title: 'Life-OS • Segundo Cerebro',
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
          final user = authState.session?.user;
          // El usuario solo accede si tiene sesión en Supabase y la bóveda E2EE está desbloqueada
          if (user != null && vault.isUnlocked) {
            return const HomeScreen();
          }
          return const AuthScreen();
        },
        loading: () => const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
          ),
        ),
        error: (error, stack) => const AuthScreen(),
      ),
    );
  }
}
