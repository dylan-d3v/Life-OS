import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/projects/domain/project_item.dart';
import 'package:life_os/features/projects/presentation/projects_provider.dart';
import 'package:life_os/features/projects/presentation/projects_view.dart';

class MockProjectListNotifier extends ProjectListNotifier {
  final List<ProjectItem> _initialProjects;

  MockProjectListNotifier([this._initialProjects = const []]);

  @override
  Future<List<ProjectItem>> build() async => _initialProjects;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> updateStatus(String projectId, ProjectStatus newStatus) async {
    state = state.whenData((projects) {
      return projects.map((p) {
        if (p.id == projectId) return p.copyWith(status: newStatus);
        return p;
      }).toList();
    });
  }

  @override
  Future<void> deleteProject(String projectId) async {
    state = state.whenData(
      (projects) => projects.where((p) => p.id != projectId).toList(),
    );
  }
}

void main() {
  testWidgets('ProjectsView muestra encabezado, filtros y estado vacío inicial',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider
              .overrideWith(() => MockProjectListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProjectsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Proyectos y Metas'), findsOneWidget);
    expect(find.text('Nuevo Proyecto'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Activos'), findsOneWidget);
    expect(find.text('Pausados'), findsOneWidget);
    expect(find.text('Completados'), findsOneWidget);
    expect(find.textContaining('No tienes proyectos aún'), findsOneWidget);
  });

  testWidgets('ProjectsView muestra tarjetas de proyectos y filtra por estado',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleProjects = [
      ProjectItem(
        id: '1',
        name: 'MVP de Escritorio Flutter',
        description: 'Construcción de interfaz y capa E2EE',
        colorHex: '#0284C7',
        status: ProjectStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProjectItem(
        id: '2',
        name: 'Fase 2 de Base de Datos',
        description: 'Configuración de tablas y RLS en Supabase',
        colorHex: '#10B981',
        status: ProjectStatus.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider
              .overrideWith(() => MockProjectListNotifier(sampleProjects)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProjectsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Filtro "Todos" muestra ambos
    expect(find.text('MVP de Escritorio Flutter'), findsOneWidget);
    expect(find.text('Fase 2 de Base de Datos'), findsOneWidget);

    // Filtrar por "Activos"
    await tester.tap(find.text('Activos'));
    await tester.pumpAndSettle();

    expect(find.text('MVP de Escritorio Flutter'), findsOneWidget);
    expect(find.text('Fase 2 de Base de Datos'), findsNothing);

    // Filtrar por "Completados"
    await tester.tap(find.text('Completados'));
    await tester.pumpAndSettle();

    expect(find.text('MVP de Escritorio Flutter'), findsNothing);
    expect(find.text('Fase 2 de Base de Datos'), findsOneWidget);
  });

  testWidgets('ProjectsView abre diálogo modal al pulsar "Nuevo Proyecto"',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider
              .overrideWith(() => MockProjectListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProjectsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo Proyecto'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo Proyecto Cifrado'), findsOneWidget);
    expect(find.text('Nombre del proyecto'), findsOneWidget);
    expect(find.text('Descripción y objetivos'), findsOneWidget);
    expect(find.text('Color distintivo'), findsOneWidget);
    expect(find.text('Crear Proyecto'), findsOneWidget);
  });
}

