import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';

void main() {
  group('EncryptedPayload Tests', () {
    test('serializa y deserializa preservando todos los campos', () {
      const payload = EncryptedPayload(
        cipherTextBase64: 'dGVzdF9jaXBoZXI=',
        nonceBase64: 'MTIzNDU2Nzg5MDEy',
        macBase64: 'YWJjZGVmMTIzNDU2',
      );

      final serialized = payload.serialize();
      expect(serialized, isA<String>());

      final deserialized = EncryptedPayload.deserialize(serialized);
      expect(deserialized, equals(payload));
      expect(deserialized.cipherTextBase64, equals('dGVzdF9jaXBoZXI='));
      expect(deserialized.nonceBase64, equals('MTIzNDU2Nzg5MDEy'));
      expect(deserialized.macBase64, equals('YWJjZGVmMTIzNDU2'));
    });

    test('arroja FormatException cuando el JSON está incompleto', () {
      final invalidJson = jsonEncode({'v': 1, 'ct': 'solo_ct'});
      expect(
        () => EncryptedPayload.deserialize(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('EncryptionService Tests (AES-256-GCM)', () {
    late EncryptionService encryptionService;
    late SecretKey secretKey;

    setUp(() async {
      encryptionService = EncryptionService();
      final algorithm = AesGcm.with256bits();
      secretKey = await algorithm.newSecretKey();
    });

    test('cifra y descifra una cadena de texto recuperando el original exacto', () async {
      const originalText = 'Comprar víveres y revisar notas del proyecto secreto #LifeOS';

      final payload = await encryptionService.encryptString(originalText, secretKey);

      expect(payload.cipherTextBase64, isNotEmpty);
      expect(payload.nonceBase64, isNotEmpty);
      expect(payload.macBase64, isNotEmpty);
      // El ciphertext no debe contener el texto plano
      expect(payload.cipherTextBase64, isNot(contains(originalText)));

      final decrypted = await encryptionService.decryptToString(payload, secretKey);
      expect(decrypted, equals(originalText));
    });

    test('genera nonces únicos en cada cifrado para el mismo texto plano', () async {
      const text = 'Mismo texto cifrado dos veces';

      final payload1 = await encryptionService.encryptString(text, secretKey);
      final payload2 = await encryptionService.encryptString(text, secretKey);

      // Los nonces y ciphertexts deben ser distintos para evitar fugas estadísticas
      expect(payload1.nonceBase64, isNot(equals(payload2.nonceBase64)));
      expect(payload1.cipherTextBase64, isNot(equals(payload2.cipherTextBase64)));

      // Ambos descifran correctamente al mismo valor original
      expect(await encryptionService.decryptToString(payload1, secretKey), equals(text));
      expect(await encryptionService.decryptToString(payload2, secretKey), equals(text));
    });

    test('cifra y descifra objetos JSON complejos', () async {
      final originalData = {
        'id': 'task-123',
        'title': 'Desarrollar módulo de finanzas',
        'subtasks': ['Definir DTO', 'Crear UI', 'Conectar backend'],
        'amount': 450.75,
        'isCompleted': false,
      };

      final payload = await encryptionService.encryptJson(originalData, secretKey);
      final decryptedData = await encryptionService.decryptJson(payload, secretKey);

      expect(decryptedData, equals(originalData));
    });

    test('detecta manipulación o alteración del texto cifrado (Anti-Tampering)', () async {
      const text = 'Mensaje confidencial';
      final payload = await encryptionService.encryptString(text, secretKey);

      // Modificamos un carácter del ciphertext Base64
      final tamperedCipher = payload.cipherTextBase64.startsWith('A')
          ? 'B${payload.cipherTextBase64.substring(1)}'
          : 'A${payload.cipherTextBase64.substring(1)}';

      final tamperedPayload = EncryptedPayload(
        cipherTextBase64: tamperedCipher,
        nonceBase64: payload.nonceBase64,
        macBase64: payload.macBase64,
      );

      expect(
        () async => await encryptionService.decryptToString(tamperedPayload, secretKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('falla al descifrar si se usa una clave distinta', () async {
      const text = 'Datos confidenciales protegidos';
      final payload = await encryptionService.encryptString(text, secretKey);

      final otherKey = await AesGcm.with256bits().newSecretKey();

      expect(
        () async => await encryptionService.decryptToString(payload, otherKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('KeyVaultService Tests (PBKDF2)', () {
    late KeyVaultService vault;
    final salt = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

    setUp(() {
      vault = KeyVaultService();
    });

    test('genera salt aleatorio seguro de 16 bytes', () {
      final salt1 = KeyVaultService.generateSalt();
      final salt2 = KeyVaultService.generateSalt();

      expect(salt1.length, equals(16));
      expect(salt2.length, equals(16));
      expect(salt1, isNot(equals(salt2)));
    });

    test('deriva la misma clave para la misma contraseña y salt de forma determinista', () async {
      const password = 'MiContraseñaMaestraSuperSegura2026!';

      final key1 = await vault.deriveKeyFromPassword(masterPassword: password, salt: salt);
      final key2 = await vault.deriveKeyFromPassword(masterPassword: password, salt: salt);

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1, equals(bytes2));
      expect(bytes1.length, equals(32)); // 256 bits = 32 bytes
    });

    test('deriva claves distintas si la contraseña o el salt cambian', () async {
      final key1 = await vault.deriveKeyFromPassword(masterPassword: 'passwordA', salt: salt);
      final key2 = await vault.deriveKeyFromPassword(masterPassword: 'passwordB', salt: salt);

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1, isNot(equals(bytes2)));
    });

    test('gestión de estado de la bóveda en memoria (lock/unlock)', () async {
      expect(vault.isUnlocked, isFalse);
      expect(() => vault.activeKey, throwsStateError);

      final key = await vault.deriveKeyFromPassword(masterPassword: 'pass', salt: salt);
      vault.setActiveKey(key);

      expect(vault.isUnlocked, isTrue);
      expect(vault.activeKey, equals(key));

      vault.lockVault();
      expect(vault.isUnlocked, isFalse);
      expect(() => vault.activeKey, throwsStateError);
    });

    test('Flujo E2E: Derivación -> Cifrado -> Serialización -> Deserialización -> Descifrado', () async {
      const userMasterPassword = 'UsuarioMasterPassword#2026';
      final encryption = EncryptionService();

      // 1. Derivar clave maestra
      final derivedKey = await vault.deriveKeyFromPassword(
        masterPassword: userMasterPassword,
        salt: salt,
      );

      // 2. Cifrar tarea
      final taskPayload = {
        'title': 'Comprar panel solar para asistente ESP32',
        'notes': 'Revisar voltaje de salida 5V 1A',
        'priority': 3,
      };
      final encrypted = await encryption.encryptJson(taskPayload, derivedKey);

      // 3. Simular almacenamiento en Supabase (columna encrypted_data TEXT)
      final storedStringInDb = encrypted.serialize();

      // 4. Simular recuperación desde Supabase
      final retrievedFromDb = EncryptedPayload.deserialize(storedStringInDb);

      // 5. Descifrar en el cliente con la clave derivada
      final decryptedData = await encryption.decryptJson(retrievedFromDb, derivedKey);

      expect(decryptedData['title'], equals('Comprar panel solar para asistente ESP32'));
      expect(decryptedData['priority'], equals(3));
    });
  });
}

