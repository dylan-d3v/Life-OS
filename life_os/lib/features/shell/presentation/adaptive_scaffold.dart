import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/sync/realtime_sync_service.dart';
import 'desktop_scaffold.dart';
import 'mobile_scaffold.dart';

/// Shell adaptativo que conmuta automáticamente entre la experiencia
/// de escritorio multi-columna (Windows/Linux/macOS) y la experiencia
/// móvil táctil M3 (Android/iOS y pantallas compactas).
///
/// Además mantiene activa la suscripción de sincronización en tiempo real (I1),
/// el coordinador de notificaciones locales de recordatorios (E1) y gestiona
/// la actualización silenciosa al regresar de segundo plano.
class AdaptiveScaffold extends ConsumerStatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold>
    with WidgetsBindingObserver {
  StreamSubscription<TriggeredNotification>? _notificationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifService = ref.read(notificationServiceProvider);
      _notificationSub =
          notifService.onNotificationStream.listen(_showInAppNotificationBanner);
    });
  }

  void _showInAppNotificationBanner(TriggeredNotification notification) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF38BDF8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (notification.body.isNotEmpty)
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(realtimeSyncServiceProvider).handleLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene vivos el coordinador de sincronización Realtime (I1) y de notificaciones (E1)
    ref.watch(realtimeSyncServiceProvider);
    ref.watch(notificationCoordinatorProvider);

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
