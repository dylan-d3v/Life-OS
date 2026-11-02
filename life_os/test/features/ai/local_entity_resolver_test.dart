import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/ai/data/local_entity_resolver.dart';
import 'package:life_os/features/calendar/domain/calendar_event_item.dart';
import 'package:life_os/features/notes/domain/note_item.dart';
import 'package:life_os/features/projects/domain/project_item.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';

void main() {
  group('LocalEntityResolver - Normalización y Utilidades', () {
    test('normalize convierte a minúsculas y elimina acentos y signos', () {
      expect(
        LocalEntityResolver.normalize('¡Examen de MATEMÁTICAS, Física y Química!'),
        'examen de matematicas fisica y quimica',
      );
      expect(
        LocalEntityResolver.normalize('   Café   con   Leche...  '),
        'cafe con leche',
      );
    });

    test('tokenize descarta palabras vacías (stop words)', () {
      final tokens = LocalEntityResolver.tokenize('Comprar el pan en la panadería');
      expect(tokens, containsAll(['comprar', 'pan', 'panaderia']));
      expect(tokens, isNot(contains('el')));
      expect(tokens, isNot(contains('la')));
      expect(tokens, isNot(contains('en')));
    });

    test('levenshteinDistance calcula la distancia de edición correcta', () {
      expect(LocalEntityResolver.levenshteinDistance('gato', 'pato'), 1);
      expect(LocalEntityResolver.levenshteinDistance('cafe', 'cafe'), 0);
      expect(LocalEntityResolver.levenshteinDistance('examen', 'exame'), 1);
      expect(LocalEntityResolver.levenshteinDistance('examen', 'exmane'), 3);
    });
  });

  group('LocalEntityResolver - Algoritmo de Puntuación (computeScore)', () {
    test('Coincidencia exacta devuelve score 100', () {
      final score = LocalEntityResolver.computeScore(
        'Comprar café tostado',
        'comprar cafe tostado',
      );
      expect(score, 100.0);
    });

    test('Coincidencia por prefijo devuelve score alto (>= 80)', () {
      final score = LocalEntityResolver.computeScore(
        'Comprar café',
        'Comprar café tostado colombiano para la oficina',
      );
      expect(score, greaterThanOrEqualTo(80.0));
    });

    test('Coincidencia por subcadena devuelve score adecuado (>= 68)', () {
      final score = LocalEntityResolver.computeScore(
        'satélite ESP32',
        'Diseño del circuito hardware satélite ESP32 para Kev',
      );
      expect(score, greaterThanOrEqualTo(68.0));
    });

    test('Intersección de tokens resuelve con palabras vacías interpuestas', () {
      final score = LocalEntityResolver.computeScore(
        'examen de matematicas',
        'Examen final presencial Matemáticas 2026',
      );
      expect(score, greaterThanOrEqualTo(50.0));
    });

    test('Rechaza consultas completamente no relacionadas devolviendo 0 o < 40', () {
      final score = LocalEntityResolver.computeScore(
        'comprar pan en la esquina',
        'Reunión de balance financiero anual con contabilidad',
      );
      expect(score, lessThan(40.0));
    });
  });

  group('LocalEntityResolver - Búsqueda en Entidades de Life-OS', () {
    test('findBestMatch localiza la tarea correcta entre una lista', () {
      final tasks = [
        TaskItem(
          id: '1',
          title: 'Pagar servicio de internet y luz',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TaskItem(
          id: '2',
          title: 'Comprar café tostado en grano',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TaskItem(
          id: '3',
          title: 'Revisar pull request de Flutter',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final match = LocalEntityResolver.findBestMatch<TaskItem>(
        query: 'comprar el cafe',
        items: tasks,
        titleExtractor: (t) => t.title,
      );

      expect(match, isNotNull);
      expect(match!.id, '2');
      expect(match.title, 'Comprar café tostado en grano');
    });

    test('findBestMatch localiza nota por tema o título parcial', () {
      final notes = [
        NoteItem(
          id: 'n1',
          title: 'Receta de cocina italiana',
          content: 'Pasta y salsa',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        NoteItem(
          id: 'n2',
          title: 'Arquitectura del Satélite ESP32',
          content: 'I2S y micrófono INMP441',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final match = LocalEntityResolver.findBestMatch<NoteItem>(
        query: 'satelite esp32',
        items: notes,
        titleExtractor: (n) => n.title,
      );

      expect(match, isNotNull);
      expect(match!.id, 'n2');
    });

    test('findBestMatch localiza proyecto por nombre con mayúsculas/minúsculas diferentes', () {
      final projects = [
        ProjectItem(
          id: 'p1',
          name: 'Life-OS & Asistente Kev',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ProjectItem(
          id: 'p2',
          name: 'Remodelación de Casa',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final match = LocalEntityResolver.findBestMatch<ProjectItem>(
        query: 'life os',
        items: projects,
        titleExtractor: (p) => p.name,
      );

      expect(match, isNotNull);
      expect(match!.id, 'p1');
    });

    test('findBestMatch localiza evento de calendario para reprogramación', () {
      final now = DateTime.now();
      final events = [
        CalendarEventItem(
          id: 'e1',
          title: 'Consulta Médica General',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          createdAt: now,
          updatedAt: now,
        ),
        CalendarEventItem(
          id: 'e2',
          title: 'Examen de Matemáticas',
          location: 'CEN',
          category: 'Estudios',
          startTime: now.add(const Duration(days: 3)),
          endTime: now.add(const Duration(days: 3, hours: 2)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final match = LocalEntityResolver.findBestMatch<CalendarEventItem>(
        query: 'examen matematicas',
        items: events,
        titleExtractor: (e) => e.title,
      );

      expect(match, isNotNull);
      expect(match!.id, 'e2');
      expect(match.location, 'CEN');
    });

    test('rankMatches devuelve los elementos ordenados por relevancia descendente', () {
      final tasks = [
        TaskItem(
          id: '1',
          title: 'Comprar pan',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TaskItem(
          id: '2',
          title: 'Comprar pan dulce con canela',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TaskItem(
          id: '3',
          title: 'Limpiar el garage',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final ranked = LocalEntityResolver.rankMatches<TaskItem>(
        query: 'comprar pan',
        items: tasks,
        titleExtractor: (t) => t.title,
      );

      expect(ranked.length, 2);
      expect(ranked[0].item.id, '1'); // Exact match
      expect(ranked[0].score, 100.0);
      expect(ranked[1].item.id, '2'); // Prefix match
      expect(ranked[1].score, lessThan(100.0));
    });

    test('Retorna null si no existe ningún elemento que alcance el umbral mínimo', () {
      final tasks = [
        TaskItem(
          id: '1',
          title: 'Estudiar para el examen de inglés',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final match = LocalEntityResolver.findBestMatch<TaskItem>(
        query: 'comprar pizza hawaiana',
        items: tasks,
        titleExtractor: (t) => t.title,
      );

      expect(match, isNull);
    });
  });
}
