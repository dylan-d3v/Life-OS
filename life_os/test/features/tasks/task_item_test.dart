import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';

void main() {
  group('TaskItem Domain Tests', () {
    test('toEncryptedFieldsMap extrae únicamente los campos sensibles', () {
      final task = TaskItem(
        id: 'task-123',
        projectId: 'proj-456',
        title: 'Estudiar para el examen de cálculo',
        notes: 'Capítulos 3 y 4 del libro',
        status: TaskStatus.todo,
        priority: 3,
        dueDate: DateTime.parse('2026-11-01T10:00:00Z'),
        createdAt: DateTime.parse('2026-10-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-10-30T10:00:00Z'),
      );

      final sensitiveMap = task.toEncryptedFieldsMap();

      expect(sensitiveMap, {
        'title': 'Estudiar para el examen de cálculo',
        'notes': 'Capítulos 3 y 4 del libro',
      });
      // Asegurarse de que no incluya metadatos
      expect(sensitiveMap.containsKey('id'), isFalse);
      expect(sensitiveMap.containsKey('status'), isFalse);
      expect(sensitiveMap.containsKey('priority'), isFalse);
    });

    test('fromDecryptedMap reconstruye el TaskItem combinando metadatos y campos descifrados', () {
      final row = {
        'id': 'task-abc',
        'project_id': 'proj-xyz',
        'status': 'in_progress',
        'priority': 4,
        'due_date': '2026-11-15T18:00:00Z',
        'created_at': '2026-10-25T08:00:00Z',
        'updated_at': '2026-10-28T12:00:00Z',
        'deleted_at': null,
      };

      final decryptedFields = {
        'title': 'Comprar sensores de pulso para el ESP32',
        'notes': 'Revisar modelo MAX30102',
      };

      final task = TaskItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      );

      expect(task.id, 'task-abc');
      expect(task.projectId, 'proj-xyz');
      expect(task.title, 'Comprar sensores de pulso para el ESP32');
      expect(task.notes, 'Revisar modelo MAX30102');
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, 4);
      expect(task.dueDate, DateTime.parse('2026-11-15T18:00:00Z'));
      expect(task.deletedAt, isNull);
    });

    test('TaskStatus.fromString mapea correctamente valores válidos y por defecto', () {
      expect(TaskStatus.fromString('todo'), TaskStatus.todo);
      expect(TaskStatus.fromString('in_progress'), TaskStatus.inProgress);
      expect(TaskStatus.fromString('done'), TaskStatus.done);
      expect(TaskStatus.fromString('cancelled'), TaskStatus.cancelled);
      expect(TaskStatus.fromString('valor_desconocido'), TaskStatus.todo);
    });

    test('copyWith clona y modifica los atributos especificados', () {
      final original = TaskItem(
        id: '1',
        title: 'Original',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = original.copyWith(
        title: 'Modificado',
        status: TaskStatus.done,
        priority: 4,
      );

      expect(updated.id, '1');
      expect(updated.title, 'Modificado');
      expect(updated.status, TaskStatus.done);
      expect(updated.priority, 4);
    });

    test('Flujo E2EE completo de tarea: Cifrado -> Serialización -> Deserialización -> Descifrado', () async {
      final encryptionService = EncryptionService();
      final vault = KeyVaultService();
      final salt = KeyVaultService.generateSalt();
      final key = await vault.deriveKeyFromPassword(
        masterPassword: 'MasterPasswordSuperSegura2026!',
        salt: salt,
      );

      final originalTask = TaskItem(
        id: 'uuid-tarea-segura',
        title: 'Revisión médica confidencial',
        notes: 'Resultados de análisis de sangre en ayunas',
        status: TaskStatus.todo,
        priority: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Cifrar campos sensibles
      final sensitiveFields = originalTask.toEncryptedFieldsMap();
      final encryptedPayload = await encryptionService.encryptJson(sensitiveFields, key);
      final serializedPayload = encryptedPayload.serialize();

      // 2. Simular persistencia en BD: el payload guardado en Supabase no contiene texto legible
      expect(serializedPayload.contains('Revisión médica'), isFalse);
      expect(serializedPayload.contains('análisis de sangre'), isFalse);

      // 3. Simular lectura desde BD y descifrado
      final deserializedPayload = EncryptedPayload.deserialize(serializedPayload);
      final decryptedFields = await encryptionService.decryptJson(deserializedPayload, key);

      // 4. Reconstruir TaskItem
      final reconstructed = TaskItem.fromDecryptedMap(
        row: {
          'id': originalTask.id,
          'status': originalTask.status.value,
          'priority': originalTask.priority,
          'created_at': originalTask.createdAt.toIso8601String(),
          'updated_at': originalTask.updatedAt.toIso8601String(),
        },
        decryptedFields: decryptedFields,
      );

      expect(reconstructed.id, originalTask.id);
      expect(reconstructed.title, originalTask.title);
      expect(reconstructed.notes, originalTask.notes);
      expect(reconstructed.priority, originalTask.priority);
    });
  });
}

