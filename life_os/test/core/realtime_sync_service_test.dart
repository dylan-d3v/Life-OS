import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/core/sync/realtime_sync_service.dart';

void main() {
  group('RealtimeSyncService Tests (Fase 3 - I1)', () {
    late KeyVaultService unlockedVault;

    setUp(() async {
      unlockedVault = KeyVaultService();
      final key = await AesGcm.with256bits().newSecretKey();
      unlockedVault.setActiveKey(key);
    });

    test(
        'aplica debounce por tabla y actualiza únicamente la entidad modificada ante ráfagas de eventos',
        () async {
      final invalidated = <String>[];
      final syncService = RealtimeSyncService(
        client: null,
        vault: unlockedVault,
        debounceDuration: const Duration(milliseconds: 40),
        onInvalidateTable: invalidated.add,
      );
      addTearDown(syncService.dispose);

      // Simulamos 5 cambios consecutivos rápidos en 'tasks' y 2 en 'notes'
      syncService.notifyTableChanged('tasks');
      syncService.notifyTableChanged('tasks');
      syncService.notifyTableChanged('tasks');
      syncService.notifyTableChanged('notes');
      syncService.notifyTableChanged('tasks');
      syncService.notifyTableChanged('notes');

      // Antes de que expire el debounce, no se ha disparado ninguna recarga innecesaria
      expect(invalidated, isEmpty);

      // Esperamos a que se cumpla la ventana de debounce
      await Future<void>.delayed(const Duration(milliseconds: 90));

      // Solo se ejecutó 1 actualización para 'tasks' y 1 para 'notes' (y 0 para finance/calendar/projects)
      expect(invalidated, equals(['tasks', 'notes']));
      expect(syncService.syncedTablesHistory, equals(['tasks', 'notes']));
    });

    test('ignora eventos si la bóveda criptográfica está bloqueada', () async {
      final lockedVault = KeyVaultService();
      final invalidated = <String>[];
      final syncService = RealtimeSyncService(
        client: null,
        vault: lockedVault,
        debounceDuration: const Duration(milliseconds: 20),
        onInvalidateTable: invalidated.add,
      );
      addTearDown(syncService.dispose);

      syncService.notifyTableChanged('tasks');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(invalidated, isEmpty);
    });

    test(
        'sincroniza las tablas al regresar de segundo plano (AppLifecycleState.resumed) solo si superó el intervalo mínimo',
        () {
      final invalidated = <String>[];
      final syncService = RealtimeSyncService(
        client: null,
        vault: unlockedVault,
        minResumeInterval: const Duration(seconds: 15),
        onInvalidateTable: invalidated.add,
      );
      addTearDown(syncService.dispose);

      final t0 = DateTime(2026, 11, 24, 10, 0, 0);

      // Primera reanudación: sincroniza las 5 tablas
      syncService.onAppResumed(nowOverride: t0);
      expect(invalidated.length, equals(5));
      invalidated.clear();

      // Si vuelve a reanudarse apenas 3 segundos después, evita recarga innecesaria
      syncService.onAppResumed(
        nowOverride: t0.add(const Duration(seconds: 3)),
      );
      expect(invalidated, isEmpty);

      // Si pasaron 20 segundos (>= 15s), vuelve a sincronizar
      syncService.onAppResumed(
        nowOverride: t0.add(const Duration(seconds: 20)),
      );
      expect(invalidated.length, equals(5));
    });
  });
}
