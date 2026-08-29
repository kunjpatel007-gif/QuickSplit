import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/core/constants/app_constants.dart';
import 'package:campus_quicksplit/core/constants/category_icons.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/utils/input_validators.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TemplateProvider>().loadTemplates());
  }

  void _showAddPresetSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddPresetForm(),
    );
  }

  Future<void> _useTemplate(ExpenseTemplate template) async {
    final expense = Expense(
      title: template.title,
      totalAmount: template.amount,
      category: template.category,
      timestamp: DateTime.now(),
      isRecurring: false,
      isDeleted: false,
    );
    
    final List<dynamic> parsedPayers = jsonDecode(template.payersJson);
    final List<dynamic> parsedSplits = jsonDecode(template.splitsJson);
    
    final payers = parsedPayers.map((e) => ExpensePayer(
      expenseId: 0,
      userId: e['userId'],
      amountPaid: e['amountPaid'],
    )).toList();
    
    final splits = parsedSplits.map((e) => ExpenseSplit(
      expenseId: 0,
      userId: e['userId'],
      amountOwed: e['amountOwed'],
    )).toList();
    
    await context.read<ExpenseProvider>().addExpense(
      expense: expense,
      payers: payers.isEmpty ? [ExpensePayer(expenseId: 0, userId: context.read<UserProvider>().currentUser?.id ?? 0, amountPaid: template.amount)] : payers,
      splits: splits.isEmpty ? [ExpenseSplit(expenseId: 0, userId: context.read<UserProvider>().currentUser?.id ?? 0, amountOwed: template.amount)] : splits,
    );
    await context.read<BalanceProvider>().recalculateBalances();
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense added from preset')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Presets'),
      ),
      body: Consumer<TemplateProvider>(
        builder: (context, provider, child) {
          if (provider.templates.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_awesome,
              message: 'No routine presets yet.\nCreate one for quick logging!',
            );
          }
          
          return ListView.builder(
            itemCount: provider.templates.length,
            itemBuilder: (context, index) {
              final template = provider.templates[index];
              return Dismissible(
                key: ValueKey(template.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: cs.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(Icons.delete, color: cs.onError),
                ),
                onDismissed: (_) {
                  if (template.id != null) {
                    provider.deleteTemplate(template.id!);
                  }
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: CategoryIcons.getColor(template.category).withValues(alpha: 0.2),
                      child: Icon(
                        CategoryIcons.getIcon(template.category),
                        color: CategoryIcons.getColor(template.category),
                      ),
                    ),
                    title: Text(template.title),
                    subtitle: Text(CurrencyFormatter.format(template.amount)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _useTemplate(template),
                          child: const Text('Use'),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: cs.error),
                          onPressed: () {
                            if (template.id != null) {
                              provider.deleteTemplate(template.id!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPresetSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddPresetForm extends StatefulWidget {
  const _AddPresetForm({super.key});

  @override
  State<_AddPresetForm> createState() => _AddPresetFormState();
}

class _AddPresetFormState extends State<_AddPresetForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = AppConstants.categories.first;
  final Set<int> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = context.read<UserProvider>().currentUser;
      if (currentUser != null && currentUser.id != null) {
        setState(() {
          _selectedUserIds.add(currentUser.id!);
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final amount = double.parse(_amountController.text.trim());
      String payersJson = '[]';
      String splitsJson = '[]';

      if (_selectedUserIds.isNotEmpty) {
        final currentUser = context.read<UserProvider>().currentUser;
        final payerId = (currentUser != null && _selectedUserIds.contains(currentUser.id)) 
            ? currentUser.id! 
            : _selectedUserIds.first;
            
        final payers = [{'userId': payerId, 'amountPaid': amount}];
        payersJson = jsonEncode(payers);

        final splitAmount = amount / _selectedUserIds.length;
        final splits = _selectedUserIds.map((id) => {'userId': id, 'amountOwed': splitAmount}).toList();
        splitsJson = jsonEncode(splits);
      }

      final template = ExpenseTemplate(
        title: _titleController.text.trim(),
        amount: amount,
        category: _selectedCategory,
        payersJson: payersJson,
        splitsJson: splitsJson,
        createdAt: DateTime.now(),
      );
      
      context.read<TemplateProvider>().addTemplate(template);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New Routine Preset',
              style: tt.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: InputValidators.validateTitle,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              validator: InputValidators.validateAmount,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.categories.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Icon(CategoryIcons.getIcon(c), color: CategoryIcons.getColor(c)),
                      const SizedBox(width: 8),
                      Text(c),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 16),
            Text('Split between:', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                return Wrap(
                  spacing: 8,
                  children: userProvider.users.map((u) {
                    final isSelected = _selectedUserIds.contains(u.id);
                    return FilterChip(
                      label: Text(u.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedUserIds.add(u.id!);
                          } else {
                            _selectedUserIds.remove(u.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save Preset'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
