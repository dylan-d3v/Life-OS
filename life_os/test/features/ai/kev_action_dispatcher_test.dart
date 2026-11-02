import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/features/ai/data/kev_action_dispatcher.dart';
import 'package:life_os/features/ai/domain/kev_action.dart';
import 'package:life_os/features/calendar/data/calendar_repository.dart';
import 'package:life_os/features/calendar/domain/calendar_event_item.dart';
import 'package:life_os/features/finance/data/finance_repository.dart';
import 'package:life_os/features/finance/domain/finance_transaction_item.dart';
import 'package:life_os/features/notes/data/note_repository.dart';
import 'package:life_os/features/notes/domain/note_item.dart';
import 'package:life_os/features/projects/data/project_repository.dart';
import 'package:life_os/features/projects/domain/project_item.dart';
import 'package:life_os/features/tasks/data/task_repository.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';

// =============================================================================
// Fakes para Repositorios
// =============================================================================

class FakeTaskRepository extends TaskRepository {
  TaskItem? lastCreatedTask;
  String? lastEncryptedData;
  final List<TaskItem> mockTasks;
  bool shouldThrow = false;

  FakeTaskRepository({
    required super.encryptionService,
    required super.vault,
    this.mockTasks = const [],
  });

  @override
  Future<TaskItem> createTask({
    required String title,
    String notes = '',
    int priority = 2,
    DateTime? dueDate,
    String? projectId,
  }) async {
    if (shouldThrow) {
      throw Exception('Error simulado en base de datos de tareas');
    }

    // Simulamos el cifrado E2EE real con AES-256-GCM
    final sensitiveData = {'title': title, 'notes': notes};
    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );
    lastEncryptedData = payload.serialize();

    final task = TaskItem(
      id: 'task-fake-id',
      projectId: projectId,
      title: title,
      notes: notes,
      status: TaskStatus.todo,
      priority: priority,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    lastCreatedTask = task;
    return task;
  }

  @override
  Future<List<TaskItem>> fetchTasks() async => mockTasks;
}

class FakeNoteRepository extends NoteRepository {
  NoteItem? lastCreatedNote;
  String? lastEncryptedData;

  FakeNoteRepository({
    required super.encryptionService,
    required super.vault,
  });

  @override
  Future<NoteItem> createNote({
    required String title,
    String content = '',
    List<String> tags = const [],
    bool isPinned = false,
    String? projectId,
  }) async {
    final sensitive = {'title': title, 'content': content, 'tags': tags};
    final payload = await encryptionService.encryptJson(
      sensitive,
      vault.activeKey,
    );
    lastEncryptedData = payload.serialize();

    final note = NoteItem(
      id: 'note-fake-id',
      projectId: projectId,
      title: title,
      content: content,
      tags: tags,
      isPinned: isPinned,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    lastCreatedNote = note;
    return note;
  }
}

class FakeProjectRepository extends ProjectRepository {
  ProjectItem? lastCreatedProject;
  final List<ProjectItem> mockProjects;

  FakeProjectRepository({
    required super.encryptionService,
    required super.vault,
    this.mockProjects = const [],
  });

  @override
  Future<ProjectItem> createProject({
    required String name,
    String description = '',
    String colorHex = '#0284C7',
    ProjectStatus status = ProjectStatus.active,
  }) async {
    final project = ProjectItem(
      id: 'project-fake-id',
      name: name,
      description: description,
      colorHex: colorHex,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    lastCreatedProject = project;
    return project;
  }

  @override
  Future<List<ProjectItem>> fetchProjects() async => mockProjects;
}

class FakeCalendarRepository extends CalendarRepository {
  CalendarEventItem? lastCreatedEvent;
  final List<CalendarEventItem> mockEvents;

  FakeCalendarRepository({
    required super.encryptionService,
    required super.vault,
    this.mockEvents = const [],
  });

