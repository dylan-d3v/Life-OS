import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/crypto.dart';

/// Proveedor para el servicio de cifrado simétrico AES-256-GCM.
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

/// Proveedor para el servicio de gestión de bóveda y derivación de clave maestra.
final keyVaultServiceProvider = Provider<KeyVaultService>((ref) {
  return KeyVaultService();
});

