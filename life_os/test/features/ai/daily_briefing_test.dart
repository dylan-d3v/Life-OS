import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/features/ai/data/daily_briefing_service.dart';
import 'package:life_os/features/ai/domain/daily_briefing.dart';
import 'package:life_os/features/ai/presentation/ai_providers.dart';
import 'package:life_os/features/ai/presentation/widgets/daily_briefing_card.dart';
import 'package:life_os/features/calendar/data/calendar_repository.dart';
import 'package:life_os/features/calendar/domain/calendar_event_item.dart';
import 'package:life_os/features/finance/data/finance_repository.dart';
import 'package:life_os/features/finance/domain/finance_transaction_item.dart';
import 'package:life_os/features/tasks/data/task_repository.dart';
import 'package:life_os/features/tasks/domain/task_item.dart';

// =============================================================================
// Fakes de prueba
// =============================================================================

class FakeTaskRepoForBriefing extends TaskRepository {
  final List<TaskItem> tasks;
  FakeTaskRepoForBriefing(this.tasks, {required super.encryptionService, required super.vault});

  @override
  Future<List<TaskItem>> fetchTasks() async => tasks;
}

class FakeCalendarRepoForBriefing extends CalendarRepository {
  final List<CalendarEventItem> events;
  FakeCalendarRepoForBriefing(this.events, {required super.encryptionService, required super.vault});

  @override
  Future<List<CalendarEventItem>> fetchEvents() async => events;
}

class FakeFinanceRepoForBriefing extends FinanceRepository {
  final List<FinanceTransactionItem> txs;
  FakeFinanceRepoForBriefing(this.txs, {required super.encryptionService, required super.vault});

  @override
  Future<List<FinanceTransactionItem>> fetchTransactions() async => txs;
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late EncryptionService encryptionService;
  late KeyVaultService vault;

  setUp(() {
    encryptionService = EncryptionService();
    vault = KeyVaultService();
    vault.setActiveKey(SecretKey(Uint8List(32)));
  });

