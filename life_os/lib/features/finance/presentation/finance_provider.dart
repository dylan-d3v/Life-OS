import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/supabase_providers.dart';
import '../data/finance_repository.dart';
import '../domain/finance_transaction_item.dart';

// =============================================================================
// Repositorio
// =============================================================================

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(
    client: ref.watch(supabaseClientProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    vault: ref.watch(keyVaultServiceProvider),
  );
});

// =============================================================================
// Filtro Activo
// =============================================================================

enum FinanceFilter { all, expense, income, transfer }

class FinanceFilterNotifier extends Notifier<FinanceFilter> {
  @override
  FinanceFilter build() => FinanceFilter.all;

  void setFilter(FinanceFilter filter) {
    state = filter;
  }
}

final financeFilterProvider =
    NotifierProvider<FinanceFilterNotifier, FinanceFilter>(
  FinanceFilterNotifier.new,
);

// =============================================================================
// Lista de Transacciones
// =============================================================================

class FinanceTransactionListNotifier
    extends AsyncNotifier<List<FinanceTransactionItem>> {
  @override
  Future<List<FinanceTransactionItem>> build() => _loadTransactions();

  Future<List<FinanceTransactionItem>> _loadTransactions() async {
    final repo = ref.read(financeRepositoryProvider);
    return repo.fetchTransactions();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadTransactions);
  }

  Future<void> addTransaction({
    required TransactionType type,
    required double amount,
    required DateTime transactionDate,
    String currency = 'USD',
    String category = 'General',
    String notes = '',
    String? fromAccount,
    String? toAccount,
  }) async {
    final repo = ref.read(financeRepositoryProvider);
    final newItem = await repo.createTransaction(
      type: type,
      amount: amount,
      transactionDate: transactionDate,
      currency: currency,
      category: category,
      notes: notes,
      fromAccount: fromAccount,
      toAccount: toAccount,
    );

    state = state.whenData((list) {
      final updated = [newItem, ...list];
      updated.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      return updated;
    });
  }

  Future<void> updateTransaction(FinanceTransactionItem item) async {
    final repo = ref.read(financeRepositoryProvider);
    await repo.updateTransaction(item);

    state = state.whenData((list) {
      final updated = list.map((i) => i.id == item.id ? item : i).toList();
      updated.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      return updated;
    });
  }

  Future<void> deleteTransaction(String id) async {
    final repo = ref.read(financeRepositoryProvider);

    state = state.whenData(
      (list) => list.where((i) => i.id != id).toList(),
    );

    await repo.softDeleteTransaction(id);
  }
}

final financeTransactionListProvider = AsyncNotifierProvider<
    FinanceTransactionListNotifier, List<FinanceTransactionItem>>(
  FinanceTransactionListNotifier.new,
);

/// Proveedor filtrado según la pestaña seleccionada.
final filteredFinanceTransactionsProvider =
    Provider<AsyncValue<List<FinanceTransactionItem>>>((ref) {
  final filter = ref.watch(financeFilterProvider);
  final txsAsync = ref.watch(financeTransactionListProvider);

  return txsAsync.whenData((list) {
    switch (filter) {
      case FinanceFilter.all:
        return list;
      case FinanceFilter.expense:
        return list.where((i) => i.type == TransactionType.expense).toList();
      case FinanceFilter.income:
        return list.where((i) => i.type == TransactionType.income).toList();
      case FinanceFilter.transfer:
        return list.where((i) => i.type == TransactionType.transfer).toList();
    }
  });
});

/// Proveedor de resumen financiero computado en local tras descifrar los montos.
final financeSummaryProvider = Provider<AsyncValue<FinanceSummary>>((ref) {
  final txsAsync = ref.watch(financeTransactionListProvider);

  return txsAsync.whenData((list) {
    return FinanceSummary.fromTransactions(list);
  });
});

