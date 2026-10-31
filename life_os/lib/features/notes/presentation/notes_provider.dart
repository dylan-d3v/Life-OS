import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/supabase_providers.dart';
import '../data/note_repository.dart';
import '../domain/note_item.dart';

// =============================================================================
// Repositorio de Notas
// =============================================================================

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(
    client: ref.watch(supabaseClientProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    vault: ref.watch(keyVaultServiceProvider),
  );
});

// =============================================================================
// Filtro y Búsqueda
// =============================================================================

enum NoteFilter { all, pinned }

class NoteFilterNotifier extends Notifier<NoteFilter> {
  @override
  NoteFilter build() => NoteFilter.all;

  void setFilter(NoteFilter filter) {
    state = filter;
  }
}

final noteFilterProvider =
    NotifierProvider<NoteFilterNotifier, NoteFilter>(NoteFilterNotifier.new);

class NoteSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final noteSearchQueryProvider =
    NotifierProvider<NoteSearchQueryNotifier, String>(
  NoteSearchQueryNotifier.new,
);

// =============================================================================
// Lista de Notas
// =============================================================================

class NoteListNotifier extends AsyncNotifier<List<NoteItem>> {
  @override
  Future<List<NoteItem>> build() => _loadNotes();

  Future<List<NoteItem>> _loadNotes() async {
    final repo = ref.read(noteRepositoryProvider);
    return repo.fetchNotes();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadNotes);
  }

  Future<void> addNote({
    required String title,
    String content = '',
    List<String> tags = const [],
    bool isPinned = false,
  }) async {
    final repo = ref.read(noteRepositoryProvider);
    final newNote = await repo.createNote(
      title: title,
      content: content,
      tags: tags,
      isPinned: isPinned,
    );

    state = state.whenData((notes) => [newNote, ...notes]);
  }

  Future<void> togglePin(String noteId) async {
    final repo = ref.read(noteRepositoryProvider);
    final currentNotes = state.value ?? [];
    final note = currentNotes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) return;

    final newPinned = !note.isPinned;

    state = state.whenData((notes) {
      final updatedList = notes.map((n) {
        if (n.id == noteId) return n.copyWith(isPinned: newPinned);
        return n;
      }).toList();

      // Mantener orden: fijadas primero
      updatedList.sort((a, b) {
        if (a.isPinned == b.isPinned) {
          return b.updatedAt.compareTo(a.updatedAt);
        }
        return a.isPinned ? -1 : 1;
      });
      return updatedList;
    });

    await repo.togglePin(noteId, note.isPinned);
  }

  Future<void> updateNote(NoteItem note) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.updateNote(note);

    state = state.whenData((notes) {
      return notes.map((n) => n.id == note.id ? note : n).toList();
    });
  }

  Future<void> deleteNote(String noteId) async {
    final repo = ref.read(noteRepositoryProvider);

    state = state.whenData(
      (notes) => notes.where((n) => n.id != noteId).toList(),
    );

    await repo.softDeleteNote(noteId);
  }
}

final noteListProvider =
    AsyncNotifierProvider<NoteListNotifier, List<NoteItem>>(
  NoteListNotifier.new,
);

/// Proveedor que filtra las notas por pestaña y término de búsqueda (en memoria descifrada).
final filteredNotesProvider = Provider<AsyncValue<List<NoteItem>>>((ref) {
  final filter = ref.watch(noteFilterProvider);
  final query = ref.watch(noteSearchQueryProvider).trim().toLowerCase();
  final notesAsync = ref.watch(noteListProvider);

  return notesAsync.whenData((notes) {
    var result = notes;

    if (filter == NoteFilter.pinned) {
      result = result.where((n) => n.isPinned).toList();
    }

    if (query.isNotEmpty) {
      result = result.where((n) {
        final matchesTitle = n.title.toLowerCase().contains(query);
        final matchesContent = n.content.toLowerCase().contains(query);
        final matchesTags =
            n.tags.any((tag) => tag.toLowerCase().contains(query));
        return matchesTitle || matchesContent || matchesTags;
      }).toList();
    }

    return result;
  });
});

