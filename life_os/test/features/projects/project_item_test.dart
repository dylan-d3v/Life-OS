import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/features/projects/domain/project_item.dart';

void main() {
  group('ProjectItem Domain Tests', () {
    test('toEncryptedFieldsMap extrae únicamente los campos sensibles', () {
      final project = ProjectItem(
        id: 'proj-1',
        name: 'Construcción Hardware Life-OS',
        description: 'Ensamblaje del dispositivo de bolsillo con ESP32 y sensores',
        colorHex: '#10B981',
        status: ProjectStatus.active,
        createdAt: DateTime.parse('2026-10-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-10-30T10:00:00Z'),
      );

      final sensitive = project.toEncryptedFieldsMap();

      expect(sensitive, {
        'name': 'Construcción Hardware Life-OS',
        'description': 'Ensamblaje del dispositivo de bolsillo con ESP32 y sensores',
        'color_hex': '#10B981',
      });
      expect(sensitive.containsKey('id'), isFalse);
      expect(sensitive.containsKey('status'), isFalse);
    });

    test('fromDecryptedMap reconstruye el ProjectItem correctamente', () {
      final row = {
        'id': 'proj-uuid-999',
        'status': 'paused',
        'created_at': '2026-10-20T12:00:00Z',
        'updated_at': '2026-10-25T15:00:00Z',
        'deleted_at': null,
      };

      final decryptedFields = {
        'name': 'Plan de Ahorro e Inversión',
        'description': 'Fondo de emergencia y aportes mensuales',
        'color_hex': '#F59E0B',
      };

      final project = ProjectItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      );

      expect(project.id, 'proj-uuid-999');
      expect(project.name, 'Plan de Ahorro e Inversión');
      expect(project.description, 'Fondo de emergencia y aportes mensuales');
      expect(project.colorHex, '#F59E0B');
      expect(project.status, ProjectStatus.paused);
      expect(project.deletedAt, isNull);
    });

    test('ProjectStatus.fromString mapea estados válidos y fallback', () {
      expect(ProjectStatus.fromString('active'), ProjectStatus.active);
      expect(ProjectStatus.fromString('paused'), ProjectStatus.paused);
      expect(ProjectStatus.fromString('completed'), ProjectStatus.completed);
      expect(ProjectStatus.fromString('archived'), ProjectStatus.archived);
      expect(ProjectStatus.fromString('desconocido'), ProjectStatus.active);
    });

    test('Flujo E2EE completo de Proyecto: Cifrado -> Serialización -> Deserialización -> Descifrado', () async {
      final encryptionService = EncryptionService();
      final vault = KeyVaultService();
      final salt = KeyVaultService.generateSalt();
      final key = await vault.deriveKeyFromPassword(
        masterPassword: 'MasterPasswordSuperSegura2026!',
        salt: salt,
      );

      final originalProject = ProjectItem(
        id: 'proj-seguro-001',
        name: 'Iniciativa Confidencial AI Kev/Jev',
        description: 'Orquestación de LLM en la nube y sincronización con ESP32',
        colorHex: '#8B5CF6',
        status: ProjectStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Cifrar
      final sensitiveFields = originalProject.toEncryptedFieldsMap();
      final encryptedPayload = await encryptionService.encryptJson(sensitiveFields, key);
      final serializedPayload = encryptedPayload.serialize();

      // 2. Comprobar que en el payload de Supabase no hay texto legible
      expect(serializedPayload.contains('Iniciativa Confidencial'), isFalse);
      expect(serializedPayload.contains('Kev/Jev'), isFalse);
      expect(serializedPayload.contains('Orquestación'), isFalse);

      // 3. Deserializar y descifrar
      final deserialized = EncryptedPayload.deserialize(serializedPayload);
      final decrypted = await encryptionService.decryptJson(deserialized, key);

      // 4. Reconstruir
      final reconstructed = ProjectItem.fromDecryptedMap(
        row: {
          'id': originalProject.id,
          'status': originalProject.status.value,
          'created_at': originalProject.createdAt.toIso8601String(),
          'updated_at': originalProject.updatedAt.toIso8601String(),
        },
        decryptedFields: decrypted,
      );

      expect(reconstructed.id, originalProject.id);
      expect(reconstructed.name, originalProject.name);
      expect(reconstructed.description, originalProject.description);
      expect(reconstructed.colorHex, originalProject.colorHex);
      expect(reconstructed.status, ProjectStatus.active);
    });
  });
}

