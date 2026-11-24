import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/backup/backup_service.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/features/calendar/domain/calendar_event_item.dart';
import 'package:life_os/features/finance/domain/finance_transaction_item.dart';
import 'package:life_os/features/notes/domain/note_item.dart';
import 'package:life_os/features/projects/domain/project_item.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';

void main() {
  group('BackupService Tests (Fase 4 - G1)', () {
    late KeyVaultService vault;
    late EncryptionService encryptionService;
    late BackupService backupService;
    late LifeOsBackupBundle sampleBundle;

    setUp(() async {
      vault = KeyVaultService();
      encryptionService = EncryptionService();
      final key = await vault.deriveKeyFromPassword(
        masterPassword: 'MasterBackupKey#2026',
        salt: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      );
      vault.setActiveKey(key, masterPassword: 'MasterBackupKey#2026');

      backupService = BackupService(
        client: null,
        encryptionService: encryptionService,
        vault: vault,
      );

      final now = DateTime.utc(2026, 11, 24, 12, 0);
      sampleBundle = LifeOsBackupBundle(
        projects: [
          ProjectItem(
            id: 'proj-1',
            name: 'Satélite ESP32',
            description: 'Asistente de voz hardware',
            colorHex: '#10B981',
            status: ProjectStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tasks: [
          TaskItem(
            id: 'task-1',
            projectId: 'proj-1',
            title: 'Soldar micrófono INMP441',
            notes: 'Pin L/R a GND',
            priority: 4,
            status: TaskStatus.todo,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        notes: [
          NoteItem(
            id: 'note-1',
            projectId: 'proj-1',
            title: 'Pinout I2S',
            content: 'SCK=14, WS=15, SD=32',
            tags: const ['hardware', 'esp32'],
            isPinned: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        calendarEvents: [
          CalendarEventItem(
            id: 'evt-1',
            title: 'Demo Life-OS',
            description: 'Presentación móvil y desktop',
            location: 'Sala 1',
            category: 'Trabajo',
            startTime: now,
            endTime: now.add(const Duration(hours: 1)),
            createdAt: now,
            updatedAt: now,
          ),
        ],
        financeTransactions: [
          FinanceTransactionItem(
            id: 'fin-1',
            type: TransactionType.expense,
            amount: 15.50,
            currency: 'USD',
            category: 'Hardware',
            notes: 'Componentes electrónicos',
            transactionDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });

    test(
        'exporta respaldo cifrado con AES-256-GCM y lo restaura validando integridad SHA-256',
        () async {
      final exportedJson = await backupService.exportBackupToJson(
        bundle: sampleBundle,
        encrypt: true,
        customPassword: 'ClaveMigracionCuenta2026',
      );

      // El JSON cifrado no debe exponer ningún título en texto plano
      expect(exportedJson, isNot(contains('Soldar micrófono INMP441')));
      expect(exportedJson, isNot(contains('Pinout I2S')));

      // Si intentamos restaurar con una contraseña incorrecta, falla con SecretBoxAuthenticationError
      expect(
        () => backupService.validateAndParseBackup(
          rawJson: exportedJson,
          customPassword: 'ClaveIncorrecta',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      // Con la contraseña correcta, restaura las 5 colecciones intactas
      final restored = await backupService.validateAndParseBackup(
        rawJson: exportedJson,
        customPassword: 'ClaveMigracionCuenta2026',
      );

      expect(restored.totalRecords, equals(5));
      expect(restored.projects.first.name, equals('Satélite ESP32'));
      expect(restored.tasks.first.title, equals('Soldar micrófono INMP441'));
      expect(restored.tasks.first.projectId, equals('proj-1'));
      expect(restored.notes.first.tags, contains('esp32'));
      expect(restored.calendarEvents.first.title, equals('Demo Life-OS'));
      expect(restored.financeTransactions.first.amount, equals(15.50));
    });

    test('detecta manipulación del checksum SHA-256 antes de importar', () async {
      final exportedJson = await backupService.exportBackupToJson(
        bundle: sampleBundle,
        encrypt: false,
      );

      final tamperedMap =
          jsonDecode(exportedJson) as Map<String, dynamic>;
      tamperedMap['checksum_sha256'] =
          '0000000000000000000000000000000000000000000000000000000000000000';

      expect(
        () => backupService.validateAndParseBackup(
          rawJson: jsonEncode(tamperedMap),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'mergeBundlesWithoutDuplicates actualiza registros con el mismo UUID sin duplicarlos',
        () {
      final now = DateTime.utc(2026, 11, 24, 15, 0);
      final incomingBundle = LifeOsBackupBundle(
        tasks: [
          // Mismo ID 'task-1' pero con estado completado
          sampleBundle.tasks.first.copyWith(
            title: 'Soldar micrófono INMP441 (Completado)',
            status: TaskStatus.done,
          ),
          // Nueva tarea 'task-2'
          TaskItem(
            id: 'task-2',
            title: 'Probar altavoz MAX98357A',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final result = backupService.mergeBundlesWithoutDuplicates(
        existing: sampleBundle,
        incoming: incomingBundle,
      );

      expect(result.mergedBundle.tasks.length, equals(2));
      expect(result.summary.updatedExistingCount, equals(1));
      expect(
        result.mergedBundle.tasks
            .firstWhere((t) => t.id == 'task-1')
            .title,
        equals('Soldar micrófono INMP441 (Completado)'),
      );
    });
  });
}
