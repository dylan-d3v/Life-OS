import 'dart:convert';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto.dart';

/// Repositorio encargado de la autenticación con Supabase y
/// del desbloqueo simultáneo de la bóveda criptográfica local E2EE.
class AuthRepository {
  final SupabaseClient? client;
  final KeyVaultService vault;

  AuthRepository({
    this.client,
    required this.vault,
  });

  User? get currentUser => client?.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      client?.auth.onAuthStateChange ?? const Stream.empty();

  bool get isVaultUnlocked => vault.isUnlocked;

  /// Genera un Salt determinista de 16 bytes a partir del email del usuario
  /// garantizando que la misma clave pueda derivarse en cualquier cliente (Windows, ESP32, móvil).
  Future<List<int>> _generateUserSalt(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final digest = await crypto.Sha256().hash(utf8.encode('life_os_salt_$cleanEmail'));
    return digest.bytes.sublist(0, 16);
  }

  /// Inicia sesión en Supabase y desbloquea la bóveda criptográfica con la clave maestra.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
    required String masterKeyPassword,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('El cliente de Supabase no está inicializado.');
    }

    final response = await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    // Derivar y activar la clave simétrica en memoria
    final salt = await _generateUserSalt(email);
    final derivedKey = await vault.deriveKeyFromPassword(
      masterPassword: masterKeyPassword,
      salt: salt,
    );
    vault.setActiveKey(derivedKey);

    return response;
  }

  /// Registra un nuevo usuario en Supabase y desbloquea la bóveda con su clave maestra.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String masterKeyPassword,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('El cliente de Supabase no está inicializado.');
    }

    final response = await supabase.auth.signUp(
      email: email.trim(),
      password: password,
    );

    // Derivar y activar la clave simétrica para el nuevo usuario
    final salt = await _generateUserSalt(email);
    final derivedKey = await vault.deriveKeyFromPassword(
      masterPassword: masterKeyPassword,
      salt: salt,
    );
    vault.setActiveKey(derivedKey);

    return response;
  }

  /// Desbloquea la bóveda local si el usuario ya tiene sesión activa en Supabase.
  Future<void> unlockVault({
    required String email,
    required String masterKeyPassword,
  }) async {
    final salt = await _generateUserSalt(email);
    final derivedKey = await vault.deriveKeyFromPassword(
      masterPassword: masterKeyPassword,
      salt: salt,
    );
    vault.setActiveKey(derivedKey);
  }

  /// Cierra sesión en Supabase y destruye la clave de memoria en la bóveda.
  Future<void> signOut() async {
    vault.lockVault();
    await client?.auth.signOut();
  }
}
