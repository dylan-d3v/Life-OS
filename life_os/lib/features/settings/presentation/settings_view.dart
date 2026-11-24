import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../ai/presentation/ai_providers.dart';
import '../../ai/presentation/kev_command_bar_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../calendar/presentation/calendar_provider.dart';
import '../../finance/presentation/finance_provider.dart';
import '../../notes/presentation/notes_provider.dart';
import '../../projects/presentation/projects_provider.dart';
import '../../tasks/presentation/tasks_provider.dart';
import 'settings_provider.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _showSavedKey = false;
  bool _encryptBackup = true;
  bool _isExporting = false;
  String? _lastBackupStatusMessage;

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

  Future<void> _handleExportBackup() async {
    final vault = ref.read(keyVaultServiceProvider);
    if (!vault.isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desbloquea primero la bóveda para exportar tus datos.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final bundle = ref.read(currentAccountBackupBundleProvider);
      final jsonContent = await backupService.exportBackupToJson(
        bundle: bundle,
        encrypt: _encryptBackup,
        customPassword: vault.activeMasterPassword,
      );

      await Clipboard.setData(ClipboardData(text: jsonContent));
      String savedPath = 'Portapapeles';
      try {
        final file = await backupService.saveBackupToFile(jsonContent);
        savedPath = file.path;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _lastBackupStatusMessage =
            'Respaldo exportado (${bundle.totalRecords} registros, ${_encryptBackup ? "Cifrado AES-256-GCM" : "JSON en claro"}). Guardado en: $savedPath y copiado al portapapeles.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Respaldo generado (${bundle.totalRecords} registros) y copiado al portapapeles.',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar respaldo: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showImportBackupDialog() {
    final jsonController = TextEditingController();
    final passwordController = TextEditingController();
    final filePathController = TextEditingController();
    String? dialogError;
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> runImport() async {
              setDialogState(() {
                dialogError = null;
                isImporting = true;
              });

              try {
                String rawJson = jsonController.text.trim();
                final pathText = filePathController.text.trim();
                if (rawJson.isEmpty && pathText.isNotEmpty) {
                  final file = File(pathText);
                  if (!await file.exists()) {
                    throw const FormatException(
                      'No se encontró ningún archivo en la ruta indicada.',
                    );
                  }
                  rawJson = await file.readAsString();
                }

                if (rawJson.isEmpty) {
                  throw const FormatException(
                    'Pega el contenido JSON del respaldo o indica la ruta del archivo.',
                  );
                }

                final backupService = ref.read(backupServiceProvider);
                final parsedBundle = await backupService.validateAndParseBackup(
                  rawJson: rawJson,
                  customPassword: passwordController.text.trim().isNotEmpty
                      ? passwordController.text.trim()
                      : null,
                );

                final existingBundle =
                    ref.read(currentAccountBackupBundleProvider);
                final summary = await backupService.importBackupToSupabase(
                  incoming: parsedBundle,
                  existingInMemory: existingBundle,
                );

                // Refrescar proveedores para reflejar datos importados
                ref.invalidate(projectListProvider);
                ref.invalidate(taskListProvider);
                ref.invalidate(noteListProvider);
                ref.invalidate(calendarEventListProvider);
                ref.invalidate(financeTransactionListProvider);
                ref.invalidate(dailyBriefingProvider);

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();

                if (!mounted) return;
                setState(() {
                  _lastBackupStatusMessage =
                      'Importación exitosa: ${summary.totalProcessed} registros procesados (${summary.updatedExistingCount} actualizados sin duplicar).';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Respaldo importado con éxito (${summary.totalProcessed} registros verificados).',
                    ),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
              } catch (e) {
                setDialogState(() {
                  isImporting = false;
                  dialogError = e.toString();
                });
              }
            }

            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 520, maxHeight: 620),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Importar Respaldo Verificado',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () => Navigator.of(ctx).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Se verificará la firma SHA-256 y autenticidad AES-256-GCM antes de fusionar por UUID (sin duplicar registros existentes).',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                key: const Key('import_backup_filepath_field'),
                                controller: filePathController,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  labelText:
                                      'Ruta de archivo local (.lifeos.json) — Opcional',
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 12),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF334155)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                key: const Key('import_backup_json_field'),
                                controller: jsonController,
                                maxLines: 5,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      'O pega aquí el contenido JSON del respaldo',
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 12),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF334155)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                key: const Key('import_backup_password_field'),
                                controller: passwordController,
                                obscureText: true,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  labelText:
                                      'Contraseña del respaldo (si proviene de otra cuenta)',
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 12),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF334155)),
                                  ),
                                ),
                              ),
                              if (dialogError != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  dialogError!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: isImporting
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton.icon(
                            key: const Key('confirm_import_backup_button'),
                            onPressed: isImporting ? null : runImport,
                            icon: const Icon(Icons.download_done_rounded,
                                size: 16),
                            label: const Text('Validar e Importar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(keyVaultServiceProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final currentBundle = ref.watch(currentAccountBackupBundleProvider);
    final notifService = ref.watch(notificationCoordinatorProvider);
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
              'Configuración de seguridad, asistente Kev, respaldos y sesión',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // ── 1. BÓVEDA CRIPTOGRÁFICA Y SESIÓN ──
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

            // ── 2. CONFIGURACIÓN DEL ASISTENTE KEV IA (F1 Parte 1 & A1) ──
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
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 18, color: Color(0xFF818CF8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Asistente Inteligente Kev',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Botón flotante de Kev siempre disponible (24/7)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Mantiene visible el botón rápido de Kev en las vistas móviles.',
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
                        key: const Key('kev_fab_visible_switch'),
                        value: appSettings.kevFabVisible,
                        activeTrackColor: const Color(0xFF6366F1),
                        onChanged: (val) {
                          ref
                              .read(appSettingsProvider.notifier)
                              .setKevFabVisible(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Volver a mostrar la guía de sugerencias al abrir Kev',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                      ),
                      OutlinedButton.icon(
                        key: const Key('reset_kev_onboarding_button'),
                        onPressed: () async {
                          await ref
                              .read(kevCommandBarProvider.notifier)
                              .resetOnboarding();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Guía de sugerencias de Kev restablecida.',
                              ),
                              backgroundColor: Color(0xFF6366F1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('Restablecer Sugerencias'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF818CF8),
                          side: const BorderSide(color: Color(0xFF334155)),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 3. NOTIFICACIONES Y RECORDATORIOS (E1 + F1 Parte 2) ──
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active_outlined,
                              size: 18, color: Color(0xFF38BDF8)),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Notificaciones y Recordatorios Locales',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          '${notifService.scheduledReminders.length} recordatorios programados',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activar notificaciones de tareas y eventos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Programa alertas locales sin exponer tus títulos cifrados a servidores externos.',
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
                        key: const Key('notifications_enabled_switch'),
                        value: appSettings.notificationsEnabled,
                        activeTrackColor: const Color(0xFF0284C7),
                        onChanged: (enabled) {
                          ref
                              .read(appSettingsProvider.notifier)
                              .setNotificationsEnabled(enabled);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 12),

                  // Hora del recordatorio / resumen diario
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Horario de aviso y resumen diario de tareas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Hora a la que recibirás el recordatorio matutino de tus pendientes.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        key: const Key('daily_reminder_time_button'),
                        onPressed: !appSettings.notificationsEnabled
                            ? null
                            : () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: appSettings.dailyReminderHour,
                                    minute: appSettings.dailyReminderMinute,
                                  ),
                                );
                                if (picked != null) {
                                  await ref
                                      .read(appSettingsProvider.notifier)
                                      .setDailyReminderTime(
                                        picked.hour,
                                        picked.minute,
                                      );
                                }
                              },
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(appSettings.formattedReminderTime),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Selección de tono de notificación
                  const Text(
                    'Tono de notificación:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const [
                        ('default', 'Estándar'),
                        ('chime', 'Campana Suave'),
                        ('urgent', 'Alerta Prioritaria'),
                        ('silent', 'Silencioso'),
                      ])
                        ChoiceChip(
                          key: Key('tone_chip_${entry.$1}'),
                          label: Text(entry.$2),
                          selected: appSettings.notificationTone == entry.$1,
                          selectedColor: const Color(0xFF0284C7),
                          backgroundColor: const Color(0xFF0F172A),
                          labelStyle: TextStyle(
                            color: appSettings.notificationTone == entry.$1
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          onSelected: !appSettings.notificationsEnabled
                              ? null
                              : (_) {
                                  ref
                                      .read(appSettingsProvider.notifier)
                                      .setNotificationTone(entry.$1);
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const Key('test_notification_button'),
                    onPressed: !appSettings.notificationsEnabled
                        ? null
                        : () {
                            final triggered =
                                notifService.triggerTestNotification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${triggered.title}: ${triggered.body}'),
                                backgroundColor: const Color(0xFF0284C7),
                              ),
                            );
                          },
                    icon: const Icon(Icons.notifications_none_rounded, size: 16),
                    label: const Text('Probar Notificación Ahora'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF334155)),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 4. RESPALDO, EXPORTACIÓN E IMPORTACIÓN DE DATOS (G1) ──
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
                  const Row(
                    children: [
                      Icon(Icons.cloud_download_outlined,
                          size: 18, color: Color(0xFF38BDF8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Respaldo y Soberanía de Datos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descarga o restaura tus datos con verificación de integridad SHA-256. Registros actuales en sesión: ${currentBundle.totalRecords} (${currentBundle.projects.length} proyectos, ${currentBundle.tasks.length} tareas, ${currentBundle.notes.length} notas, ${currentBundle.calendarEvents.length} eventos, ${currentBundle.financeTransactions.length} finanzas).',
                    style:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cifrar archivo de respaldo con AES-256-GCM (Recomendado)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Protege el archivo con tu contraseña maestra para que nadie pueda leerlo fuera de Life-OS.',
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
                        key: const Key('encrypt_backup_switch'),
                        value: _encryptBackup,
                        activeTrackColor: const Color(0xFF059669),
                        onChanged: (val) =>
                            setState(() => _encryptBackup = val),
                      ),
                    ],
                  ),
                  if (!_encryptBackup) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x22F59E0B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x66F59E0B)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: Color(0xFFFBBF24)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Advertencia: Al desactivar el cifrado, el archivo JSON contendrá tu información personal en texto legible.',
                              style: TextStyle(
                                  color: Color(0xFFFBBF24), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        key: const Key('export_backup_button'),
                        onPressed: _isExporting ? null : _handleExportBackup,
                        icon: const Icon(Icons.upload_file_rounded, size: 17),
                        label: Text(
                          _isExporting
                              ? 'Exportando...'
                              : 'Exportar Respaldo de Cuenta',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('open_import_backup_dialog_button'),
                        onPressed: _showImportBackupDialog,
                        icon: const Icon(Icons.restore_page_outlined, size: 17),
                        label: const Text('Importar Respaldo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  if (_lastBackupStatusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _lastBackupStatusMessage!,
                      key: const Key('backup_status_message'),
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 12,
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
