import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final vault = ref.watch(keyVaultServiceProvider);
    final currentUser = authRepo.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text('Life-OS • Segundo Cerebro'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar Sesión y Bloquear Bóveda',
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Color(0xFF10B981), // Emerald 500
              ),
              const SizedBox(height: 16),
              const Text(
                '¡Autenticación y Bóveda E2EE Activas!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Usuario: ${currentUser?.email ?? "Desconocido"}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Estado de la Bóveda: ',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: vault.isUnlocked
                          ? const Color(0xFF065F46)
                          : const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vault.isUnlocked ? 'DESBLOQUEADA (AES-256)' : 'BLOQUEADA',
                      style: TextStyle(
                        color: vault.isUnlocked
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF87171),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 16),
              const Text(
                'El cliente está conectado a Supabase y listo para la Tarea 3.4 (Shell de Escritorio) y Tarea 3.5 (Módulo de Tareas E2EE).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

