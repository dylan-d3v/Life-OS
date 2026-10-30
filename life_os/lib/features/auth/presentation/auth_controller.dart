import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/supabase_providers.dart';
import '../data/auth_repository.dart';

/// Proveedor para el repositorio de autenticación.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    client: ref.watch(supabaseClientProvider),
    vault: ref.watch(keyVaultServiceProvider),
  );
});

/// Proveedor de cambios en la sesión de autenticación.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

/// Controlador reactivo para acciones de autenticación y desbloqueo de la bóveda.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Estado inicial en reposo
    return null;
  }

  Future<void> signIn({
    required String email,
    required String password,
    required String masterKeyPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signIn(
          email: email,
          password: password,
          masterKeyPassword: masterKeyPassword,
        ));
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String masterKeyPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signUp(
          email: email,
          password: password,
          masterKeyPassword: masterKeyPassword,
        ));
  }

  Future<void> unlockVault({
    required String email,
    required String masterKeyPassword,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).unlockVault(
          email: email,
          masterKeyPassword: masterKeyPassword,
        ));
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signOut());
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
