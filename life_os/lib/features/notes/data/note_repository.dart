import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto.dart';
import '../domain/note_item.dart';

/// Repositorio encargado de la persistencia de notas con cifrado E2EE.
/// Protege el título, cuerpo y etiquetas antes de enviarlos a Supabase.
class NoteRepository {
  final SupabaseClient? client;
  final EncryptionService encryptionService;
  final KeyVaultService vault;

  static const _table = 'notes';

  NoteRepository({
    this.client,
    required this.encryptionService,
    required this.vault,
  });

  /// Crea una nueva nota cifrando los campos sensibles localmente.
  Future<NoteItem> createNote({
    required String title,
    String content = '',
    List<String> tags = const [],
    bool isPinned = false,
    String? projectId,
  }) async {
    final supabase = _requireClient();
    final userId = _requireUserId();

    // 1. Cifrar campos confidenciales
    final sensitiveData = {
      'title': title,
      'content': content,
      'tags': tags,
    };
    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    // 2. Construir fila para Supabase
    final row = <String, dynamic>{
      'user_id': userId,
      'encrypted_data': payload.serialize(),
      'is_pinned': isPinned,
      'project_id': ?projectId,
    };

    final response = await supabase
        .from(_table)
        .insert(row)
        .select()
        .single();

    return NoteItem.fromDecryptedMap(
      row: response,
      decryptedFields: sensitiveData,
    );
  }

  /// Obtiene las notas activas del usuario, ordenadas con las fijadas primero
  /// y luego por fecha de actualización descendente.
  Future<List<NoteItem>> fetchNotes() async {
    final supabase = _requireClient();

    final rows = await supabase
        .from(_table)
        .select()
        .isFilter('deleted_at', null)
        .order('is_pinned', ascending: false)
        .order('updated_at', ascending: false);

    final notes = <NoteItem>[];
    for (final row in rows) {
      final encryptedString = row['encrypted_data'] as String;
      final payload = EncryptedPayload.deserialize(encryptedString);
      final decryptedFields = await encryptionService.decryptJson(
        payload,
        vault.activeKey,
      );
      notes.add(NoteItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      ));
    }

    return notes;
  }

  /// Actualiza los campos sensibles y metadatos de una nota existente.
  Future<void> updateNote(NoteItem note) async {
    final supabase = _requireClient();

    final sensitiveData = note.toEncryptedFieldsMap();
    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    final updates = <String, dynamic>{
      'encrypted_data': payload.serialize(),
      'is_pinned': note.isPinned,
      'project_id': note.projectId,
    };

    await supabase.from(_table).update(updates).eq('id', note.id);
  }

  /// Alterna el estado de fijado (pinned) sin necesidad de re-cifrar datos.
  Future<void> togglePin(String noteId, bool currentPinState) async {
    final supabase = _requireClient();
    await supabase
        .from(_table)
        .update({'is_pinned': !currentPinState})
        .eq('id', noteId);
  }

  /// Elimina una nota de forma suave (soft delete).
  Future<void> softDeleteNote(String noteId) async {
    final supabase = _requireClient();
    await supabase
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', noteId);
  }

  // ---------------------------------------------------------------------------
  // Helpers internos
  // ---------------------------------------------------------------------------

  SupabaseClient _requireClient() {
    final c = client;
    if (c == null) {
      throw StateError('El cliente de Supabase no está inicializado.');
    }
    return c;
  }

  String _requireUserId() {
    final user = client?.auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }
    return user.id;
  }
}