  group('DailyBriefingService Tests', () {
    test('retorna estado bloqueado si la bóveda no tiene clave activa', () async {
      vault.lockVault();

      final service = DailyBriefingService(
        taskRepository: FakeTaskRepoForBriefing([], encryptionService: encryptionService, vault: vault),
        calendarRepository: FakeCalendarRepoForBriefing([], encryptionService: encryptionService, vault: vault),
        financeRepository: FakeFinanceRepoForBriefing([], encryptionService: encryptionService, vault: vault),
        vault: vault,
      );

      final briefing = await service.generateBriefing();

      expect(briefing.isLocked, isTrue);
      expect(briefing.formattedSummary, contains('Bóveda de seguridad bloqueada'));
      expect(briefing.ttsMessage, contains('Bóveda bloqueada'));
    });

    test('agrega y clasifica correctamente tareas, eventos y finanzas del día', () async {
      final now = DateTime(2026, 11, 1, 9, 0);

      final tasks = [
        TaskItem(
          id: 't1',
          title: 'Estudiar para examen',
          status: TaskStatus.todo,
          priority: 4, // Urgente
          createdAt: now,
          updatedAt: now,
        ),
        TaskItem(
          id: 't2',
          title: 'Comprar víveres',
          status: TaskStatus.inProgress,
          priority: 2, // Normal
          createdAt: now,
          updatedAt: now,
        ),
        TaskItem(
          id: 't3',
          title: 'Tarea ya hecha',
          status: TaskStatus.done,
          priority: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final events = [
        CalendarEventItem(
          id: 'e1',
          title: 'Reunión de proyecto',
          startTime: DateTime(2026, 11, 1, 14, 0),
          endTime: DateTime(2026, 11, 1, 15, 0),
          createdAt: now,
          updatedAt: now,
        ),
        CalendarEventItem(
          id: 'e2',
          title: 'Evento de mañana',
          startTime: DateTime(2026, 11, 2, 10, 0),
          endTime: DateTime(2026, 11, 2, 11, 0),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final txs = [
        FinanceTransactionItem(
          id: 'f1',
          type: TransactionType.expense,
          amount: 25.50,
          transactionDate: DateTime(2026, 11, 1, 12, 0),
          category: 'Alimentación',
          createdAt: now,
          updatedAt: now,
        ),
        FinanceTransactionItem(
          id: 'f2',
          type: TransactionType.income,
          amount: 100.0,
          transactionDate: DateTime(2026, 11, 1, 10, 0),
          category: 'Freelance',
          createdAt: now,
          updatedAt: now,
        ),
        FinanceTransactionItem(
          id: 'f3',
          type: TransactionType.expense,
          amount: 50.0,
          transactionDate: DateTime(2026, 10, 31, 10, 0), // Ayer
          category: 'Otros',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final service = DailyBriefingService(
        taskRepository: FakeTaskRepoForBriefing(tasks, encryptionService: encryptionService, vault: vault),
        calendarRepository: FakeCalendarRepoForBriefing(events, encryptionService: encryptionService, vault: vault),
        financeRepository: FakeFinanceRepoForBriefing(txs, encryptionService: encryptionService, vault: vault),
        vault: vault,
      );

      final briefing = await service.generateBriefing(forDate: now);

      expect(briefing.isLocked, isFalse);
      expect(briefing.pendingTasks.length, 2);
      expect(briefing.urgentTasks.length, 1);
      expect(briefing.todayEvents.length, 1);
      expect(briefing.todayEvents.first.title, 'Reunión de proyecto');
      expect(briefing.todayExpenses, 25.50);
      expect(briefing.todayIncome, 100.0);

      // Verificamos resumen textual y TTS
      expect(briefing.formattedSummary, contains('2 tarea(s) pendiente(s)'));
      expect(briefing.formattedSummary, contains('1 de alta prioridad'));
      expect(briefing.formattedSummary, contains('Reunión de proyecto'));
      expect(briefing.formattedSummary, contains('\$25.50'));

      expect(briefing.ttsMessage, contains('Tienes 2 tareas pendientes, 1 urgentes'));
      expect(briefing.ttsMessage, contains('1 eventos hoy'));
    });
  });

  group('DailyBriefingCard Widget Tests', () {
    testWidgets('renderiza tarjeta con métricas y botón de Kev', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime(2026, 11, 1);
      final fakeBriefing = DailyBriefing(
        date: now,
        pendingTasks: [
          TaskItem(id: '1', title: 'T1', status: TaskStatus.todo, createdAt: now, updatedAt: now),
        ],
        urgentTasks: [
          TaskItem(id: '1', title: 'T1', priority: 3, status: TaskStatus.todo, createdAt: now, updatedAt: now),
        ],
        todayEvents: [
          CalendarEventItem(id: '1', title: 'E1', startTime: now, endTime: now, createdAt: now, updatedAt: now),
        ],
        todayExpenses: 15.0,
        formattedSummary: '📋 Resumen: 1 tarea pendiente y 1 evento hoy.',
        ttsMessage: 'Tienes 1 tarea pendiente y 1 evento hoy.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyBriefingProvider.overrideWith((ref) => Future.value(fakeBriefing)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: DailyBriefingCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificamos encabezado
      expect(find.text('Briefing Diario Kev'), findsOneWidget);
      expect(find.text('Kev (Ctrl + K)'), findsOneWidget);

      // Verificamos píldoras de métricas
      expect(find.text('1 Tareas pendientes'), findsOneWidget);
      expect(find.text('(1 urgentes)'), findsOneWidget);
      expect(find.text('1 Eventos hoy'), findsOneWidget);
      expect(find.text('Gastos hoy: \$15.00'), findsOneWidget);

      // Verificamos texto de resumen
      expect(find.text('📋 Resumen: 1 tarea pendiente y 1 evento hoy.'), findsOneWidget);
    });

    testWidgets('muestra mensaje de advertencia si la bóveda está bloqueada', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final lockedBriefing = DailyBriefing.locked(DateTime.now());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyBriefingProvider.overrideWith((ref) => Future.value(lockedBriefing)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: DailyBriefingCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Briefing Diario Kev'), findsOneWidget);
      expect(find.text('Bóveda de seguridad bloqueada. Inicia sesión con tu clave maestra para consultar tu resumen.'), findsOneWidget);
    });
  });
}

