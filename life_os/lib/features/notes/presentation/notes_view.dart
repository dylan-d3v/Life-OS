import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/note_item.dart';
import 'notes_provider.dart';

/// Vista principal del Módulo de Notas Diarias con cifrado E2EE.
class NotesView extends ConsumerWidget {
  const NotesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredNotes = ref.watch(filteredNotesProvider);
    final activeFilter = ref.watch(noteFilterProvider);

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
                      'Notas Diarias',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Apuntes, ideas y conocimiento con cifrado de extremo a extremo',
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
                onPressed: () => _openNoteDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Nota'),
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

          // ── Barra de búsqueda y filtros ──
          Row(
            children: [
              _FilterChip(
                label: 'Todas',
                selected: activeFilter == NoteFilter.all,
                onTap: () => ref
                    .read(noteFilterProvider.notifier)
                    .setFilter(NoteFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Fijadas',
                selected: activeFilter == NoteFilter.pinned,
                onTap: () => ref
                    .read(noteFilterProvider.notifier)
                    .setFilter(NoteFilter.pinned),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (val) => ref
                        .read(noteSearchQueryProvider.notifier)
                        .setQuery(val),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar en notas descifradas...',
                      hintStyle:
                          const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                tooltip: 'Recargar notas',
                onPressed: () => ref.read(noteListProvider.notifier).refresh(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Lista de Notas ──
          Expanded(
            child: filteredNotes.when(
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
                    const Text('Error al cargar notas',
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
                          ref.read(noteListProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return _buildEmptyState(activeFilter);
                }
                return GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _NoteCard(
                      note: note,
                      onEdit: () => _openNoteDialog(context, ref, note: note),
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

  Widget _buildEmptyState(NoteFilter filter) {
    final message = filter == NoteFilter.pinned
        ? 'No tienes notas fijadas.\nToca el icono de pin en cualquier nota para destacarla.'
        : 'No hay notas registradas.\nCrea tu primera nota con cifrado E2EE.';

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
              Icons.note_alt_outlined,
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

  void _openNoteDialog(BuildContext context, WidgetRef ref, {NoteItem? note}) {
    showDialog(
      context: context,
      builder: (ctx) => _NoteEditorDialog(ref: ref, initialNote: note),
    );
  }
}

// =============================================================================
// Widget: Chip de filtro
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
// Widget: Tarjeta de Nota
// =============================================================================

class _NoteCard extends ConsumerWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
  });

  final NoteItem note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: note.isPinned
              ? const Color(0xFF38BDF8)
              : const Color(0xFF334155),
          width: note.isPinned ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Título y botón fijar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        note.title.isNotEmpty ? note.title : 'Sin título',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        note.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        size: 18,
                        color: note.isPinned
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF64748B),
                      ),
                      tooltip: note.isPinned ? 'Desfijar' : 'Fijar nota',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onPressed: () => ref
                          .read(noteListProvider.notifier)
                          .togglePin(note.id),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Contenido snippet
                Expanded(
                  child: Text(
                    note.content.isNotEmpty
                        ? note.content
                        : '(Nota sin contenido adicional)',
                    style: TextStyle(
                      color: note.content.isNotEmpty
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),

                // Tags si existen
                if (note.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: note.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 10,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Pie de tarjeta: Fecha y botón eliminar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm', 'es')
                          .format(note.updatedAt),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Color(0xFF64748B)),
                      tooltip: 'Eliminar nota',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar nota',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Deseas eliminar "${note.title.isNotEmpty ? note.title : 'esta nota'}"?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(noteListProvider.notifier).deleteNote(note.id);
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
// Dialog: Editor de Nota (Crear / Modificar)
// =============================================================================

class _NoteEditorDialog extends ConsumerStatefulWidget {
  const _NoteEditorDialog({
    required this.ref,
    this.initialNote,
  });

  final WidgetRef ref;
  final NoteItem? initialNote;

  @override
  ConsumerState<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends ConsumerState<_NoteEditorDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _tagsCtrl;
  late bool _isPinned;
  bool _isLoading = false;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.initialNote?.title ?? '');
    _contentCtrl =
        TextEditingController(text: widget.initialNote?.content ?? '');
    _tagsCtrl = TextEditingController(
      text: widget.initialNote?.tags.join(', ') ?? '',
    );
    _isPinned = widget.initialNote?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
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
            _isEditing ? 'Editar Nota Cifrada' : 'Nueva Nota Cifrada',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                autofocus: !_isEditing,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Título de la nota',
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
                controller: _contentCtrl,
                maxLines: 8,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Contenido (apuntes, ideas o texto enriquecido)',
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

              TextField(
                controller: _tagsCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Etiquetas (separadas por comas)',
                  hintText: 'ej: finanzas, ideas, reunión',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
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
              const SizedBox(height: 12),

              Row(
                children: [
                  Checkbox(
                    value: _isPinned,
                    activeColor: const Color(0xFF0284C7),
                    checkColor: Colors.white,
                    onChanged: (val) =>
                        setState(() => _isPinned = val ?? false),
                  ),
                  const Text('Fijar esta nota al inicio',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),

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
                        'El título, contenido y etiquetas se cifran con AES-256-GCM antes de salir de tu equipo.',
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
              : Text(_isEditing ? 'Guardar Cambios' : 'Crear Nota'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim().replaceAll('#', ''))
        .where((t) => t.isNotEmpty)
        .toList();

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updatedNote = widget.initialNote!.copyWith(
          title: title,
          content: content,
          tags: tags,
          isPinned: _isPinned,
          updatedAt: DateTime.now(),
        );
        await ref.read(noteListProvider.notifier).updateNote(updatedNote);
      } else {
        await ref.read(noteListProvider.notifier).addNote(
              title: title,
              content: content,
              tags: tags,
              isPinned: _isPinned,
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar nota: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
