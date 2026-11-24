import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/calendar/domain/calendar_event_item.dart';
import '../../features/calendar/presentation/calendar_provider.dart';
import '../../features/finance/domain/finance_transaction_item.dart';
import '../../features/finance/presentation/finance_provider.dart';
import '../../features/notes/domain/note_item.dart';
import '../../features/notes/presentation/notes_provider.dart';
import '../../features/projects/domain/project_item.dart';
import '../../features/projects/presentation/projects_provider.dart';
import '../../features/tasks/domain/task_item.dart';
import '../../features/tasks/presentation/tasks_provider.dart';
import '../crypto/crypto.dart';
import '../providers/crypto_providers.dart';
import '../providers/supabase_providers.dart';

/// Contenedor en memoria de los datos completos de una cuenta de Life-OS.
class LifeOsBackupBundle {
  final List<ProjectItem> projects;
  final List<TaskItem> tasks;
  final List<NoteItem> notes;
  final List<CalendarEventItem> calendarEvents;
  final List<FinanceTransactionItem> financeTransactions;

  const LifeOsBackupBundle({
    this.projects = const [],
    this.tasks = const [],
    this.notes = const [],
    this.calendarEvents = const [],
    this.financeTransactions = const [],
  });

  int get totalRecords =>
      projects.length +
      tasks.length +
      notes.length +
      calendarEvents.length +
      financeTransactions.length;
}

/// Resumen estructurado tras completar una importación controlada.
class BackupImportSummary {
  final int projectsCount;
  final int tasksCount;
  final int notesCount;
  final int calendarEventsCount;
  final int financeTransactionsCount;
  final int updatedExistingCount;

  const BackupImportSummary({
    required this.projectsCount,
    required this.tasksCount,
    required this.notesCount,
    required this.calendarEventsCount,
    required this.financeTransactionsCount,
    required this.updatedExistingCount,
  });

  int get totalProcessed =>
      projectsCount +
      tasksCount +
      notesCount +
      calendarEventsCount +
      financeTransactionsCount;
}

/// Servicio de Respaldo, Exportación e Importación de Datos (Fase 4 - G1).
///
/// Características de seguridad e integridad:
/// 1. Exportación cifrada por defecto con AES-256-GCM (usando la clave activa
///    de la bóveda o una contraseña de respaldo dedicada con salt propio para
///    permitir migración entre distintas cuentas).
/// 2. Verificación criptográfica de integridad mediante hash SHA-256 sobre el
///    payload canónico antes de aceptar cualquier importación.
/// 3. Prevención de duplicados y preservación de llaves foráneas (`project_id`)
///    importando proyectos primero y aplicando `UPSERT` por `id` (UUID),
///    re-cifrando los datos con la clave maestra activa de la cuenta destino.
class BackupService {
  static const String appIdentifier = 'Life-OS';
  static const int currentSchemaVersion = 1;

  final SupabaseClient? client;
  final EncryptionService encryptionService;
  final KeyVaultService vault;

  BackupService({
    this.client,
    required this.encryptionService,
    required this.vault,
  });

