import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/features/calendar/domain/calendar_event_item.dart';

void main() {
  group('CalendarEventItem Domain Tests', () {
    test('toEncryptedFieldsMap extrae únicamente los campos confidenciales', () {
      final event = CalendarEventItem(
        id: 'event-1',
        startTime: DateTime.parse('2026-11-01T14:00:00Z'),
        endTime: DateTime.parse('2026-11-01T15:30:00Z'),
        isAllDay: false,
        title: 'Reunión médica privada',
        description: 'Chequeo general y entrega de resultados',
        location: 'Hospital Metropolitano, Consultorio 402',
        createdAt: DateTime.parse('2026-10-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-10-30T10:00:00Z'),
      );

      final sensitive = event.toEncryptedFieldsMap();

      expect(sensitive, {
        'title': 'Reunión médica privada',
        'description': 'Chequeo general y entrega de resultados',
        'location': 'Hospital Metropolitano, Consultorio 402',
      });
      expect(sensitive.containsKey('id'), isFalse);
      expect(sensitive.containsKey('start_time'), isFalse);
      expect(sensitive.containsKey('end_time'), isFalse);
      expect(sensitive.containsKey('is_all_day'), isFalse);
    });

    test('fromDecryptedMap reconstruye el CalendarEventItem fielmente', () {
      final row = {
        'id': 'cal-uuid-777',
        'start_time': '2026-11-10T09:00:00Z',
        'end_time': '2026-11-10T18:00:00Z',
        'is_all_day': true,
        'created_at': '2026-10-28T08:00:00Z',
        'updated_at': '2026-10-29T10:00:00Z',
        'deleted_at': null,
      };

      final decryptedFields = {
        'title': 'Hackathon Life-OS ESP32',
        'description': 'Jornada de integración de hardware y firmware',
        'location': 'Laboratorio de Innovación',
      };

      final event = CalendarEventItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      );

      expect(event.id, 'cal-uuid-777');
      expect(event.startTime, DateTime.parse('2026-11-10T09:00:00Z'));
      expect(event.endTime, DateTime.parse('2026-11-10T18:00:00Z'));
      expect(event.isAllDay, isTrue);
      expect(event.title, 'Hackathon Life-OS ESP32');
      expect(event.description, 'Jornada de integración de hardware y firmware');
      expect(event.location, 'Laboratorio de Innovación');
      expect(event.deletedAt, isNull);
    });

    test('Flujo E2EE completo de Evento: Cifrado -> Serialización -> Deserialización -> Descifrado', () async {
      final encryptionService = EncryptionService();
      final vault = KeyVaultService();
      final salt = KeyVaultService.generateSalt();
      final key = await vault.deriveKeyFromPassword(
        masterPassword: 'MasterPasswordSuperSegura2026!',
        salt: salt,
      );

      final originalEvent = CalendarEventItem(
        id: 'cal-secure-001',
        startTime: DateTime.now().add(const Duration(days: 2)),
        endTime: DateTime.now().add(const Duration(days: 2, hours: 2)),
        isAllDay: false,
        title: 'Cita con asesor financiero confidencial',
        description: 'Revisión de patrimonio neto y planificación fiscal',
        location: 'Sucursal Bancaria Privada',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Cifrar
      final sensitiveFields = originalEvent.toEncryptedFieldsMap();
      final encryptedPayload = await encryptionService.encryptJson(sensitiveFields, key);
      final serializedPayload = encryptedPayload.serialize();

      // 2. Comprobar que en el payload de Supabase no hay texto legible
      expect(serializedPayload.contains('asesor financiero'), isFalse);
      expect(serializedPayload.contains('planificación fiscal'), isFalse);
      expect(serializedPayload.contains('Sucursal Bancaria'), isFalse);

      // 3. Deserializar y descifrar
      final deserialized = EncryptedPayload.deserialize(serializedPayload);
      final decrypted = await encryptionService.decryptJson(deserialized, key);

      // 4. Reconstruir
      final reconstructed = CalendarEventItem.fromDecryptedMap(
        row: {
          'id': originalEvent.id,
          'start_time': originalEvent.startTime.toIso8601String(),
          'end_time': originalEvent.endTime.toIso8601String(),
          'is_all_day': originalEvent.isAllDay,
          'created_at': originalEvent.createdAt.toIso8601String(),
          'updated_at': originalEvent.updatedAt.toIso8601String(),
        },
        decryptedFields: decrypted,
      );

      expect(reconstructed.id, originalEvent.id);
      expect(reconstructed.title, originalEvent.title);
      expect(reconstructed.description, originalEvent.description);
      expect(reconstructed.location, originalEvent.location);
      expect(reconstructed.isAllDay, originalEvent.isAllDay);
    });
  });
}

