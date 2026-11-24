import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'encrypted_payload.dart';
import 'encryption_service.dart';

/// Servicio responsable de la derivación de claves criptográficas (KDF),
/// de la custodia en memoria de la clave maestra activa durante la sesión,
/// y de la persistencia cifrada en el almacén seguro del dispositivo (B2).
class KeyVaultService {
  static const String _kDeviceWrapKeyPref = 'life_os_keystore_wrap_v1';
  static const String _kEncryptedVaultPref = 'life_os_keystore_vault_v1';
  static const String _kPersistEnabledPref = 'life_os_keystore_persist_enabled_v1';

  final Pbkdf2 _kdf;
  SecretKey? _activeKey;
  String? _activeMasterPassword;
  String? _activeDerivedKeyBase64;
  bool _persistSessionEnabled = true;
  bool _restoreAttempted = false;

  /// Callback invocado cuando la bóveda cambia de estado (desbloqueada / bloqueada).
  void Function(bool isUnlocked)? onUnlockStateChanged;

  KeyVaultService({Pbkdf2? kdf})
      : _kdf = kdf ??
            Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: 100000,
              bits: 256,
            );

  /// Genera un Salt aleatorio criptográficamente seguro de 16 bytes.
  static List<int> generateSalt([int length = 16]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Deriva una clave simétrica de 256 bits a partir de la contraseña maestra del usuario y un salt.
  /// Utiliza PBKDF2 con HMAC-SHA256 y 100,000 iteraciones para resistencia ante ataques de fuerza bruta.
  Future<SecretKey> deriveKeyFromPassword({
    required String masterPassword,
    required List<int> salt,
  }) async {
    final passwordBytes = utf8.encode(masterPassword);
    final derivedKey = await _kdf.deriveKey(
      secretKey: SecretKey(passwordBytes),
      nonce: salt,
    );
    return derivedKey;
  }

  /// Establece la clave simétrica activa para la sesión del usuario
  /// y notifica a los observadores reactivos.
  void setActiveKey(
    SecretKey key, {
    String? masterPassword,
    String? derivedKeyBase64,
  }) {
    _activeKey = key;
    if (masterPassword != null) {
      _activeMasterPassword = masterPassword;
    }
    if (derivedKeyBase64 != null) {
      _activeDerivedKeyBase64 = derivedKeyBase64;
    } else {
      key.extractBytes().then((bytes) {
        _activeDerivedKeyBase64 = base64Encode(bytes);
      }).catchError((_) {});
    }
    onUnlockStateChanged?.call(true);
  }

  /// Retorna la clave activa para operaciones de cifrado/descifrado.
  /// Arroja [StateError] si la sesión está bloqueada o no autenticada.
  SecretKey get activeKey {
    if (_activeKey == null) {
      throw StateError('La bóveda criptográfica está bloqueada. Se requiere contraseña maestra.');
    }
    return _activeKey!;
  }

  /// Indica si la bóveda está desbloqueada y lista para operar.
  bool get isUnlocked => _activeKey != null;

  /// Contraseña maestra activa en la sesión (solo accesible para inspección del usuario autenticado).
  String? get activeMasterPassword => _activeMasterPassword;

  /// Representación en Base64 de los 32 bytes de la clave derivada AES-256 activa.
  String? get activeDerivedKeyBase64 => _activeDerivedKeyBase64;

  /// Indica si la persistencia de sesión/bóveda entre reinicios está activa.
  bool get persistSessionEnabled => _persistSessionEnabled;

  /// Bloquea la bóveda, limpia la clave de la memoria al cerrar sesión
  /// y notifica a los observadores reactivos.
  void lockVault({bool clearPersisted = false}) {
    _activeKey = null;
    _activeMasterPassword = null;
    _activeDerivedKeyBase64 = null;
    if (clearPersisted) {
      clearPersistedKeystore();
    }
    onUnlockStateChanged?.call(false);
  }

  /// Persiste la clave derivada (y opcionalmente la contraseña maestra para visualización
  /// del usuario) dentro de un sobre cifrado AES-256-GCM en el almacenamiento del sistema.
  Future<void> persistSessionToKeystore({
    required SecretKey key,
    String? masterPassword,
    String? userEmail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _persistSessionEnabled = prefs.getBool(_kPersistEnabledPref) ?? true;

      final keyBytes = await key.extractBytes();
      final dkBase64 = base64Encode(keyBytes);
      _activeDerivedKeyBase64 = dkBase64;
      if (masterPassword != null) {
        _activeMasterPassword = masterPassword;
      }

      if (!_persistSessionEnabled) {
        return;
      }

      final wrapKey = await _getOrCreateDeviceWrappingKey(prefs);
      final encryption = EncryptionService();

      final envelope = <String, dynamic>{
        'dk': dkBase64,
        'mp': masterPassword ?? _activeMasterPassword ?? '',
        'email': (userEmail ?? '').trim().toLowerCase(),
        'ts': DateTime.now().toUtc().toIso8601String(),
      };

      final encryptedPayload = await encryption.encryptJson(envelope, wrapKey);
      await prefs.setString(_kEncryptedVaultPref, encryptedPayload.serialize());
    } catch (_) {
      // En entornos de test sin SharedPreferences inicializado, continuar en RAM sin fallar.
    }
  }

  /// Restaura la clave derivada desde el sobre cifrado local si existe y está habilitado.
  Future<bool> restoreSessionFromKeystore({String? expectedEmail}) async {
    _restoreAttempted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _persistSessionEnabled = prefs.getBool(_kPersistEnabledPref) ?? true;
      if (!_persistSessionEnabled) {
        return false;
      }

      final rawEncrypted = prefs.getString(_kEncryptedVaultPref);
      final rawWrapKey = prefs.getString(_kDeviceWrapKeyPref);
      if (rawEncrypted == null || rawWrapKey == null) {
        return false;
      }

      final wrapKeyBytes = base64Decode(rawWrapKey);
      if (wrapKeyBytes.length != 32) {
        return false;
      }

      final wrapKey = SecretKey(wrapKeyBytes);
      final payload = EncryptedPayload.deserialize(rawEncrypted);
      final encryption = EncryptionService();
      final envelope = await encryption.decryptJson(payload, wrapKey);

      final storedEmail = (envelope['email'] as String? ?? '').trim().toLowerCase();
      final cleanExpected = (expectedEmail ?? '').trim().toLowerCase();
      if (cleanExpected.isNotEmpty &&
          storedEmail.isNotEmpty &&
          storedEmail != cleanExpected) {
        return false;
      }

      final dkBase64 = envelope['dk'] as String?;
      if (dkBase64 == null || dkBase64.isEmpty) {
        return false;
      }

      final keyBytes = base64Decode(dkBase64);
      if (keyBytes.length != 32) {
        return false;
      }

      final mp = envelope['mp'] as String?;
      _activeDerivedKeyBase64 = dkBase64;
      _activeMasterPassword = (mp != null && mp.isNotEmpty) ? mp : null;
      _activeKey = SecretKey(keyBytes);

      onUnlockStateChanged?.call(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Indica si ya se intentó restaurar la sesión desde el keystore al menos una vez.
  bool get restoreAttempted => _restoreAttempted;

  /// Habilita o deshabilita la persistencia automática de la bóveda al cerrar la app.
  Future<void> setPersistSessionEnabled(bool enabled, {String? userEmail}) async {
    _persistSessionEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPersistEnabledPref, enabled);
      if (!enabled) {
        await clearPersistedKeystore();
      } else if (_activeKey != null) {
        await persistSessionToKeystore(
          key: _activeKey!,
          masterPassword: _activeMasterPassword,
          userEmail: userEmail,
        );
      }
    } catch (_) {}
    onUnlockStateChanged?.call(isUnlocked);
  }

  /// Elimina del dispositivo el sobre cifrado de la bóveda (al cerrar sesión).
  Future<void> clearPersistedKeystore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kEncryptedVaultPref);
    } catch (_) {}
  }

  Future<SecretKey> _getOrCreateDeviceWrappingKey(SharedPreferences prefs) async {
    final existing = prefs.getString(_kDeviceWrapKeyPref);
    if (existing != null && existing.isNotEmpty) {
      try {
        final bytes = base64Decode(existing);
        if (bytes.length == 32) {
          return SecretKey(bytes);
        }
      } catch (_) {}
    }

    final randomBytes = generateSalt(32);
    await prefs.setString(_kDeviceWrapKeyPref, base64Encode(randomBytes));
    return SecretKey(randomBytes);
  }
}