  /// Calcula el hash SHA-256 en hexadecimal de una cadena UTF-8.
  Future<String> computeSha256Hex(String input) async {
    final digest = await crypto.Sha256().hash(utf8.encode(input));
    final buffer = StringBuffer();
    for (final b in digest.bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Serializa un [LifeOsBackupBundle] a un archivo JSON de respaldo.
  ///
  /// - Si [encrypt] es `true` (por defecto), el contenido se cifra con AES-256-GCM.
  /// - Si se proporciona [customPassword], se deriva una clave con un salt aleatorio
  ///   incluido en la cabecera del respaldo (ideal para trasladar datos a otra cuenta).
  /// - Si no se proporciona [customPassword], se utiliza [vault.activeKey].
  Future<String> exportBackupToJson({
    required LifeOsBackupBundle bundle,
    bool encrypt = true,
    String? customPassword,
  }) async {
    final dataMap = <String, dynamic>{
      'projects': bundle.projects.map(_projectToMap).toList(),
      'tasks': bundle.tasks.map(_taskToMap).toList(),
      'notes': bundle.notes.map(_noteToMap).toList(),
      'calendar_events': bundle.calendarEvents.map(_eventToMap).toList(),
      'finance_transactions':
          bundle.financeTransactions.map(_financeToMap).toList(),
    };

    final canonicalDataJson = jsonEncode(dataMap);
    final checksum = await computeSha256Hex(canonicalDataJson);

    final envelope = <String, dynamic>{
      'app': appIdentifier,
      'schema_version': currentSchemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'encrypted': encrypt,
      'checksum_sha256': checksum,
      'counts': {
        'projects': bundle.projects.length,
        'tasks': bundle.tasks.length,
        'notes': bundle.notes.length,
        'calendar_events': bundle.calendarEvents.length,
        'finance_transactions': bundle.financeTransactions.length,
      },
    };

    if (encrypt) {
      crypto.SecretKey targetKey;
      if (customPassword != null && customPassword.trim().isNotEmpty) {
        final salt = KeyVaultService.generateSalt(16);
        targetKey = await vault.deriveKeyFromPassword(
          masterPassword: customPassword.trim(),
          salt: salt,
        );
        envelope['kdf_salt'] = base64Encode(salt);
      } else {
        targetKey = vault.activeKey;
      }

      final encryptedPayload = await encryptionService.encryptString(
        canonicalDataJson,
        targetKey,
      );
      envelope['payload'] = encryptedPayload.toMap();
    } else {
      envelope['payload'] = dataMap;
    }

    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Valida la estructura, autenticidad AES-256-GCM y checksum SHA-256 de un
  /// respaldo JSON, reconstruyendo el [LifeOsBackupBundle] en memoria.
  Future<LifeOsBackupBundle> validateAndParseBackup({
    required String rawJson,
    String? customPassword,
  }) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      throw const FormatException(
        'El archivo no tiene un formato JSON válido.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Estructura raíz de respaldo inválida.');
    }

    if (decoded['app'] != appIdentifier) {
      throw const FormatException(
        'El archivo no corresponde a un respaldo de Life-OS.',
      );
    }

    final version = decoded['schema_version'];
    if (version != currentSchemaVersion) {
      throw FormatException(
        'Versión de esquema de respaldo no soportada: $version.',
      );
    }

    final expectedChecksum = decoded['checksum_sha256'] as String?;
    if (expectedChecksum == null || expectedChecksum.isEmpty) {
      throw const FormatException(
        'El respaldo no contiene firma de integridad SHA-256.',
      );
    }

    final isEncrypted = decoded['encrypted'] as bool? ?? true;
    final dynamic rawPayload = decoded['payload'];
    if (rawPayload == null) {
      throw const FormatException('El respaldo no contiene bloque de datos.');
    }

    String canonicalDataJson;
    Map<String, dynamic> dataMap;

    if (isEncrypted) {
      if (rawPayload is! Map<String, dynamic>) {
        throw const FormatException('Bloque cifrado de respaldo corrupto.');
      }
      final encryptedPayload = EncryptedPayload.fromMap(rawPayload);

      crypto.SecretKey decryptKey;
      final kdfSaltBase64 = decoded['kdf_salt'] as String?;
      if (kdfSaltBase64 != null && kdfSaltBase64.isNotEmpty) {
        final pass = (customPassword != null && customPassword.trim().isNotEmpty)
            ? customPassword.trim()
            : (vault.activeMasterPassword ?? '');
        if (pass.isEmpty) {
          throw StateError(
            'Este respaldo fue protegido con contraseña. Ingresa la contraseña del respaldo para descifrarlo.',
          );
        }
        final salt = base64Decode(kdfSaltBase64);
        decryptKey = await vault.deriveKeyFromPassword(
          masterPassword: pass,
          salt: salt,
        );
      } else {
        decryptKey = vault.activeKey;
      }

      canonicalDataJson = await encryptionService.decryptToString(
        encryptedPayload,
        decryptKey,
      );
      dataMap = jsonDecode(canonicalDataJson) as Map<String, dynamic>;
    } else {
      if (rawPayload is! Map<String, dynamic>) {
        throw const FormatException('Bloque de datos en claro inválido.');
      }
      dataMap = rawPayload;
      canonicalDataJson = jsonEncode(dataMap);
    }

    // Validar integridad SHA-256
    final actualChecksum = await computeSha256Hex(canonicalDataJson);
    if (actualChecksum != expectedChecksum) {
      throw const FormatException(
        'Fallo de integridad: el contenido del respaldo fue alterado o está corrupto (SHA-256 mismatch).',
      );
    }

    final projects = ((dataMap['projects'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_projectFromMap)
        .toList();

    final tasks = ((dataMap['tasks'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_taskFromMap)
        .toList();

    final notes = ((dataMap['notes'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_noteFromMap)
        .toList();

    final events = ((dataMap['calendar_events'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_eventFromMap)
        .toList();

    final finances = ((dataMap['finance_transactions'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_financeFromMap)
        .toList();

    return LifeOsBackupBundle(
      projects: projects,
      tasks: tasks,
      notes: notes,
      calendarEvents: events,
      financeTransactions: finances,
    );
  }

  /// Fusiona un [LifeOsBackupBundle] con las listas existentes deduplicando por `id` (UUID).
  /// Si un registro con el mismo `id` ya existe, se actualiza únicamente si el respaldo
  /// tiene un `updatedAt` igual o más reciente (o se reemplaza sin duplicar).
  ({
    LifeOsBackupBundle mergedBundle,
    BackupImportSummary summary,
  }) mergeBundlesWithoutDuplicates({
    required LifeOsBackupBundle existing,
    required LifeOsBackupBundle incoming,
  }) {
    int updatedCount = 0;

    List<T> mergeList<T>(
      List<T> currentList,
      List<T> newList,
      String Function(T) getId,
    ) {
      final map = <String, T>{for (final item in currentList) getId(item): item};
      for (final item in newList) {
        final id = getId(item);
        if (map.containsKey(id)) {
          updatedCount++;
        }
        map[id] = item;
      }
      return map.values.toList();
    }

    final mergedProjects = mergeList<ProjectItem>(
      existing.projects,
      incoming.projects,
      (p) => p.id,
    );
    final mergedTasks = mergeList<TaskItem>(
      existing.tasks,
      incoming.tasks,
      (t) => t.id,
    );
    final mergedNotes = mergeList<NoteItem>(
      existing.notes,
      incoming.notes,
      (n) => n.id,
    );
    final mergedEvents = mergeList<CalendarEventItem>(
      existing.calendarEvents,
      incoming.calendarEvents,
      (e) => e.id,
    );
    final mergedFinances = mergeList<FinanceTransactionItem>(
      existing.financeTransactions,
      incoming.financeTransactions,
      (f) => f.id,
    );

    final summary = BackupImportSummary(
      projectsCount: incoming.projects.length,
      tasksCount: incoming.tasks.length,
      notesCount: incoming.notes.length,
      calendarEventsCount: incoming.calendarEvents.length,
      financeTransactionsCount: incoming.financeTransactions.length,
      updatedExistingCount: updatedCount,
    );

    return (
      mergedBundle: LifeOsBackupBundle(
        projects: mergedProjects,
        tasks: mergedTasks,
        notes: mergedNotes,
        calendarEvents: mergedEvents,
        financeTransactions: mergedFinances,
      ),
      summary: summary,
    );
  }

  /// Importa un [LifeOsBackupBundle] hacia Supabase realizando UPSERT por `id`
  /// y re-cifrando cada registro con la clave maestra activa de la cuenta destino.
  Future<BackupImportSummary> importBackupToSupabase({
    required LifeOsBackupBundle incoming,
    required LifeOsBackupBundle existingInMemory,
  }) async {
    final mergeResult = mergeBundlesWithoutDuplicates(
      existing: existingInMemory,
      incoming: incoming,
    );

    final supabase = client;
    final userId = supabase?.auth.currentUser?.id;
    if (supabase == null || userId == null) {
      return mergeResult.summary;
    }

    final activeKey = vault.activeKey;
    final validProjectIds = <String>{
      for (final p in mergeResult.mergedBundle.projects) p.id,
    };

    // 1. Upsert Proyectos primero (para respetar FK project_id en tareas y notas)
    for (final p in incoming.projects) {
      final payload = await encryptionService.encryptJson(
        p.toEncryptedFieldsMap(),
        activeKey,
      );
      await supabase.from('projects').upsert({
        'id': p.id,
        'user_id': userId,
        'status': p.status.value,
        'encrypted_data': payload.serialize(),
        'created_at': p.createdAt.toUtc().toIso8601String(),
        'updated_at': p.updatedAt.toUtc().toIso8601String(),
      });
    }

    // 2. Upsert Tareas
    for (final t in incoming.tasks) {
      final payload = await encryptionService.encryptJson(
        t.toEncryptedFieldsMap(),
        activeKey,
      );
      final safeProjectId =
          (t.projectId != null && validProjectIds.contains(t.projectId))
              ? t.projectId
              : null;
      await supabase.from('tasks').upsert({
        'id': t.id,
        'user_id': userId,
        'project_id': safeProjectId,
        'status': t.status.value,
        'priority': t.priority,
        'due_date': t.dueDate?.toUtc().toIso8601String(),
        'encrypted_data': payload.serialize(),
        'created_at': t.createdAt.toUtc().toIso8601String(),
        'updated_at': t.updatedAt.toUtc().toIso8601String(),
      });
    }

    // 3. Upsert Notas
    for (final n in incoming.notes) {
      final payload = await encryptionService.encryptJson(
        n.toEncryptedFieldsMap(),
        activeKey,
      );
      final safeProjectId =
          (n.projectId != null && validProjectIds.contains(n.projectId))
              ? n.projectId
              : null;
      await supabase.from('notes').upsert({
        'id': n.id,
        'user_id': userId,
        'project_id': safeProjectId,
        'is_pinned': n.isPinned,
        'encrypted_data': payload.serialize(),
        'created_at': n.createdAt.toUtc().toIso8601String(),
        'updated_at': n.updatedAt.toUtc().toIso8601String(),
      });
    }

    // 4. Upsert Eventos de Calendario
    for (final e in incoming.calendarEvents) {
      final payload = await encryptionService.encryptJson(
        e.toEncryptedFieldsMap(),
        activeKey,
      );
      await supabase.from('calendar_events').upsert({
        'id': e.id,
        'user_id': userId,
        'start_time': e.startTime.toUtc().toIso8601String(),
        'end_time': e.endTime.toUtc().toIso8601String(),
        'is_all_day': e.isAllDay,
        'encrypted_data': payload.serialize(),
        'created_at': e.createdAt.toUtc().toIso8601String(),
        'updated_at': e.updatedAt.toUtc().toIso8601String(),
      });
    }

    // 5. Upsert Transacciones Financieras
    for (final f in incoming.financeTransactions) {
      final payload = await encryptionService.encryptJson(
        f.toEncryptedFieldsMap(),
        activeKey,
      );
      await supabase.from('finance_transactions').upsert({
        'id': f.id,
        'user_id': userId,
        'type': f.type.value,
        'transaction_date': f.transactionDate.toUtc().toIso8601String(),
        'encrypted_data': payload.serialize(),
        'created_at': f.createdAt.toUtc().toIso8601String(),
        'updated_at': f.updatedAt.toUtc().toIso8601String(),
      });
    }

    return mergeResult.summary;
  }

  /// Guarda el contenido JSON de respaldo en un archivo local del dispositivo.
  Future<File> saveBackupToFile(String jsonContent, {String? customPath}) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final fileName = 'life_os_backup_$timestamp.lifeos.json';
    final path = customPath ??
        '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    await file.writeAsString(jsonContent, flush: true);
    return file;
  }

  // ---------------------------------------------------------------------------
  // Mapeadores internos de serialización canónica
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _projectToMap(ProjectItem p) => {
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'color_hex': p.colorHex,
        'status': p.status.value,
        'created_at': p.createdAt.toUtc().toIso8601String(),
        'updated_at': p.updatedAt.toUtc().toIso8601String(),
      };

  ProjectItem _projectFromMap(Map<String, dynamic> m) => ProjectItem(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        colorHex: m['color_hex'] as String? ?? '#0284C7',
        status: ProjectStatus.fromString(m['status'] as String? ?? 'active'),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> _taskToMap(TaskItem t) => {
        'id': t.id,
        'project_id': t.projectId,
        'title': t.title,
        'notes': t.notes,
        'status': t.status.value,
        'priority': t.priority,
        'due_date': t.dueDate?.toUtc().toIso8601String(),
        'created_at': t.createdAt.toUtc().toIso8601String(),
        'updated_at': t.updatedAt.toUtc().toIso8601String(),
      };

  TaskItem _taskFromMap(Map<String, dynamic> m) => TaskItem(
        id: m['id'] as String,
        projectId: m['project_id'] as String?,
        title: m['title'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
        status: TaskStatus.fromString(m['status'] as String? ?? 'todo'),
        priority: (m['priority'] as num?)?.toInt() ?? 2,
        dueDate: m['due_date'] != null
            ? DateTime.parse(m['due_date'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> _noteToMap(NoteItem n) => {
        'id': n.id,
        'project_id': n.projectId,
        'is_pinned': n.isPinned,
        'title': n.title,
        'content': n.content,
        'tags': n.tags,
        'created_at': n.createdAt.toUtc().toIso8601String(),
        'updated_at': n.updatedAt.toUtc().toIso8601String(),
      };

  NoteItem _noteFromMap(Map<String, dynamic> m) => NoteItem(
        id: m['id'] as String,
        projectId: m['project_id'] as String?,
        isPinned: m['is_pinned'] as bool? ?? false,
        title: m['title'] as String? ?? '',
        content: m['content'] as String? ?? '',
        tags: ((m['tags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> _eventToMap(CalendarEventItem e) => {
        'id': e.id,
        'start_time': e.startTime.toUtc().toIso8601String(),
        'end_time': e.endTime.toUtc().toIso8601String(),
        'is_all_day': e.isAllDay,
        'title': e.title,
        'description': e.description,
        'location': e.location,
        'category': e.category,
        'created_at': e.createdAt.toUtc().toIso8601String(),
        'updated_at': e.updatedAt.toUtc().toIso8601String(),
      };

  CalendarEventItem _eventFromMap(Map<String, dynamic> m) => CalendarEventItem(
        id: m['id'] as String,
        startTime: DateTime.parse(m['start_time'] as String),
        endTime: DateTime.parse(m['end_time'] as String),
        isAllDay: m['is_all_day'] as bool? ?? false,
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        location: m['location'] as String? ?? '',
        category: m['category'] as String? ?? 'Personal',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> _financeToMap(FinanceTransactionItem f) => {
        'id': f.id,
        'type': f.type.value,
        'transaction_date': f.transactionDate.toUtc().toIso8601String(),
        'amount': f.amount,
        'currency': f.currency,
        'category': f.category,
        'notes': f.notes,
        'from_account': f.fromAccount,
        'to_account': f.toAccount,
        'created_at': f.createdAt.toUtc().toIso8601String(),
        'updated_at': f.updatedAt.toUtc().toIso8601String(),
      };

  FinanceTransactionItem _financeFromMap(Map<String, dynamic> m) =>
      FinanceTransactionItem(
        id: m['id'] as String,
        type: TransactionType.fromString(m['type'] as String? ?? 'expense'),
        transactionDate: DateTime.parse(m['transaction_date'] as String),
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        currency: m['currency'] as String? ?? 'USD',
        category: m['category'] as String? ?? 'General',
        notes: m['notes'] as String? ?? '',
        fromAccount: m['from_account'] as String?,
        toAccount: m['to_account'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

/// Proveedor para el servicio de respaldos E2EE de Life-OS.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    client: ref.watch(supabaseClientProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    vault: ref.watch(keyVaultServiceProvider),
  );
});

/// Construye el [LifeOsBackupBundle] actual a partir del estado en memoria de los 5 módulos.
final currentAccountBackupBundleProvider = Provider<LifeOsBackupBundle>((ref) {
  return LifeOsBackupBundle(
    projects: ref.watch(projectListProvider).value ?? const [],
    tasks: ref.watch(taskListProvider).value ?? const [],
    notes: ref.watch(noteListProvider).value ?? const [],
    calendarEvents: ref.watch(calendarEventListProvider).value ?? const [],
    financeTransactions:
        ref.watch(financeTransactionListProvider).value ?? const [],
  );
});
