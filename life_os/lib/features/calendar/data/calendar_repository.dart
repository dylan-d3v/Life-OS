import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto.dart';
import '../domain/calendar_event_item.dart';

/// Repositorio encargado de la persistencia de eventos de calendario con cifrado E2EE.
class CalendarRepository {
  final SupabaseClient? client;
  final EncryptionService encryptionService;
  final KeyVaultService vault;

  static const _table = 'calendar_events';

  CalendarRepository({
    this.client,
    required this.encryptionService,
    required this.vault,
  });

  /// Crea un nuevo evento cifrando título, descripción y ubicación antes de guardar en Supabase.
  Future<CalendarEventItem> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String description = '',
    String location = '',
  }) async {
    final supabase = _requireClient();
    final userId = _requireUserId();

    if (endTime.isBefore(startTime)) {
      throw ArgumentError('La hora de fin no puede ser anterior a la hora de inicio.');
    }

    final sensitiveData = {
      'title': title,
      'description': description,
      'location': location,
    };

    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    final row = <String, dynamic>{
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_all_day': isAllDay,
      'encrypted_data': payload.serialize(),
    };

    final response = await supabase
        .from(_table)
        .insert(row)
        .select()
        .single();

    return CalendarEventItem.fromDecryptedMap(
      row: response,
      decryptedFields: sensitiveData,
    );
  }

  /// Obtiene los eventos activos ordenados cronológicamente y los descifra localmente.
  Future<List<CalendarEventItem>> fetchEvents() async {
    final supabase = _requireClient();

    final rows = await supabase
        .from(_table)
        .select()
        .isFilter('deleted_at', null)
        .order('start_time', ascending: true);

    final events = <CalendarEventItem>[];
    for (final row in rows) {
      final encryptedString = row['encrypted_data'] as String;
      final payload = EncryptedPayload.deserialize(encryptedString);
      final decryptedFields = await encryptionService.decryptJson(
        payload,
        vault.activeKey,
      );
      events.add(CalendarEventItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      ));
    }

    return events;
  }

  /// Actualiza un evento existente re-cifrando la información confidencial.
  Future<void> updateEvent(CalendarEventItem event) async {
    final supabase = _requireClient();

    if (event.endTime.isBefore(event.startTime)) {
      throw ArgumentError('La hora de fin no puede ser anterior a la hora de inicio.');
    }

    final sensitiveData = event.toEncryptedFieldsMap();
    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    final updates = <String, dynamic>{
      'start_time': event.startTime.toIso8601String(),
      'end_time': event.endTime.toIso8601String(),
      'is_all_day': event.isAllDay,
      'encrypted_data': payload.serialize(),
    };

    await supabase.from(_table).update(updates).eq('id', event.id);
  }

  /// Elimina un evento de forma suave (soft delete).
  Future<void> softDeleteEvent(String eventId) async {
    final supabase = _requireClient();
    await supabase
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', eventId);
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

