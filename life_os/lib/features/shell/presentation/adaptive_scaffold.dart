import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/realtime_sync_service.dart';
import 'desktop_scaffold.dart';
import 'mobile_scaffold.dart';

/// Shell adaptativo que conmuta automáticamente entre la experiencia
/// de escritorio multi-columna (Windows/Linux/macOS) y la experiencia
/// móvil táctil M3 (Android/iOS y pantallas compactas).
///
/// Además mantiene activa la suscripción de sincronización en tiempo real (I1)
/// y gestiona la actualización silenciosa al regresar de segundo plano.
class AdaptiveScaffold extends ConsumerStatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(realtimeSyncServiceProvider).handleLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene vivo el coordinador de sincronización Realtime mientras la sesión esté activa
    ref.watch(realtimeSyncServiceProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // En plataformas móviles nativas siempre se renderiza MobileScaffold
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          return const MobileScaffold();
        }

        // En escritorio o web se evalúa el ancho disponible
        if (constraints.maxWidth >= 850) {
          return const DesktopScaffold();
        }

        return const MobileScaffold();
      },
    );
  }
}
