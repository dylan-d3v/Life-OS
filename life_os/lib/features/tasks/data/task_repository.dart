import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto.dart';
import '../domain/task_item.dart';

/// Repositorio que gestiona la persistencia de tareas en Supabase
/// aplicando cifrado E2EE a los campos sensibles (título, notas)
/// antes de enviarlos al servidor.
///
/// Los metadatos operativos (status, priority, due_date) se almacenan
/// en claro para permitir filtrado y ordenamiento en el backend.
class TaskRepository {
  final SupabaseClient? client;
  final EncryptionService encryptionService;
  final KeyVaultService vault;

  static const _table = 'tasks';

  TaskRepository({
    this.client,
    required this.encryptionService,
    required this.vault,
  });

  /// Crea una nueva tarea cifrando los campos sensibles y enviándola a Supabase.
  Future<TaskItem> createTask({
    required String title,
    String notes = '',
    int priority = 2,
    DateTime? dueDate,
    String? projectId,
  }) async {
    final supabase = _requireClient();
    final userId = _requireUserId();

    // 1. Cifrar campos sensibles
    final sensitiveData = {'title': title, 'notes': notes};
    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    // 2. Construir fila con ciphertext + metadatos en claro
    final row = <String, dynamic>{
      'user_id': userId,
      'encrypted_data': payload.serialize(),
      'status': TaskStatus.todo.value,
      'priority': priority,
      'due_date': ?dueDate?.toIso8601String(),
      'project_id': ?projectId,
    };

    // 3. Insertar y obtener la fila completa de vuelta
    final response = await supabase
        .from(_table)
        .insert(row)
        .select()
        .single();

    return TaskItem.fromDecryptedMap(
      row: response,
      decryptedFields: sensitiveData,
    );
  }

  /// Obtiene todas las tareas activas (no eliminadas) del usuario autenticado,
  /// descifrando los campos sensibles localmente.
  Future<List<TaskItem>> fetchTasks() async {
    final supabase = _requireClient();

    // RLS filtra automáticamente por user_id
    final rows = await supabase
        .from(_table)
        .select()
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    final tasks = <TaskItem>[];
    for (final row in rows) {
      final encryptedString = row['encrypted_data'] as String;
      final payload = EncryptedPayload.deserialize(encryptedString);
      final decryptedFields = await encryptionService.decryptJson(
        payload,
        vault.activeKey,
      );
      tasks.add(TaskItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      ));
    }

    return tasks;
  }

  /// Actualiza los campos de una tarea existente.
  /// Si [title] o [notes] cambian, se re-cifra `encrypted_data`.
  Future<void> updateTask(TaskItem task) async {
    final supabase = _requireClient();

    // Re-cifrar campos sensibles con la clave activa
    final sensitiveData = task.toEncryptedFieldsMap();
    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    final updates = <String, dynamic>{
      'encrypted_data': payload.serialize(),
      'status': task.status.value,
      'priority': task.priority,
      'due_date': task.dueDate?.toIso8601String(),
      'project_id': task.projectId,
    };

    await supabase.from(_table).update(updates).eq('id', task.id);
  }

  /// Cambia el estado de una tarea sin necesidad de re-cifrar datos sensibles.
  Future<void> updateStatus(String taskId, TaskStatus newStatus) async {
    final supabase = _requireClient();
    await supabase
        .from(_table)
        .update({'status': newStatus.value})
        .eq('id', taskId);
  }

  /// Elimina una tarea de forma suave (soft delete) estableciendo `deleted_at`.
  Future<void> softDeleteTask(String taskId) async {
    final supabase = _requireClient();
    await supabase
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', taskId);
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

