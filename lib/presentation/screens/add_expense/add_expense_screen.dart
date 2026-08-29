import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/core/constants/app_constants.dart';
import 'package:campus_quicksplit/core/constants/category_icons.dart';
import 'package:campus_quicksplit/core/utils/input_validators.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nlpController = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String _category = AppConstants.categories.first;
  SplitMode _splitMode = SplitMode.uniform;
  bool _isRecurring = false;
  int? _payerId;

  Set<int> _selectedUserIds = {};
  final Map<int, TextEditingController> _specificControllers = {};
  final Map<int, TextEditingController> _ratioControllers = {};

  final NlpParser _nlpParser = NlpParser();

  @override
  void initState() {
    super.initState();
    _splitMode = SplitMode.uniform;
    _category = AppConstants.categories.first;
    _nlpController.addListener(_onNlpChanged);

    Future.microtask(() {
      final userProvider = context.read<UserProvider>();
      final users = userProvider.users;
      setState(() {
        _payerId = userProvider.currentUser?.id;
        _selectedUserIds = users.map((u) => u.id!).toSet();
        for (var u in users) {
          _specificControllers[u.id!] = TextEditingController();
          _ratioControllers[u.id!] = TextEditingController();
        }
      });
    });
  }

  void _onNlpChanged() {
    if (_nlpController.text.isEmpty) return;
    final parsed = _nlpParser.parse(_nlpController.text);
    setState(() {
      if (parsed.amount != null) {
        _amountController.text = parsed.amount!.toStringAsFixed(2);
      }
      if (parsed.title != null && parsed.title!.isNotEmpty) {
        _titleController.text = parsed.title!;
      }
      if (parsed.category != null) {
        _category = parsed.category!;
      }
      
      final users = context.read<UserProvider>().users;
      final currentUser = context.read<UserProvider>().currentUser;
      
      if (parsed.payerName != null && parsed.payerName!.isNotEmpty) {
        final matchedUser = users.where((u) => 
          u.name.toLowerCase() == parsed.payerName!.toLowerCase()
        ).firstOrNull;
        if (matchedUser != null) {
          _payerId = matchedUser.id;
        }
      }
      
      if (parsed.isProRata && parsed.items.isNotEmpty) {
        _splitMode = SplitMode.specific;
        
        // Reset all specifics
        for (var c in _specificControllers.values) {
          c.text = '';
        }
        
        double subtotal = parsed.items.fold(0, (sum, i) => sum + i.amount);
        Map<int, double> userShares = {};
        
        for (var item in parsed.items) {
          User? matchedUser;
          final p = item.person.toLowerCase();
          if (p == 'i' || p == 'me' || p == 'my') {
            matchedUser = currentUser;
            _payerId ??= currentUser?.id; // If I ordered it, assume I paid unless specified
          } else {
            matchedUser = users.where((u) => u.name.toLowerCase() == p).firstOrNull;
          }
          
          if (matchedUser != null && matchedUser.id != null) {
            double taxShare = subtotal > 0 ? (item.amount / subtotal) * parsed.taxAmount : 0;
            double share = item.amount + taxShare;
            userShares[matchedUser.id!] = (userShares[matchedUser.id!] ?? 0) + share;
            
            if (!_selectedUserIds.contains(matchedUser.id!)) {
              _selectedUserIds.add(matchedUser.id!);
            }
          }
        }
        
        userShares.forEach((uid, share) {
          _specificControllers[uid]?.text = share.toStringAsFixed(2);
        });
      }
    });
  }

  @override
  void dispose() {
    _nlpController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    for (var c in _specificControllers.values) {
      c.dispose();
    }
    for (var c in _ratioControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _getRemainingSpecific() {
    final total = double.tryParse(_amountController.text) ?? 0;
    double assigned = 0;
    for (var uid in _selectedUserIds) {
      assigned +=
          double.tryParse(_specificControllers[uid]?.text ?? '0') ?? 0;
    }
    return total - assigned;
  }

  double _getRatioSum() {
    double sum = 0;
    for (var uid in _selectedUserIds) {
      sum += double.tryParse(_ratioControllers[uid]?.text ?? '0') ?? 0;
    }
    return sum;
  }

  bool _canSubmit() {
    if (_selectedUserIds.isEmpty) return false;
    if (_splitMode == SplitMode.specific) {
      return _getRemainingSpecific().abs() < 0.01;
    } else if (_splitMode == SplitMode.ratio) {
      return (_getRatioSum() - 100).abs() < 0.01;
    }
    return true;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_splitMode == SplitMode.specific
              ? 'Specific amounts must equal total'
              : 'Ratios must sum to 100%'),
        ),
      );
      return;
    }

    if (_payerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who paid')),
      );
      return;
    }

    final amount = double.parse(_amountController.text);
    final splitEngine = SplitEngine();

    final expense = Expense(
      title: _titleController.text.trim(),
      totalAmount: amount,
      category: _category,
      timestamp: DateTime.now(),
      isRecurring: _isRecurring,
    );

    final payers = [
      ExpensePayer(
        expenseId: 0,
        userId: _payerId!,
        amountPaid: amount,
      ),
    ];

    List<ExpenseSplit> splits;
    switch (_splitMode) {
      case SplitMode.uniform:
        splits = splitEngine.calculateUniformSplit(
          expenseId: 0,
          totalAmount: amount,
          participantIds: _selectedUserIds.toList(),
        );
        break;
      case SplitMode.specific:
        final userAmounts = <int, double>{};
        for (var uid in _selectedUserIds) {
          userAmounts[uid] =
              double.tryParse(_specificControllers[uid]?.text ?? '0') ?? 0;
        }
        splits = splitEngine.calculateSpecificSplit(
          expenseId: 0,
          userAmounts: userAmounts,
        );
        break;
      case SplitMode.ratio:
        final userRatios = <int, double>{};
        for (var uid in _selectedUserIds) {
          userRatios[uid] =
              double.tryParse(_ratioControllers[uid]?.text ?? '0') ?? 0;
        }
        splits = splitEngine.calculateRatioSplit(
          expenseId: 0,
          totalAmount: amount,
          userRatios: userRatios,
        );
        break;
    }

    try {
      await context.read<ExpenseProvider>().addExpense(
            expense: expense,
            payers: payers,
            splits: splits,
          );
      await context.read<BalanceProvider>().recalculateBalances();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final users = context.watch<UserProvider>().users;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextFormField(
              controller: _nlpController,
              decoration: const InputDecoration(
                labelText: 'Auto-Parse',
                prefixIcon: Icon(Icons.auto_fix_high),
                hintText: 'e.g., Paid 500 for pizza with Rahul',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: InputValidators.validateTitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: InputValidators.validateAmount,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
              ),
              items: AppConstants.categories.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Icon(CategoryIcons.getIcon(c),
                          color: CategoryIcons.getColor(c)),
                      const SizedBox(width: AppSpacing.sm),
                      Text(c),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _category = val!;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              value: _payerId,
              decoration: const InputDecoration(
                labelText: 'Paid By',
                prefixIcon: Icon(Icons.person),
              ),
              items: users.map((u) {
                return DropdownMenuItem<int>(
                  value: u.id,
                  child: Text(u.name),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _payerId = val;
                });
              },
              validator: (val) => val == null ? 'Select who paid' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Split Mode', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<SplitMode>(
              segments: const [
                ButtonSegment(
                    value: SplitMode.uniform, label: Text('Equal')),
                ButtonSegment(
                    value: SplitMode.specific, label: Text('Specific')),
                ButtonSegment(
                    value: SplitMode.ratio, label: Text('Ratio')),
              ],
              selected: {_splitMode},
              onSelectionChanged: (set) {
                setState(() {
                  _splitMode = set.first;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Participants', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: users.map((user) {
                final isSelected = _selectedUserIds.contains(user.id);
                return FilterChip(
                  label: Text(user.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedUserIds.add(user.id!);
                        _specificControllers[user.id!] =
                            _specificControllers[user.id!] ??
                                TextEditingController();
                        _ratioControllers[user.id!] =
                            _ratioControllers[user.id!] ??
                                TextEditingController();
                      } else {
                        _selectedUserIds.remove(user.id!);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: _buildSplitSection(users, cs, tt),
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              title: const Text('Recurring Expense'),
              subtitle: const Text('Auto-clone monthly'),
              secondary: const Icon(Icons.repeat),
              value: _isRecurring,
              onChanged: (val) => setState(() => _isRecurring = val),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _canSubmit() ? _submit : null,
              icon: const Icon(Icons.check),
              label: const Text('Submit Expense'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitSection(List<User> users, ColorScheme cs, TextTheme tt) {
    final totalAmount = double.tryParse(_amountController.text) ?? 0;
    final selectedUsers =
        users.where((u) => _selectedUserIds.contains(u.id)).toList();

    if (selectedUsers.isEmpty) {
      return Text('Select participants above', style: tt.bodyMedium);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...selectedUsers.map((user) {
          if (_splitMode == SplitMode.uniform) {
            final perPerson = selectedUsers.isEmpty
                ? 0.0
                : totalAmount / selectedUsers.length;
            return ListTile(
              leading: CircleAvatar(child: Text(user.name[0])),
              title: Text(user.name),
              trailing: Text(CurrencyFormatter.format(perPerson)),
            );
          } else if (_splitMode == SplitMode.specific) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                      radius: 16, child: Text(user.name[0])),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(user.name)),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _specificControllers[user.id!],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          const InputDecoration(labelText: '₹ Amount'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                      radius: 16, child: Text(user.name[0])),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(user.name)),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _ratioControllers[user.id!],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: '%'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            );
          }
        }),
        if (_splitMode == SplitMode.specific)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Remaining: ${CurrencyFormatter.format(_getRemainingSpecific())}',
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getRemainingSpecific().abs() < 0.01
                    ? const Color(0xFF16A34A)
                    : cs.error,
              ),
            ),
          ),
        if (_splitMode == SplitMode.ratio)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Total: ${_getRatioSum().toStringAsFixed(1)}%',
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color:
                    (_getRatioSum() - 100).abs() < 0.01
                        ? const Color(0xFF16A34A)
                        : cs.error,
              ),
            ),
          ),
      ],
    );
  }
}
