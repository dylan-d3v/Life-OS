import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/finance/domain/finance_transaction_item.dart';
import 'package:life_os/features/finance/presentation/finance_provider.dart';
import 'package:life_os/features/finance/presentation/finance_view.dart';

class MockFinanceTransactionListNotifier
    extends FinanceTransactionListNotifier {
  final List<FinanceTransactionItem> _initialItems;

  MockFinanceTransactionListNotifier([this._initialItems = const []]);

  @override
  Future<List<FinanceTransactionItem>> build() async => _initialItems;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> deleteTransaction(String id) async {
    state = state.whenData(
      (list) => list.where((i) => i.id != id).toList(),
    );
  }
}

void main() {
  testWidgets('FinanceView muestra tarjetas de resumen y estado vacío inicial',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeTransactionListProvider
              .overrideWith(() => MockFinanceTransactionListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FinanceView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Finanzas Personales'), findsOneWidget);
    expect(find.text('Nueva Transacción'), findsOneWidget);
    expect(find.text('Balance Neto'), findsOneWidget);
    expect(find.text('Total Ingresos'), findsOneWidget);
    expect(find.text('Total Gastos'), findsOneWidget);
    expect(find.textContaining('No tienes movimientos'), findsOneWidget);
  });

  testWidgets('FinanceView renderiza métricas calculadas y filtra por tipo',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final sampleTransactions = [
      FinanceTransactionItem(
        id: '1',
        type: TransactionType.income,
        amount: 2000.0,
        category: 'Nómina',
        notes: 'Sueldo empresa',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      FinanceTransactionItem(
        id: '2',
        type: TransactionType.expense,
        amount: 350.0,
        category: 'Supermercado',
        notes: 'Compras del mes',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeTransactionListProvider.overrideWith(
              () => MockFinanceTransactionListNotifier(sampleTransactions)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FinanceView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Validar métricas en tarjetas de resumen: Balance = 2000 - 350 = 1650
    expect(find.text('\$1,650.00'), findsOneWidget);
    expect(find.text('+\$2,000.00'), findsOneWidget);
    expect(find.text('-\$350.00'), findsOneWidget);

    // Ambas transacciones visibles en filtro "Todas"
    expect(find.text('Nómina'), findsOneWidget);
    expect(find.text('Supermercado'), findsOneWidget);

    // Filtrar por "Gastos"
    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();

    expect(find.text('Nómina'), findsNothing);
    expect(find.text('Supermercado'), findsOneWidget);

    // Filtrar por "Ingresos"
    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();

    expect(find.text('Nómina'), findsOneWidget);
    expect(find.text('Supermercado'), findsNothing);
  });

  testWidgets('FinanceView abre diálogo modal al pulsar "Nueva Transacción"',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeTransactionListProvider
              .overrideWith(() => MockFinanceTransactionListNotifier([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FinanceView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva Transacción'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva Transacción Cifrada'), findsOneWidget);
    expect(find.text('Monto (\$ USD)'), findsOneWidget);
    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('Registrar'), findsOneWidget);
  });
}

