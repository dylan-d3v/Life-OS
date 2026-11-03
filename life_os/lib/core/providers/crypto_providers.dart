import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/crypto.dart';

/// Proveedor para el servicio de cifrado simétrico AES-256-GCM.
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

/// Notificador de Riverpod para la bóveda criptográfica.
/// Invalida y notifica reactivamente a los observadores cuando la clave activa cambia.
class KeyVaultNotifier extends Notifier<KeyVaultService> {
  late final KeyVaultService _vault = KeyVaultService();

  @override
  KeyVaultService build() {
    _vault.onUnlockStateChanged = (_) {
      ref.invalidateSelf();
    };
    return _vault;
  }
}

/// Proveedor reactivo para el servicio de gestión de bóveda y derivación de clave maestra.
final keyVaultServiceProvider =
    NotifierProvider<KeyVaultNotifier, KeyVaultService>(KeyVaultNotifier.new);

