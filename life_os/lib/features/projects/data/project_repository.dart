import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto.dart';
import '../domain/project_item.dart';

/// Repositorio encargado de la persistencia de proyectos con cifrado E2EE.
class ProjectRepository {
  final SupabaseClient? client;
  final EncryptionService encryptionService;
  final KeyVaultService vault;

  static const _table = 'projects';

  ProjectRepository({
    this.client,
    required this.encryptionService,
    required this.vault,
  });

  /// Crea un nuevo proyecto cifrando nombre, descripción y color antes de persistir.
  Future<ProjectItem> createProject({
    required String name,
    String description = '',
    String colorHex = '#0284C7',
    ProjectStatus status = ProjectStatus.active,
  }) async {
    final supabase = _requireClient();
    final userId = _requireUserId();

    final sensitiveData = {
      'name': name,
      'description': description,
      'color_hex': colorHex,
    };

    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    final row = <String, dynamic>{
      'user_id': userId,
      'encrypted_data': payload.serialize(),
      'status': status.value,
    };

    final response = await supabase
        .from(_table)
        .insert(row)
        .select()
        .single();

    return ProjectItem.fromDecryptedMap(
      row: response,
      decryptedFields: sensitiveData,
    );
  }

  /// Obtiene los proyectos activos del usuario y los descifra localmente.
  Future<List<ProjectItem>> fetchProjects() async {
    final supabase = _requireClient();

    final rows = await supabase
        .from(_table)
        .select()
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    final projects = <ProjectItem>[];
    for (final row in rows) {
      final encryptedString = row['encrypted_data'] as String;
      final payload = EncryptedPayload.deserialize(encryptedString);
      final decryptedFields = await encryptionService.decryptJson(
        payload,
        vault.activeKey,
      );
      projects.add(ProjectItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      ));
    }

    return projects;
  }

  /// Actualiza un proyecto existente re-cifrando los campos confidenciales.
  Future<void> updateProject(ProjectItem project) async {
    final supabase = _requireClient();

    final sensitiveData = project.toEncryptedFieldsMap();
    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    final updates = <String, dynamic>{
      'encrypted_data': payload.serialize(),
      'status': project.status.value,
    };

    await supabase.from(_table).update(updates).eq('id', project.id);
  }

  /// Cambia el estado operativo del proyecto directamente en el metadato en claro.
  Future<void> updateStatus(String projectId, ProjectStatus newStatus) async {
    final supabase = _requireClient();
    await supabase
        .from(_table)
        .update({'status': newStatus.value})
        .eq('id', projectId);
  }

  /// Elimina un proyecto de forma suave (soft delete).
  Future<void> softDeleteProject(String projectId) async {
    final supabase = _requireClient();
    await supabase
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', projectId);
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

