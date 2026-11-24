import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _showSavedKey = false;

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiada al portapapeles'),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(keyVaultServiceProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;
    final masterPassword = vault.activeMasterPassword;
    final derivedKeyBase64 = vault.activeDerivedKeyBase64;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajustes del Sistema',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Configuración de seguridad, cuenta y estado de la sincronización',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bóveda Criptográfica Local (Zero-Knowledge)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El cifrado se realiza con AES-256-GCM. Tu clave maestra nunca sale de este dispositivo.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: vault.isUnlocked
                              ? const Color(0xFF065F46)
                              : const Color(0xFF7F1D1D),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vault.isUnlocked
                              ? 'ESTADO: DESBLOQUEADA'
                              : 'ESTADO: BLOQUEADA',
                          style: TextStyle(
                            color: vault.isUnlocked
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF87171),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        'Cuenta: ${user?.email ?? "Desconocido"}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 12),

                  // Switch de persistencia segura de sesión (B2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mantener sesión y bóveda iniciadas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Custodia la clave derivada cifrada en el almacén seguro del sistema para no pedirla al reabrir la app.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        key: const Key('persist_session_switch'),
                        value: vault.persistSessionEnabled,
                        activeTrackColor: const Color(0xFF0284C7),
                        onChanged: (enabled) async {
                          await vault.setPersistSessionEnabled(
                            enabled,
                            userEmail: user?.email,
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),

                  if (vault.isUnlocked) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 14),

                    // Sección para visualizar la clave guardada (solo para el usuario)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.vpn_key_outlined,
                              size: 16,
                              color: Color(0xFF38BDF8),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Clave Criptográfica Guardada',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          key: const Key('toggle_show_saved_key_button'),
                          onPressed: () {
                            setState(() => _showSavedKey = !_showSavedKey);
                          },
                          icon: Icon(
                            _showSavedKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 16,
                          ),
                          label: Text(
                            _showSavedKey
                                ? 'Ocultar Clave'
                                : 'Mostrar Clave Guardada',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: _showSavedKey
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (masterPassword != null &&
                                    masterPassword.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Contraseña Maestra E2EE:',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Copiar Contraseña Maestra',
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 15,
                                          color: Color(0xFF38BDF8),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _copyToClipboard(
                                          'Contraseña Maestra',
                                          masterPassword,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    masterPassword,
                                    key: const Key('revealed_master_password'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Clave Derivada AES-256 (Keystore Base64):',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (derivedKeyBase64 != null &&
                                        derivedKeyBase64.isNotEmpty)
                                      IconButton(
                                        tooltip: 'Copiar Clave Derivada',
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 15,
                                          color: Color(0xFF38BDF8),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _copyToClipboard(
                                          'Clave Derivada AES-256',
                                          derivedKeyBase64,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  derivedKeyBase64 ??
                                      'Clave activa en memoria segura',
                                  key: const Key('revealed_derived_key'),
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              '••••••••••••••••••••••••••••••••  (Protegida — Pulsa "Mostrar Clave Guardada" para inspeccionarla)',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(authControllerProvider.notifier).signOut();
              },
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Bloquear Bóveda y Cerrar Sesión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
