import 'dart:convert';

/// Representa el contenedor seguro para cualquier información cifrada en Life-OS.
/// Almacena el texto cifrado (ciphertext), el vector de inicialización (nonce)
/// y la etiqueta de autenticación (MAC) producida por AES-256-GCM.
class EncryptedPayload {
  final String cipherTextBase64;
  final String nonceBase64;
  final String macBase64;

  const EncryptedPayload({
    required this.cipherTextBase64,
    required this.nonceBase64,
    required this.macBase64,
  });

  /// Serializa el contenedor en un JSON string para guardarlo en la columna
  /// `encrypted_data` de Supabase.
  String serialize() {
    return jsonEncode(toMap());
  }

  Map<String, dynamic> toMap() {
    return {
      'v': 1, // Versión del esquema criptográfico
      'ct': cipherTextBase64,
      'iv': nonceBase64,
      'mac': macBase64,
    };
  }

  /// Deserializa desde el string guardado en la base de datos.
  factory EncryptedPayload.deserialize(String serialized) {
    final Map<String, dynamic> map = jsonDecode(serialized);
    return EncryptedPayload.fromMap(map);
  }

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('ct') || !map.containsKey('iv') || !map.containsKey('mac')) {
      throw const FormatException('Payload cifrado inválido o corrupto');
    }
    return EncryptedPayload(
      cipherTextBase64: map['ct'] as String,
      nonceBase64: map['iv'] as String,
      macBase64: map['mac'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncryptedPayload &&
          runtimeType == other.runtimeType &&
          cipherTextBase64 == other.cipherTextBase64 &&
          nonceBase64 == other.nonceBase64 &&
          macBase64 == other.macBase64;

  @override
  int get hashCode =>
      cipherTextBase64.hashCode ^ nonceBase64.hashCode ^ macBase64.hashCode;
}

