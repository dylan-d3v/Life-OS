import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/notes/domain/note_item.dart';
import 'package:life_os/features/notes/presentation/notes_provider.dart';
import 'package:life_os/features/notes/presentation/notes_view.dart';

class MockNoteListNotifier extends NoteListNotifier {
  final List<NoteItem> _initialNotes;

  MockNoteListNotifier([this._initialNotes = const []]);

  @override
  Future<List<NoteItem>> build() async => _initialNotes;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> togglePin(String noteId) async {
    state = state.whenData((notes) {
      return notes.map((n) {
        if (n.id == noteId) return n.copyWith(isPinned: !n.isPinned);
        return n;
      }).toList();
    });
  }

  @override
  Future<void> deleteNote(String noteId) async {
    state = state.whenData(
      (notes) => notes.where((n) => n.id != noteId).toList(),
    );
  }
}

void main() {
  testWidgets('NotesView muestra encabezado, filtros y estado vacío inicial',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteListProvider.overrideWith(() => MockNoteListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NotesView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Notas Diarias'), findsOneWidget);
    expect(find.text('Nueva Nota'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Fijadas'), findsOneWidget);
    expect(find.textContaining('No hay notas registradas'), findsOneWidget);
  });

  testWidgets('NotesView muestra tarjetas de notas y permite filtrar y buscar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleNotes = [
      NoteItem(
        id: '1',
        title: 'Ideas para el ESP32',
        content: 'Integración con I2C y display OLED',
        tags: const ['hardware', 'esp32'],
        isPinned: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      NoteItem(
        id: '2',
        title: 'Lista de compras semanal',
        content: 'Frutas, verduras, café',
        tags: const ['hogar'],
        isPinned: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteListProvider.overrideWith(() => MockNoteListNotifier(sampleNotes)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NotesView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Ambas notas visibles inicialmente
    expect(find.text('Ideas para el ESP32'), findsOneWidget);
    expect(find.text('Lista de compras semanal'), findsOneWidget);
    expect(find.text('#hardware'), findsOneWidget);

    // Filtrar por fijadas
    await tester.tap(find.text('Fijadas'));
    await tester.pumpAndSettle();

    expect(find.text('Ideas para el ESP32'), findsOneWidget);
    expect(find.text('Lista de compras semanal'), findsNothing);

    // Volver a "Todas" y buscar
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'compras');
    await tester.pumpAndSettle();

    expect(find.text('Ideas para el ESP32'), findsNothing);
    expect(find.text('Lista de compras semanal'), findsOneWidget);
  });

  testWidgets('NotesView abre diálogo modal al pulsar "Nueva Nota"',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteListProvider.overrideWith(() => MockNoteListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NotesView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva Nota'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva Nota Cifrada'), findsOneWidget);
    expect(find.text('Título de la nota'), findsOneWidget);
    expect(find.text('Contenido (apuntes, ideas o texto enriquecido)'),
        findsOneWidget);
    expect(find.text('Etiquetas (separadas por comas)'), findsOneWidget);
    expect(find.text('Fijar esta nota al inicio'), findsOneWidget);
    expect(find.text('Crear Nota'), findsOneWidget);
  });
}

