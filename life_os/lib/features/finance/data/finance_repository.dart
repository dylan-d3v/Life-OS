import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/crypto/crypto.dart';
import '../domain/finance_transaction_item.dart';

/// Repositorio encargado de la persistencia de transacciones financieras con cifrado E2EE.
///
/// Protege con AES-256-GCM los montos numéricos, categorías y notas antes de sincronizar
/// con Supabase. Nadie en el backend puede inspeccionar montos ni hábitos de consumo.
class FinanceRepository {
  final SupabaseClient? client;
  final EncryptionService encryptionService;
  final KeyVaultService vault;

  static const _table = 'finance_transactions';

  FinanceRepository({
    this.client,
    required this.encryptionService,
    required this.vault,
  });

  /// Crea una nueva transacción cifrando el monto y datos descriptivos localmente.
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
    final supabase = _requireClient();
    final userId = _requireUserId();

    final sensitiveData = {
      'amount': amount,
      'currency': currency,
      'category': category,
      'notes': notes,
      'from_account': fromAccount,
      'to_account': toAccount,
    };

    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    final row = <String, dynamic>{
      'user_id': userId,
      'type': type.value,
      'transaction_date': transactionDate.toIso8601String(),
      'encrypted_data': payload.serialize(),
    };

    final response = await supabase
        .from(_table)
        .insert(row)
        .select()
        .single();

    return FinanceTransactionItem.fromDecryptedMap(
      row: response,
      decryptedFields: sensitiveData,
    );
  }

  /// Obtiene las transacciones activas ordenadas por fecha reciente y las descifra localmente.
  Future<List<FinanceTransactionItem>> fetchTransactions() async {
    final supabase = _requireClient();

    final rows = await supabase
        .from(_table)
        .select()
        .isFilter('deleted_at', null)
        .order('transaction_date', ascending: false);

    final transactions = <FinanceTransactionItem>[];
    for (final row in rows) {
      final encryptedString = row['encrypted_data'] as String;
      final payload = EncryptedPayload.deserialize(encryptedString);
      final decryptedFields = await encryptionService.decryptJson(
        payload,
        vault.activeKey,
      );
      transactions.add(FinanceTransactionItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      ));
    }

    return transactions;
  }

  /// Actualiza una transacción existente re-cifrando los datos confidenciales.
  Future<void> updateTransaction(FinanceTransactionItem item) async {
    final supabase = _requireClient();

    final sensitiveData = item.toEncryptedFieldsMap();
    final payload = await encryptionService.encryptJson(
      sensitiveData,
      vault.activeKey,
    );

    final updates = <String, dynamic>{
      'type': item.type.value,
      'transaction_date': item.transactionDate.toIso8601String(),
      'encrypted_data': payload.serialize(),
    };

    await supabase.from(_table).update(updates).eq('id', item.id);
  }

  /// Elimina una transacción de forma suave (soft delete).
  Future<void> softDeleteTransaction(String transactionId) async {
    final supabase = _requireClient();
    await supabase
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', transactionId);
  }

  // ---------------------------------------------------------------------------
  // Helpers internos
  // ---------------------------------------------------------------------------

  SupabaseClient _requireClient() {
    final c = client;
    if (c == null) {
      throw StateError('El cliente de Supabase no está inicializado.');
    }
    return c;
  }

  String _requireUserId() {
    final user = client?.auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }
    return user.id;
  }
}

