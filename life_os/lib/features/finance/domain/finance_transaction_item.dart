/// Modelo de dominio que representa una Transacción Financiera en Life-OS.
///
/// Principio Zero-Knowledge: El monto numérico ([amount]), la divisa ([currency]),
/// la categoría ([category]), las notas ([notes]) y las cuentas asociadas se
/// cifran localmente con AES-256-GCM antes de persistirse en Supabase.
///
/// La base de datos solo almacena el texto cifrado, la fecha y el tipo general
/// (ingreso/gasto/transferencia) para ordenamiento cronológico.
class FinanceTransactionItem {
  final String id;
  final TransactionType type;
  final DateTime transactionDate;
  final double amount;
  final String currency;
  final String category;
  final String notes;
  final String? fromAccount;
  final String? toAccount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const FinanceTransactionItem({
    required this.id,
    required this.type,
    required this.transactionDate,
    required this.amount,
    this.currency = 'USD',
    this.category = 'General',
    this.notes = '',
    this.fromAccount,
    this.toAccount,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  FinanceTransactionItem copyWith({
    String? id,
    TransactionType? type,
    DateTime? transactionDate,
    double? amount,
    String? currency,
    String? category,
    String? notes,
    String? fromAccount,
    String? toAccount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return FinanceTransactionItem(
      id: id ?? this.id,
      type: type ?? this.type,
      transactionDate: transactionDate ?? this.transactionDate,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Retorna un mapa con todos los datos financieros confidenciales que deben cifrarse.
  Map<String, dynamic> toEncryptedFieldsMap() {
    return {
      'amount': amount,
      'currency': currency,
      'category': category,
      'notes': notes,
      'from_account': fromAccount,
      'to_account': toAccount,
    };
  }

  /// Reconstruye una [FinanceTransactionItem] combinando los metadatos en claro
  /// con los campos financieros descifrados localmente.
  factory FinanceTransactionItem.fromDecryptedMap({
    required Map<String, dynamic> row,
    required Map<String, dynamic> decryptedFields,
  }) {
    final rawAmount = decryptedFields['amount'];
    final double parsedAmount;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      parsedAmount = double.tryParse(rawAmount) ?? 0.0;
    } else {
      parsedAmount = 0.0;
    }

    return FinanceTransactionItem(
      id: row['id'] as String,
      type: TransactionType.fromString(row['type'] as String),
      transactionDate: DateTime.parse(row['transaction_date'] as String),
      amount: parsedAmount,
      currency: decryptedFields['currency'] as String? ?? 'USD',
      category: decryptedFields['category'] as String? ?? 'General',
      notes: decryptedFields['notes'] as String? ?? '',
      fromAccount: decryptedFields['from_account'] as String?,
      toAccount: decryptedFields['to_account'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }
}

/// Tipos de transacción financiera permitidos por el CHECK constraint en Supabase.
enum TransactionType {
  expense('expense', 'Gasto'),
  income('income', 'Ingreso'),
  transfer('transfer', 'Transferencia');

  const TransactionType(this.value, this.label);

  final String value;
  final String label;

  factory TransactionType.fromString(String value) {
    return TransactionType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Resumen financiero calculado en local tras descifrar los montos.
class FinanceSummary {
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final int count;

  const FinanceSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.count,
  });

  factory FinanceSummary.fromTransactions(List<FinanceTransactionItem> list) {
    double income = 0.0;
    double expense = 0.0;

    for (final item in list) {
      if (item.type == TransactionType.income) {
        income += item.amount;
      } else if (item.type == TransactionType.expense) {
        expense += item.amount;
      }
    }

    return FinanceSummary(
      totalIncome: income,
      totalExpense: expense,
      netBalance: income - expense,
      count: list.length,
    );
  }
}

