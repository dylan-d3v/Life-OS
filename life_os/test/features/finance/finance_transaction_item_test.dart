import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/crypto/crypto.dart';
import 'package:life_os/features/finance/domain/finance_transaction_item.dart';

void main() {
  group('FinanceTransactionItem Domain Tests', () {
    test('toEncryptedFieldsMap extrae y protege el monto numérico y detalles sensibles', () {
      final tx = FinanceTransactionItem(
        id: 'tx-001',
        type: TransactionType.expense,
        transactionDate: DateTime.parse('2026-10-30T10:00:00Z'),
        amount: 85.50,
        currency: 'USD',
        category: 'Alimentación',
        notes: 'Cena familiar de fin de semana',
        fromAccount: 'Cuenta Corriente',
        toAccount: 'Supermercado',
        createdAt: DateTime.parse('2026-10-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-10-30T10:00:00Z'),
      );

      final sensitive = tx.toEncryptedFieldsMap();

      expect(sensitive, {
        'amount': 85.50,
        'currency': 'USD',
        'category': 'Alimentación',
        'notes': 'Cena familiar de fin de semana',
        'from_account': 'Cuenta Corriente',
        'to_account': 'Supermercado',
      });
      expect(sensitive.containsKey('id'), isFalse);
      expect(sensitive.containsKey('type'), isFalse);
      expect(sensitive.containsKey('transaction_date'), isFalse);
    });

    test('fromDecryptedMap reconstruye FinanceTransactionItem con parsing numérico seguro', () {
      final row = {
        'id': 'tx-uuid-888',
        'type': 'income',
        'transaction_date': '2026-10-28T09:00:00Z',
        'created_at': '2026-10-28T09:00:00Z',
        'updated_at': '2026-10-28T09:00:00Z',
        'deleted_at': null,
      };

      final decryptedFields = {
        'amount': 2500.75,
        'currency': 'USD',
        'category': 'Salario',
        'notes': 'Pago de nómina mensual',
      };

      final item = FinanceTransactionItem.fromDecryptedMap(
        row: row,
        decryptedFields: decryptedFields,
      );

      expect(item.id, 'tx-uuid-888');
      expect(item.type, TransactionType.income);
      expect(item.amount, 2500.75);
      expect(item.currency, 'USD');
      expect(item.category, 'Salario');
      expect(item.notes, 'Pago de nómina mensual');
      expect(item.deletedAt, isNull);
    });

    test('FinanceSummary calcula balance neto, ingresos y gastos correctamente', () {
      final items = [
        FinanceTransactionItem(
          id: '1',
          type: TransactionType.income,
          transactionDate: DateTime.now(),
          amount: 3000.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinanceTransactionItem(
          id: '2',
          type: TransactionType.expense,
          transactionDate: DateTime.now(),
          amount: 1200.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinanceTransactionItem(
          id: '3',
          type: TransactionType.expense,
          transactionDate: DateTime.now(),
          amount: 300.50,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinanceTransactionItem(
          id: '4',
          type: TransactionType.transfer,
          transactionDate: DateTime.now(),
          amount: 500.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final summary = FinanceSummary.fromTransactions(items);

      expect(summary.totalIncome, 3000.0);
      expect(summary.totalExpense, 1500.50);
      expect(summary.netBalance, 1499.50);
      expect(summary.count, 4);
    });

    test('Flujo E2EE completo de Transacción: Cifrado -> Serialización -> Deserialización -> Descifrado', () async {
      final encryptionService = EncryptionService();
      final vault = KeyVaultService();
      final salt = KeyVaultService.generateSalt();
      final key = await vault.deriveKeyFromPassword(
        masterPassword: 'MasterPasswordSuperSegura2026!',
        salt: salt,
      );

      final originalTx = FinanceTransactionItem(
        id: 'tx-confidential-99',
        type: TransactionType.expense,
        transactionDate: DateTime.now(),
        amount: 4999.99,
        currency: 'USD',
        category: 'Honorarios Médicos Confidenciales',
        notes: 'Pago de cirugía privada',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Cifrar
      final sensitiveFields = originalTx.toEncryptedFieldsMap();
      final encryptedPayload = await encryptionService.encryptJson(sensitiveFields, key);
      final serializedPayload = encryptedPayload.serialize();

      // 2. Comprobar que en el payload de Supabase no hay texto legible ni montos
      expect(serializedPayload.contains('4999.99'), isFalse);
      expect(serializedPayload.contains('Honorarios Médicos'), isFalse);
      expect(serializedPayload.contains('cirugía'), isFalse);

      // 3. Deserializar y descifrar
      final deserialized = EncryptedPayload.deserialize(serializedPayload);
      final decrypted = await encryptionService.decryptJson(deserialized, key);

      // 4. Reconstruir
      final reconstructed = FinanceTransactionItem.fromDecryptedMap(
        row: {
          'id': originalTx.id,
          'type': originalTx.type.value,
          'transaction_date': originalTx.transactionDate.toIso8601String(),
          'created_at': originalTx.createdAt.toIso8601String(),
          'updated_at': originalTx.updatedAt.toIso8601String(),
        },
        decryptedFields: decrypted,
      );

      expect(reconstructed.id, originalTx.id);
      expect(reconstructed.amount, originalTx.amount);
      expect(reconstructed.category, originalTx.category);
      expect(reconstructed.notes, originalTx.notes);
      expect(reconstructed.type, originalTx.type);
    });
  });
}

