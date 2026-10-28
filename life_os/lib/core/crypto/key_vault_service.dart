import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Servicio responsable de la derivación de claves criptográficas (KDF)
/// y de la custodia en memoria de la clave maestra activa durante la sesión.
class KeyVaultService {
  final Pbkdf2 _kdf;
  SecretKey? _activeKey;

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

  /// Establece la clave simétrica activa para la sesión del usuario.
  void setActiveKey(SecretKey key) {
    _activeKey = key;
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

  /// Bloquea la bóveda y limpia la clave de la memoria al cerrar sesión.
  void lockVault() {
    _activeKey = null;
  }
}

