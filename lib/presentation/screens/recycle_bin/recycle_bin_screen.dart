import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/utils/date_formatter.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<Expense> _deletedExpenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeleted();
  }

  Future<void> _loadDeleted() async {
    final repo = context.read<ExpenseRepository>();
    final deleted = await repo.getDeletedExpenses();
    if (mounted) {
      setState(() {
        _deletedExpenses = deleted;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        actions: [
          if (_deletedExpenses.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Empty Recycle Bin',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Empty Recycle Bin?'),
                    content: const Text('This will permanently delete all items in the recycle bin.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: cs.error),
                        child: const Text('Empty Bin')
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  for (var expense in _deletedExpenses) {
                    await context.read<ExpenseProvider>().permanentlyDeleteExpense(expense.id!, reload: false);
                  }
                  await context.read<ExpenseProvider>().loadExpenses();
                  await _loadDeleted();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recycle bin emptied')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deletedExpenses.isEmpty
              ? const EmptyState(
                  icon: Icons.delete_outline,
                  message: 'Recycle bin is empty',
                )
              : ListView.builder(
                  itemCount: _deletedExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = _deletedExpenses[index];
                    return ListTile(
                      title: Text(expense.title),
                      subtitle: Text(
                          '${CurrencyFormatter.format(expense.totalAmount)} · ${DateFormatter.formatRelative(expense.timestamp)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.restore, color: cs.primary),
                            onPressed: () async {
                              try {
                                final expProv = context.read<ExpenseProvider>();
                                final balProv = context.read<BalanceProvider>();
                                await expProv.restoreExpense(expense.id!);
                                await balProv.recalculateBalances();
                                await _loadDeleted();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error restoring: $e')),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_forever, color: cs.error),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Forever?'),
                                  content: const Text('This action cannot be undone and will permanently remove this expense from the database.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true), 
                                      style: TextButton.styleFrom(foregroundColor: cs.error),
                                      child: const Text('Delete')
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && mounted) {
                                await context
                                    .read<ExpenseProvider>()
                                    .permanentlyDeleteExpense(expense.id!);
                                await _loadDeleted();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
