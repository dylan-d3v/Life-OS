import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/ai/presentation/ai_providers.dart';
import '../../features/calendar/presentation/calendar_provider.dart';
import '../../features/finance/presentation/finance_provider.dart';
import '../../features/notes/presentation/notes_provider.dart';
import '../../features/projects/presentation/projects_provider.dart';
import '../../features/tasks/presentation/tasks_provider.dart';
import '../crypto/crypto.dart';
import '../providers/crypto_providers.dart';
import '../providers/supabase_providers.dart';

/// Callback para notificar qué tabla fue sincronizada.
typedef TableSyncCallback = void Function(String table);

/// Servicio de sincronización automática en tiempo real (Fase 3 - I1).
///
/// Responsabilidades:
/// 1. Suscribirse eficientemente a cambios `postgres_changes` de Supabase en un
///    único canal multiplexado para las 5 tablas core (`tasks`, `notes`,
///    `finance_transactions`, `calendar_events`, `projects`).
/// 2. Aplicar debounce por tabla (400 ms por defecto) para evitar consultas
///    redundantes ante ráfagas de actualizaciones y refrescar únicamente el
///    módulo afectado.
/// 3. Gestionar el ciclo de vida de la aplicación (`AppLifecycleState.resumed`)
///    para sincronizar cambios ocurridos mientras el dispositivo estuvo suspendido.
class RealtimeSyncService {
  static const List<String> watchedTables = [
    'tasks',
    'notes',
    'finance_transactions',
    'calendar_events',
    'projects',
  ];

  final SupabaseClient? client;
  final KeyVaultService vault;
  final Duration debounceDuration;
  final Duration minResumeInterval;
  final TableSyncCallback? onInvalidateTable;

  final Map<String, Timer> _debounceTimers = {};
  final List<String> _syncedTablesHistory = [];
  RealtimeChannel? _channel;
  DateTime? _lastBackgroundTime;
  DateTime? _lastFullSyncTime;
  bool _isDisposed = false;

  RealtimeSyncService({
    required this.client,
    required this.vault,
    this.debounceDuration = const Duration(milliseconds: 400),
    this.minResumeInterval = const Duration(seconds: 15),
    this.onInvalidateTable,
  });

  /// Historial de tablas sincronizadas en la sesión (útil para diagnósticos y tests).
  List<String> get syncedTablesHistory =>
      List.unmodifiable(_syncedTablesHistory);

  /// Indica si el canal Realtime de Supabase está activo.
  bool get isSubscribed => _channel != null;

  /// Inicia la suscripción Realtime en Supabase si hay cliente, usuario autenticado y bóveda desbloqueada.
  void startSubscription() {
    if (_isDisposed || !vault.isUnlocked) return;
    final supabase = client;
    final userId = supabase?.auth.currentUser?.id;
    if (supabase == null || userId == null || _channel != null) return;

    try {
      var channel = supabase.channel('life_os_sync_$userId');

      for (final table in watchedTables) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => notifyTableChanged(table),
        );
      }

      _channel = channel..subscribe();
    } catch (_) {
      // En entornos sin WebSocket disponible, degradar silenciosamente a sync por ciclo de vida.
    }
  }

  /// Detiene la suscripción Realtime y cancela timers pendientes.
  Future<void> stopSubscription() async {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    final ch = _channel;
    _channel = null;
    if (ch != null && client != null) {
      try {
        await client!.removeChannel(ch);
      } catch (_) {}
    }
  }

  /// Notifica que una tabla específica sufrió un cambio en la base de datos.
  /// Aplica debounce por tabla para agrupar cambios simultáneos en una sola actualización.
  void notifyTableChanged(String table) {
    if (_isDisposed || !vault.isUnlocked) return;
    if (!watchedTables.contains(table)) return;

    _debounceTimers[table]?.cancel();
    _debounceTimers[table] = Timer(debounceDuration, () {
      if (_isDisposed || !vault.isUnlocked) return;
      _executeTableSync(table);
    });
  }

  void _executeTableSync(String table) {
    _syncedTablesHistory.add(table);
    onInvalidateTable?.call(table);
  }

  /// Gestiona las transiciones de ciclo de vida de la app (móvil y escritorio).
  void handleLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      onAppResumed();
    }
  }

  /// Al regresar a primer plano, verifica si transcurrió el intervalo mínimo
  /// y sincroniza las tablas activas de forma controlada.
  void onAppResumed({DateTime? nowOverride}) {
    if (_isDisposed || !vault.isUnlocked) return;

    final now = nowOverride ?? DateTime.now();
    final refTime = _lastBackgroundTime ?? _lastFullSyncTime;

    if (refTime == null || now.difference(refTime) >= minResumeInterval) {
      _lastFullSyncTime = now;
      _lastBackgroundTime = null;
      for (final table in watchedTables) {
        _executeTableSync(table);
      }
    }

    // Asegurar que la suscripción Realtime esté activa al volver
    if (_channel == null) {
      startSubscription();
    }
  }

  void dispose() {
    _isDisposed = true;
    stopSubscription();
  }
}

/// Proveedor global que conecta [RealtimeSyncService] con los 5 proveedores
/// de entidades y el Briefing Diario de Life-OS.
final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final vault = ref.watch(keyVaultServiceProvider);

  final service = RealtimeSyncService(
    client: client,
    vault: vault,
    onInvalidateTable: (table) {
      switch (table) {
        case 'tasks':
          ref.invalidate(taskListProvider);
          ref.invalidate(dailyBriefingProvider);
          break;
        case 'notes':
          ref.invalidate(noteListProvider);
          break;
        case 'finance_transactions':
          ref.invalidate(financeTransactionListProvider);
          ref.invalidate(dailyBriefingProvider);
          break;
        case 'calendar_events':
          ref.invalidate(calendarEventListProvider);
          ref.invalidate(dailyBriefingProvider);
          break;
        case 'projects':
          ref.invalidate(projectListProvider);
          break;
      }
    },
  );

  if (vault.isUnlocked) {
    service.startSubscription();
  }

  ref.onDispose(service.dispose);
  return service;
});
