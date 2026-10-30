import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Proveedor para la instancia del cliente de Supabase.
/// Retorna `null` de forma segura si la instancia no ha sido inicializada (ej. en tests o modo offline).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});
