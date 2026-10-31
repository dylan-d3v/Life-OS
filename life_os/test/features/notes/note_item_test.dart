import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/features/notes/domain/note_item.dart';

void main() {
  group('NoteItem Domain Tests', () {
    test('toEncryptedFieldsMap extrae título, contenido y etiquetas confidenciales', () {
      final note = NoteItem(
        id: 'note-1',
        title: 'Idea de startup',
        content: 'Plataforma descentralizada de micro-credenciales',
        tags: const ['startup', 'crypto', 'ideas'],
        isPinned: true,
        createdAt: DateTime.parse('2026-10-30T12:00:00Z'),
        updatedAt: DateTime.parse('2026-10-30T12:00:00Z'),
      );

      final sensitive = note.toEncryptedFieldsMap();

      expect(sensitive, {
        'title': 'Idea de startup',
        'content': 'Plataforma descentralizada de micro-credenciales',
        'tags': ['startup', 'crypto', 'ideas'],
      });
      expect(sensitive.containsKey('id'), isFalse);
      expect(sensitive.containsKey('is_pinned'), isFalse);
    });

    test('fromDecryptedMap reconstruye la nota preservando tipos y etiquetas', () {
      final row = {
        'id': 'note-abc-999',
        'project_id': 'proj-123',
        'is_pinned': true,
        'created_at': '2026-10-30T09:00:00Z',
        'updated_at': '2026-10-30T10:30:00Z',
        'deleted_at': null,
      };

      final decryptedFields = {
        'title': 'Notas de reunión confidencial',
        'content': 'Discusión sobre arquitectura E2EE con ESP32',
        'tags': ['hardware', 'esp32', 'e2ee'],
      };

      final note = NoteItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      );

      expect(note.id, 'note-abc-999');
      expect(note.projectId, 'proj-123');
      expect(note.isPinned, isTrue);
      expect(note.title, 'Notas de reunión confidencial');
      expect(note.content, 'Discusión sobre arquitectura E2EE con ESP32');
      expect(note.tags, ['hardware', 'esp32', 'e2ee']);
    });

    test('Flujo E2EE completo de Nota: Cifrado -> Serialización -> Deserialización -> Descifrado', () async {
      final encryptionService = EncryptionService();
      final vault = KeyVaultService();
      final salt = KeyVaultService.generateSalt();
      final key = await vault.deriveKeyFromPassword(
        masterPassword: 'MasterPasswordSuperSegura2026!',
        salt: salt,
      );

      final originalNote = NoteItem(
        id: 'uuid-nota-segura',
        title: 'Contraseña y accesos de emergencia',
        content: 'Seed phrase: apple banana cherry date eagle frog',
        tags: const ['seguridad', 'vault'],
        isPinned: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Cifrar
      final sensitiveFields = originalNote.toEncryptedFieldsMap();
      final encryptedPayload = await encryptionService.encryptJson(sensitiveFields, key);
      final serializedPayload = encryptedPayload.serialize();

      // 2. Comprobar que en el payload de Supabase no hay texto plano
      expect(serializedPayload.contains('Contraseña y accesos'), isFalse);
      expect(serializedPayload.contains('Seed phrase'), isFalse);
      expect(serializedPayload.contains('banana'), isFalse);

      // 3. Deserializar y descifrar
      final deserialized = EncryptedPayload.deserialize(serializedPayload);
      final decrypted = await encryptionService.decryptJson(deserialized, key);

      // 4. Reconstruir
      final reconstructed = NoteItem.fromDecryptedMap(
        row: {
          'id': originalNote.id,
          'is_pinned': originalNote.isPinned,
          'created_at': originalNote.createdAt.toIso8601String(),
          'updated_at': originalNote.updatedAt.toIso8601String(),
        },
        decryptedFields: decrypted,
      );

      expect(reconstructed.id, originalNote.id);
      expect(reconstructed.title, originalNote.title);
      expect(reconstructed.content, originalNote.content);
      expect(reconstructed.tags, originalNote.tags);
      expect(reconstructed.isPinned, isTrue);
    });
  });
}

