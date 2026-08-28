import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/utils/date_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

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
      appBar: AppBar(title: const Text('Recycle Bin')),
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
                      trailing: IconButton(
                        icon: Icon(Icons.restore, color: cs.primary),
                        onPressed: () async {
                          await context
                              .read<ExpenseProvider>()
                              .restoreExpense(expense.id!);
                          await context
                              .read<BalanceProvider>()
                              .recalculateBalances();
                          await _loadDeleted();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
