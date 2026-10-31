import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/project_item.dart';
import 'projects_provider.dart';

/// Vista principal del Módulo de Proyectos con cifrado E2EE.
class ProjectsView extends ConsumerWidget {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredProjects = ref.watch(filteredProjectsProvider);
    final activeFilter = ref.watch(projectFilterProvider);

    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proyectos y Metas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Grandes iniciativas y metas con cifrado de extremo a extremo',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _openProjectDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Proyecto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Filtros rápidos ──
          Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected: activeFilter == ProjectFilter.all,
                onTap: () => ref
                    .read(projectFilterProvider.notifier)
                    .setFilter(ProjectFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Activos',
                selected: activeFilter == ProjectFilter.active,
                onTap: () => ref
                    .read(projectFilterProvider.notifier)
                    .setFilter(ProjectFilter.active),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pausados',
                selected: activeFilter == ProjectFilter.paused,
                onTap: () => ref
                    .read(projectFilterProvider.notifier)
                    .setFilter(ProjectFilter.paused),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Completados',
                selected: activeFilter == ProjectFilter.completed,
                onTap: () => ref
                    .read(projectFilterProvider.notifier)
                    .setFilter(ProjectFilter.completed),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                tooltip: 'Recargar proyectos',
                onPressed: () =>
                    ref.read(projectListProvider.notifier).refresh(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Cuadrícula de Proyectos ──
          Expanded(
            child: filteredProjects.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 12),
                    const Text('Error al cargar proyectos',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(projectListProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (projects) {
                if (projects.isEmpty) {
                  return _buildEmptyState(activeFilter);
                }
                return GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 210,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _ProjectCard(
                      project: project,
                      onEdit: () =>
                          _openProjectDialog(context, ref, project: project),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ProjectFilter filter) {
    final message = switch (filter) {
      ProjectFilter.all =>
        'No tienes proyectos aún.\nCrea tu primera meta o proyecto cifrado.',
      ProjectFilter.active => 'No tienes proyectos activos en este momento.',
      ProjectFilter.paused => 'No tienes proyectos pausados.',
      ProjectFilter.completed => 'No tienes proyectos completados aún.',
    };

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_special_outlined,
              size: 56,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProjectDialog(BuildContext context, WidgetRef ref,
      {ProjectItem? project}) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _ProjectEditorDialog(ref: ref, initialProject: project),
    );
  }
}

// =============================================================================
// Widget: Chip de Filtro
// =============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? const Color(0xFF0284C7) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widget: Tarjeta de Proyecto
// =============================================================================

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({
    required this.project,
    required this.onEdit,
  });

  final ProjectItem project;
  final VoidCallback onEdit;

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return const Color(0xFF0284C7);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = _parseColor(project.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de color superior
          Container(height: 4, color: themeColor),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera: Nombre y Badge de Estado
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project.name.isNotEmpty
                                  ? project.name
                                  : 'Sin nombre',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: project.status),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Descripción
                      Expanded(
                        child: Text(
                          project.description.isNotEmpty
                              ? project.description
                              : '(Sin descripción detallada)',
                          style: TextStyle(
                            color: project.description.isNotEmpty
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF64748B),
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Pie: Fecha y Acciones de Estado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(project.updatedAt),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                          Row(
                            children: [
                              // Menú rápido de cambio de estado
                              PopupMenuButton<ProjectStatus>(
                                tooltip: 'Cambiar estado',
                                icon: const Icon(Icons.sync_alt,
                                    size: 16, color: Color(0xFF94A3B8)),
                                splashRadius: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                color: const Color(0xFF0F172A),
                                onSelected: (newStatus) {
                                  ref
                                      .read(projectListProvider.notifier)
                                      .updateStatus(project.id, newStatus);
                                },
                                itemBuilder: (ctx) => [
                                  for (final s in ProjectStatus.values)
                                    PopupMenuItem(
                                      value: s,
                                      child: Text(
                                        s.label,
                                        style: TextStyle(
                                          color: s == project.status
                                              ? const Color(0xFF38BDF8)
                                              : Colors.white,
                                          fontWeight: s == project.status
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 16, color: Color(0xFF64748B)),
                                tooltip: 'Eliminar proyecto',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 16,
                                onPressed: () => _confirmDelete(context, ref),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar proyecto',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar el proyecto "${project.name}"? Los datos se marcarán como eliminados.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(projectListProvider.notifier).deleteProject(project.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget: Badge de Estado
// =============================================================================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ProjectStatus.active => (const Color(0xFF22C55E), 'Activo'),
      ProjectStatus.paused => (const Color(0xFFF59E0B), 'Pausado'),
      ProjectStatus.completed => (const Color(0xFF3B82F6), 'Completado'),
      ProjectStatus.archived => (const Color(0xFF64748B), 'Archivado'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// =============================================================================
// Dialog: Editor de Proyecto
// =============================================================================

class _ProjectEditorDialog extends ConsumerStatefulWidget {
  const _ProjectEditorDialog({
    required this.ref,
    this.initialProject,
  });

  final WidgetRef ref;
  final ProjectItem? initialProject;

  @override
  ConsumerState<_ProjectEditorDialog> createState() =>
      _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends ConsumerState<_ProjectEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedColor;
  late ProjectStatus _status;
  bool _isLoading = false;

  bool get _isEditing => widget.initialProject != null;

  static const _palette = [
    '#0284C7', // Azul Sky
    '#10B981', // Esmeralda
    '#8B5CF6', // Púrpura
    '#F59E0B', // Ámbar
    '#EC4899', // Rosa
    '#F97316', // Naranja
    '#06B6D4', // Cian
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.initialProject?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.initialProject?.description ?? '');
    _selectedColor = widget.initialProject?.colorHex ?? _palette.first;
    _status = widget.initialProject?.status ?? ProjectStatus.active;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 20),
          const SizedBox(width: 8),
          Text(
            _isEditing ? 'Editar Proyecto Cifrado' : 'Nuevo Proyecto Cifrado',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: !_isEditing,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Nombre del proyecto',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _descCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Descripción y objetivos',
                  alignLabelWithHint: true,
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Selector de color
              const Text('Color distintivo',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final hex in _palette) ...[
                    GestureDetector(
                      onTap: () => setState(() => _selectedColor = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Color(int.parse('0xFF${hex.replaceAll('#', '')}')),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == hex
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: _selectedColor == hex
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // Selector de estado inicial
              const Text('Estado',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final s in [
                    ProjectStatus.active,
                    ProjectStatus.paused,
                    ProjectStatus.completed,
                  ]) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _status = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _status == s
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _status == s
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF334155),
                            ),
                          ),
                          child: Text(
                            s.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _status == s
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: _status == s
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 14, color: Color(0xFF22C55E)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'El nombre, descripción y color se cifran localmente con AES-256-GCM.',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Guardar Cambios' : 'Crear Proyecto'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updatedProject = widget.initialProject!.copyWith(
          name: name,
          description: _descCtrl.text.trim(),
          colorHex: _selectedColor,
          status: _status,
          updatedAt: DateTime.now(),
        );
        await ref
            .read(projectListProvider.notifier)
            .updateProject(updatedProject);
      } else {
        await ref.read(projectListProvider.notifier).addProject(
              name: name,
              description: _descCtrl.text.trim(),
              colorHex: _selectedColor,
              status: _status,
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar proyecto: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
