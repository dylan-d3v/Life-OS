import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'desktop_scaffold.dart';
import 'mobile_scaffold.dart';

/// Shell adaptativo que conmuta automáticamente entre la experiencia
/// de escritorio multi-columna (Windows/Linux/macOS) y la experiencia
/// móvil táctil M3 (Android/iOS y pantallas compactas).
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key});

  @override
  Widget build(BuildContext context) {
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
