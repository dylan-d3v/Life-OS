import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'encrypted_payload.dart';

/// Servicio responsable de cifrar y descifrar información utilizando
/// el estándar simétrico autenticado AES-256-GCM.
class EncryptionService {
  final AesGcm _algorithm;

  EncryptionService({AesGcm? algorithm})
      : _algorithm = algorithm ?? AesGcm.with256bits();

  /// Cifra un texto en claro generando un nonce criptográficamente seguro
  /// y una etiqueta de autenticación (MAC) que protege contra modificaciones.
  Future<EncryptedPayload> encryptString(
    String plainText,
    SecretKey secretKey,
  ) async {
    final clearBytes = utf8.encode(plainText);
    final secretBox = await _algorithm.encrypt(
      clearBytes,
      secretKey: secretKey,
    );

    return EncryptedPayload(
      cipherTextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      macBase64: base64Encode(secretBox.mac.bytes),
    );
  }

  /// Descifra un [EncryptedPayload] y valida la autenticidad del contenido.
  /// Si el ciphertext, el nonce o el mac han sido alterados, arroja [SecretBoxAuthenticationError].
  Future<String> decryptToString(
    EncryptedPayload payload,
    SecretKey secretKey,
  ) async {
    final cipherText = base64Decode(payload.cipherTextBase64);
    final nonce = base64Decode(payload.nonceBase64);
    final macBytes = base64Decode(payload.macBase64);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(clearBytes);
  }

  /// Cifra un mapa estructurado de Dart a JSON encriptado.
  Future<EncryptedPayload> encryptJson(
    Map<String, dynamic> jsonMap,
    SecretKey secretKey,
  ) async {
    final jsonString = jsonEncode(jsonMap);
    return encryptString(jsonString, secretKey);
  }

  /// Descifra un [EncryptedPayload] directamente a un mapa JSON de Dart.
  Future<Map<String, dynamic>> decryptJson(
    EncryptedPayload payload,
    SecretKey secretKey,
  ) async {
    final jsonString = await decryptToString(payload, secretKey);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }
}