  @override
  Future<CalendarEventItem> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String description = '',
    String location = '',
    String category = 'Personal',
  }) async {
    final event = CalendarEventItem(
      id: 'event-fake-id',
      title: title,
      description: description,
      location: location,
      category: category,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    lastCreatedEvent = event;
    return event;
  }

  @override
  Future<List<CalendarEventItem>> fetchEvents() async => mockEvents;
}

class FakeFinanceRepository extends FinanceRepository {
  FinanceTransactionItem? lastCreatedTransaction;
  String? lastEncryptedData;

  FakeFinanceRepository({
    required super.encryptionService,
    required super.vault,
  });

  @override
  Future<FinanceTransactionItem> createTransaction({
    required TransactionType type,
    required double amount,
    required DateTime transactionDate,
    String currency = 'USD',
    String category = 'General',
    String notes = '',
    String? fromAccount,
    String? toAccount,
  }) async {
    final sensitive = {
      'amount': amount,
      'currency': currency,
      'category': category,
      'notes': notes,
    };
    final payload = await encryptionService.encryptJson(
      sensitive,
      vault.activeKey,
    );
    lastEncryptedData = payload.serialize();

    final tx = FinanceTransactionItem(
      id: 'finance-fake-id',
      type: type,
      amount: amount,
      currency: currency,
      category: category,
      notes: notes,
      fromAccount: fromAccount,
      toAccount: toAccount,
      transactionDate: transactionDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    lastCreatedTransaction = tx;
    return tx;
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late EncryptionService encryptionService;
  late KeyVaultService vault;
  late FakeTaskRepository taskRepo;
  late FakeNoteRepository noteRepo;
  late FakeProjectRepository projectRepo;
  late FakeCalendarRepository calendarRepo;
  late FakeFinanceRepository financeRepo;
  late KevActionDispatcher dispatcher;

  setUp(() {
    encryptionService = EncryptionService();
    vault = KeyVaultService();

    // Desbloqueamos la bóveda con una clave fija de 32 bytes para los tests
    final dummyKey = Uint8List.fromList(List.generate(32, (i) => i));
    vault.setActiveKey(SecretKey(dummyKey));

    taskRepo = FakeTaskRepository(
      encryptionService: encryptionService,
      vault: vault,
    );
    noteRepo = FakeNoteRepository(
      encryptionService: encryptionService,
      vault: vault,
    );
    projectRepo = FakeProjectRepository(
      encryptionService: encryptionService,
      vault: vault,
    );
    calendarRepo = FakeCalendarRepository(
      encryptionService: encryptionService,
      vault: vault,
    );
    financeRepo = FakeFinanceRepository(
      encryptionService: encryptionService,
      vault: vault,
    );

    dispatcher = KevActionDispatcher(
      taskRepository: taskRepo,
      noteRepository: noteRepo,
      projectRepository: projectRepo,
      calendarRepository: calendarRepo,
      financeRepository: financeRepo,
      vault: vault,
    );
  });

  group('KevActionDispatcher Tests', () {
    test('rechaza la acción si la bóveda está bloqueada', () async {
      vault.lockVault(); // Bloqueamos la bóveda

      const action = CreateTaskAction(title: 'Tarea sin clave');
      final result = await dispatcher.dispatch(action);

      expect(result.success, isFalse);
      expect(result.error, 'KeyVault locked');
      expect(result.userMessage, contains('bóveda de seguridad está bloqueada'));
      expect(taskRepo.lastCreatedTask, isNull);
    });

    test('despacha CreateTaskAction y cifra título y notas', () async {
      final dueDate = DateTime(2026, 11, 10);
      final action = CreateTaskAction(
        title: 'Comprar café',
        notes: 'Grano tostado medio',
        priority: 3,
        dueDate: dueDate,
      );

      final result = await dispatcher.dispatch(action);

      expect(result.success, isTrue);
      expect(result.actionType, 'create_task');
      expect(result.entityId, 'task-fake-id');
      expect(result.userMessage, contains('Tarea agregada: "Comprar café"'));
      expect(result.userMessage, contains('10/11/2026'));

      expect(taskRepo.lastCreatedTask?.title, 'Comprar café');
      expect(taskRepo.lastCreatedTask?.priority, 3);
      expect(taskRepo.lastEncryptedData, isNotNull);

      // Verificamos que los datos cifrados se puedan descifrar con la clave de la bóveda
      final payload = EncryptedPayload.deserialize(taskRepo.lastEncryptedData!);
      final decrypted = await encryptionService.decryptJson(payload, vault.activeKey);
      expect(decrypted['title'], 'Comprar café');
      expect(decrypted['notes'], 'Grano tostado medio');
    });

    test('despacha CreateTaskAction resolviendo el ID de proyecto por nombre', () async {
      final now = DateTime.now();
      final projects = [
        ProjectItem(
          id: 'proj-1',
          name: 'Hardware ESP32',
          createdAt: now,
          updatedAt: now,
        ),
        ProjectItem(
          id: 'proj-2',
          name: 'Universidad',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      projectRepo = FakeProjectRepository(
        encryptionService: encryptionService,
        vault: vault,
        mockProjects: projects,
      );

      dispatcher = KevActionDispatcher(
        taskRepository: taskRepo,
        noteRepository: noteRepo,
        projectRepository: projectRepo,
        calendarRepository: calendarRepo,
        financeRepository: financeRepo,
        vault: vault,
      );

      const action = CreateTaskAction(
        title: 'Diseñar PCB',
        projectName: 'Hardware ESP32',
      );

      final result = await dispatcher.dispatch(action);

      expect(result.success, isTrue);
      expect(taskRepo.lastCreatedTask?.projectId, 'proj-1');
    });

    test('despacha CreateNoteAction y almacena etiquetas y contenido', () async {
      const action = CreateNoteAction(
        title: 'Idea de negocio',
        content: 'Venta de gadgets Life-OS',
        tags: ['startup', 'iot'],
        isPinned: true,
      );

      final result = await dispatcher.dispatch(action);

      expect(result.success, isTrue);
      expect(result.actionType, 'create_note');
      expect(result.userMessage, contains('Nota guardada: "Idea de negocio"'));
      expect(result.userMessage, contains('startup, iot'));

      expect(noteRepo.lastCreatedNote?.title, 'Idea de negocio');
      expect(noteRepo.lastCreatedNote?.isPinned, isTrue);
      expect(noteRepo.lastCreatedNote?.tags, ['startup', 'iot']);

      final payload = EncryptedPayload.deserialize(noteRepo.lastEncryptedData!);
      final decrypted = await encryptionService.decryptJson(payload, vault.activeKey);
      expect(decrypted['title'], 'Idea de negocio');
      expect(decrypted['content'], 'Venta de gadgets Life-OS');
    });

    test('despacha CreateProjectAction con color y estado', () async {
      const action = CreateProjectAction(
        name: 'Tesis de Grado',
        description: 'Desarrollo de agente autónomo',
        colorHex: '#10B981',
        status: ProjectStatus.active,
      );

      final result = await dispatcher.dispatch(action);

      expect(result.success, isTrue);
      expect(result.actionType, 'create_project');
      expect(result.userMessage, contains('Proyecto creado: "Tesis de Grado"'));

      expect(projectRepo.lastCreatedProject?.name, 'Tesis de Grado');
      expect(projectRepo.lastCreatedProject?.colorHex, '#10B981');
    });

    test('despacha CreateCalendarEventAction formateando fecha y ubicación', () async {
      final start = DateTime(2026, 11, 5, 15, 30);
      final end = DateTime(2026, 11, 5, 16, 30);

      final action = CreateCalendarEventAction(
        title: 'Reunión de equipo',
        startTime: start,
        endTime: end,
        location: 'Google Meet',
      );

      final result = await dispatcher.dispatch(action);

      expect(result.success, isTrue);
      expect(result.actionType, 'create_calendar_event');
      expect(result.userMessage, contains('Evento agendado: "Reunión de equipo"'));
      expect(result.userMessage, contains('Google Meet'));
      expect(result.userMessage, contains('05/11/2026 15:30'));

      expect(calendarRepo.lastCreatedEvent?.title, 'Reunión de equipo');
      expect(calendarRepo.lastCreatedEvent?.location, 'Google Meet');
    });

    test('despacha LogFinanceAction con formato monetario y categoría', () async {
      final txDate = DateTime(2026, 10, 31);
      final action = LogFinanceAction(
        type: TransactionType.expense,
        amount: 45.50,
        currency: 'USD',
        category: 'Restaurante',
        transactionDate: txDate,
      );

      final result = await dispatcher.dispatch(action);

      expect(result.success, isTrue);
      expect(result.actionType, 'log_finance');
      expect(result.userMessage, contains('Gasto de USD \$45.50 registrado en "Restaurante"'));

      expect(financeRepo.lastCreatedTransaction?.amount, 45.50);
      expect(financeRepo.lastCreatedTransaction?.category, 'Restaurante');

      final payload = EncryptedPayload.deserialize(financeRepo.lastEncryptedData!);
      final decrypted = await encryptionService.decryptJson(payload, vault.activeKey);
      expect(decrypted['amount'], 45.50);
      expect(decrypted['category'], 'Restaurante');
    });

    test('despacha QueryAction y genera resumen de tareas y eventos pendientes', () async {
      final queryDate = DateTime(2026, 11, 1);

      taskRepo = FakeTaskRepository(
        encryptionService: encryptionService,
        vault: vault,
        mockTasks: [
          TaskItem(
            id: 't1',
            title: 'Tarea 1',
            status: TaskStatus.todo,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          TaskItem(
            id: 't2',
            title: 'Tarea 2',
            status: TaskStatus.done,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      calendarRepo = FakeCalendarRepository(
        encryptionService: encryptionService,
        vault: vault,
        mockEvents: [
          CalendarEventItem(
            id: 'e1',
            title: 'Evento Hoy',
            startTime: DateTime(2026, 11, 1, 10, 0),
            endTime: DateTime(2026, 11, 1, 11, 0),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      dispatcher = KevActionDispatcher(
        taskRepository: taskRepo,
        noteRepository: noteRepo,
        projectRepository: projectRepo,
        calendarRepository: calendarRepo,
        financeRepository: financeRepo,
        vault: vault,
      );

      final action = QueryAction(
        queryTopic: 'daily_briefing',
        targetDate: queryDate,
      );

      final result = await dispatcher.dispatch(action);

      expect(result.success, isTrue);
      expect(result.actionType, 'query_summary');
      expect(result.userMessage, contains('1 tareas pendientes'));
      expect(result.userMessage, contains('1 eventos agendados'));
    });

    test('despacha UnknownAction reportando fallo con la causa', () async {
      const action = UnknownAction(
        rawName: 'volar_avion',
        rawArguments: {'destino': 'Marte'},
        reason: 'Herramienta no soportada en Life-OS',
      );

      final result = await dispatcher.dispatch(action);

      expect(result.success, isFalse);
      expect(result.actionType, 'unknown');
      expect(result.error, contains('Herramienta no soportada'));
      expect(result.userMessage, contains('No pude determinar la acción a ejecutar'));
    });

    test('captura excepciones internas del repositorio sin colapsar', () async {
      taskRepo.shouldThrow = true;

      const action = CreateTaskAction(title: 'Tarea con error de red');
      final result = await dispatcher.dispatch(action);

      expect(result.success, isFalse);
      expect(result.actionType, 'create_task');
      expect(result.error, contains('Error simulado en base de datos'));
      expect(result.userMessage, contains('Ocurrió un error al ejecutar la acción'));
    });
  });
}
