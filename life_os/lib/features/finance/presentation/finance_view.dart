import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/finance_transaction_item.dart';
import 'finance_provider.dart';

/// Vista principal del Módulo de Finanzas Personales con cifrado Zero-Knowledge.
class FinanceView extends ConsumerWidget {
  const FinanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTxs = ref.watch(filteredFinanceTransactionsProvider);
    final activeFilter = ref.watch(financeFilterProvider);
    final summaryAsync = ref.watch(financeSummaryProvider);

    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finanzas Personales',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Montos y categorías con privacidad absoluta Zero-Knowledge (AES-256-GCM)',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _openTransactionDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Transacción'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Tarjetas de Resumen Financiero ──
          summaryAsync.when(
            loading: () => const SizedBox(height: 80),
            error: (error, stack) => const SizedBox.shrink(),
            data: (summary) => _SummaryRow(summary: summary),
          ),
          const SizedBox(height: 20),

          // ── Filtros por Tipo ──
          Row(
            children: [
              _FilterChip(
                label: 'Todas',
                selected: activeFilter == FinanceFilter.all,
                onTap: () => ref
                    .read(financeFilterProvider.notifier)
                    .setFilter(FinanceFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Gastos',
                selected: activeFilter == FinanceFilter.expense,
                onTap: () => ref
                    .read(financeFilterProvider.notifier)
                    .setFilter(FinanceFilter.expense),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Ingresos',
                selected: activeFilter == FinanceFilter.income,
                onTap: () => ref
                    .read(financeFilterProvider.notifier)
                    .setFilter(FinanceFilter.income),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Transferencias',
                selected: activeFilter == FinanceFilter.transfer,
                onTap: () => ref
                    .read(financeFilterProvider.notifier)
                    .setFilter(FinanceFilter.transfer),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                tooltip: 'Recargar transacciones',
                onPressed: () =>
                    ref.read(financeTransactionListProvider.notifier).refresh(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Lista de Transacciones ──
          Expanded(
            child: filteredTxs.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 12),
                    const Text('Error al cargar finanzas',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(financeTransactionListProvider.notifier)
                          .refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return _buildEmptyState(activeFilter);
                }
                return ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _TransactionCard(
                      item: tx,
                      onEdit: () =>
                          _openTransactionDialog(context, ref, initialItem: tx),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(FinanceFilter filter) {
    final message = switch (filter) {
      FinanceFilter.all =>
        'No tienes movimientos registrados aún.\nRegistra tu primer ingreso o gasto cifrado.',
      FinanceFilter.expense => 'No tienes gastos registrados.',
      FinanceFilter.income => 'No tienes ingresos registrados.',
      FinanceFilter.transfer => 'No tienes transferencias registradas.',
    };

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTransactionDialog(BuildContext context, WidgetRef ref,
      {FinanceTransactionItem? initialItem}) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _TransactionEditorDialog(ref: ref, initialItem: initialItem),
    );
  }
}

// =============================================================================
// Widget: Fila de Resumen Financiero
// =============================================================================

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final FinanceSummary summary;

  String _formatMoney(double value) {
    return NumberFormat('#,##0.00').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = summary.netBalance >= 0;

    return Row(
      children: [
        // Balance Neto
        Expanded(
          child: _StatCard(
            title: 'Balance Neto',
            value: '\$${_formatMoney(summary.netBalance)}',
            color: isPositive
                ? const Color(0xFF22C55E)
                : const Color(0xFFEF4444),
            icon: isPositive
                ? Icons.account_balance
                : Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 14),

        // Total Ingresos
        Expanded(
          child: _StatCard(
            title: 'Total Ingresos',
            value: '+\$${_formatMoney(summary.totalIncome)}',
            color: const Color(0xFF22C55E),
            icon: Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 14),

        // Total Gastos
        Expanded(
          child: _StatCard(
            title: 'Total Gastos',
            value: '-\$${_formatMoney(summary.totalExpense)}',
            color: const Color(0xFFEF4444),
            icon: Icons.arrow_downward,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget: Chip de Filtro
// =============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? const Color(0xFF0284C7) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widget: Tarjeta de Transacción
// =============================================================================

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({
    required this.item,
    required this.onEdit,
  });

  final FinanceTransactionItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color, prefix) = switch (item.type) {
      TransactionType.income => (
          Icons.arrow_upward_rounded,
          const Color(0xFF22C55E),
          '+'
        ),
      TransactionType.expense => (
          Icons.arrow_downward_rounded,
          const Color(0xFFEF4444),
          '-'
        ),
      TransactionType.transfer => (
          Icons.swap_horiz_rounded,
          const Color(0xFF38BDF8),
          ''
        ),
    };

    final formattedAmount =
        '$prefix\$${NumberFormat('#,##0.00').format(item.amount)} ${item.currency}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Icono representativo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 14),

                // Categoría y notas
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.notes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.notes,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Fecha
                Text(
                  DateFormat('dd/MM/yyyy').format(item.transactionDate),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),

                // Monto destacado
                Text(
                  formattedAmount,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),

                // Botón eliminar
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Eliminar transacción',
                  splashRadius: 18,
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar transacción',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar el registro de "${item.category}" (\$${item.amount.toStringAsFixed(2)})?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(financeTransactionListProvider.notifier)
                  .deleteTransaction(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dialog: Editor de Transacción Financiera
// =============================================================================

class _TransactionEditorDialog extends ConsumerStatefulWidget {
  const _TransactionEditorDialog({
    required this.ref,
    this.initialItem,
  });

  final WidgetRef ref;
  final FinanceTransactionItem? initialItem;

  @override
  ConsumerState<_TransactionEditorDialog> createState() =>
      _TransactionEditorDialogState();
}

class _TransactionEditorDialogState
    extends ConsumerState<_TransactionEditorDialog> {
  late TransactionType _type;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _date;
  bool _isLoading = false;

  bool get _isEditing => widget.initialItem != null;

  static const _commonCategories = [
    'Alimentación',
    'Transporte',
    'Vivienda',
    'Servicios',
    'Salario',
    'Educación',
    'Salud',
    'Ocio',
    'Inversión',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialItem;
    _type = init?.type ?? TransactionType.expense;
    _amountCtrl = TextEditingController(
      text: init != null ? init.amount.toStringAsFixed(2) : '',
    );
    _categoryCtrl = TextEditingController(text: init?.category ?? 'General');
    _notesCtrl = TextEditingController(text: init?.notes ?? '');
    _date = init?.transactionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 20),
          const SizedBox(width: 8),
          Text(
            _isEditing
                ? 'Editar Transacción Cifrada'
                : 'Nueva Transacción Cifrada',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de Tipo
              Row(
                children: [
                  for (final t in TransactionType.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _type == t
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _type == t
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF334155),
                            ),
                          ),
                          child: Text(
                            t.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _type == t
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: _type == t
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Campo de Monto
              TextField(
                controller: _amountCtrl,
                autofocus: !_isEditing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto (\$ USD)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(
                      color: Color(0xFF38BDF8), fontSize: 20),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Campo de Categoría
              TextField(
                controller: _categoryCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Chips de categorías frecuentes
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _commonCategories.map((cat) {
                  return GestureDetector(
                    onTap: () => setState(() => _categoryCtrl.text = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        cat,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Fecha
              Row(
                children: [
                  const Text('Fecha:',
                      style:
                          TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(DateFormat('dd/MM/yyyy').format(_date)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Notas
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Notas / Detalles opcionales',
                  alignLabelWithHint: true,
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 14, color: Color(0xFF22C55E)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'El monto exacto, categoría y notas se cifran con AES-256-GCM. Supabase no puede conocer tu saldo ni gastos.',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Guardar Cambios' : 'Registrar'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un monto válido mayor a 0.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final category = _categoryCtrl.text.trim().isNotEmpty
        ? _categoryCtrl.text.trim()
        : 'General';

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updated = widget.initialItem!.copyWith(
          type: _type,
          amount: amount,
          category: category,
          notes: _notesCtrl.text.trim(),
          transactionDate: _date,
          updatedAt: DateTime.now(),
        );
        await ref
            .read(financeTransactionListProvider.notifier)
            .updateTransaction(updated);
      } else {
        await ref
            .read(financeTransactionListProvider.notifier)
            .addTransaction(
              type: _type,
              amount: amount,
              category: category,
              notes: _notesCtrl.text.trim(),
              transactionDate: _date,
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar transacción: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
