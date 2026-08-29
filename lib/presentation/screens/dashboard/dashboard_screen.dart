import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';
import 'package:campus_quicksplit/presentation/screens/add_expense/add_expense_screen.dart';
import 'package:campus_quicksplit/presentation/screens/settings/settings_screen.dart';
import 'package:campus_quicksplit/presentation/screens/audit_log/audit_log_screen.dart';
import 'package:campus_quicksplit/presentation/screens/recycle_bin/recycle_bin_screen.dart';
import 'package:campus_quicksplit/presentation/screens/settlement/settlement_screen.dart';
import 'dart:convert';
import 'package:campus_quicksplit/presentation/screens/analytics/analytics_screen.dart';
import 'package:campus_quicksplit/presentation/screens/debt_graph/debt_graph_screen.dart';
import 'package:campus_quicksplit/presentation/screens/qr_sync/qr_sync_screen.dart';
import 'package:campus_quicksplit/presentation/screens/nearby_sync/nearby_sync_screen.dart';
import 'package:campus_quicksplit/presentation/screens/hce_tap_pay/hce_tap_pay_screen.dart';
import 'package:campus_quicksplit/presentation/screens/receipt_scanner/receipt_scanner_screen.dart';

import 'package:campus_quicksplit/presentation/screens/presets/presets_screen.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';
import 'package:campus_quicksplit/presentation/widgets/staggered_list_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final expProv = context.read<ExpenseProvider>();
      if (expProv.hasMore) {
        expProv.loadMoreExpenses();
      }
    }
  }

  Future<void> _loadData() async {
    final expProv = context.read<ExpenseProvider>();
    final userProv = context.read<UserProvider>();
    final balProv = context.read<BalanceProvider>();
    final tmpProv = context.read<TemplateProvider>();

    await expProv.loadExpenses();
    await userProv.loadUsers();
    await balProv.recalculateBalances();
    await tmpProv.loadTemplates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.nfc),
            tooltip: 'Tap to Pay',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HceTapPayScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Nearby Sync',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NearbySyncScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'QR Sync',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrSyncScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Receipt',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(context),
          const SettlementScreen(),
          const AnalyticsScreen(),
          const AuditLogScreen(),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                );
                if (mounted) {
                  await _loadData();
                }
              },
              child: const Icon(
                Icons.add,
                size: 28,
              ), // Standard is 24, Large is 36. 75% of 36 = 27 (rounded to 28 for crisp rendering)
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Settlement',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Audit Log',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final balanceProvider = context.watch<BalanceProvider>();
    final userProvider = context.watch<UserProvider>();
    final templateProvider = context.watch<TemplateProvider>();
    final expenses = expenseProvider.expenses;
    final balances = balanceProvider.balances;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Balances'),
                SizedBox(
                  height: 132,
                  child: balances.isEmpty
                      ? const Center(child: Text('No balances yet.'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          itemCount: balances.length,
                          itemBuilder: (context, index) {
                            final userId = balances.keys.elementAt(index);
                            final balance = balances[userId] ?? 0;
                            final user = userProvider.getUserById(userId);
                            final displayUser =
                                user ??
                                User(
                                  name: 'User $userId',
                                  createdAt: DateTime.now(),
                                );
                            return BalanceCard(
                              user: displayUser,
                              balance: balance,
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.bubble_chart, size: 18),
                          label: const Text('View Debt Graph'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DebtGraphScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (templateProvider.templates.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Quick Presets',
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PresetsScreen(),
                          ),
                        );
                      },
                      child: const Text('Manage'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: templateProvider.templates.map((template) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.sm,
                            ),
                            child: ActionChip(
                              label: Text(template.title),
                              onPressed: () async {
                                final expense = Expense(
                                  title: template.title,
                                  totalAmount: template.amount,
                                  category: template.category,
                                  timestamp: DateTime.now(),
                                  isRecurring: false,
                                  isDeleted: false,
                                );
                                final List<dynamic> parsedPayers = jsonDecode(
                                  template.payersJson,
                                );
                                final List<dynamic> parsedSplits = jsonDecode(
                                  template.splitsJson,
                                );
                                final payers = parsedPayers
                                    .map(
                                      (e) => ExpensePayer(
                                        expenseId: 0,
                                        userId: e['userId'],
                                        amountPaid: (e['amountPaid'] as num)
                                            .toDouble(),
                                      ),
                                    )
                                    .toList();
                                final splits = parsedSplits
                                    .map(
                                      (e) => ExpenseSplit(
                                        expenseId: 0,
                                        userId: e['userId'],
                                        amountOwed: (e['amountOwed'] as num)
                                            .toDouble(),
                                      ),
                                    )
                                    .toList();
                                final currentUser = context
                                    .read<UserProvider>()
                                    .currentUser;
                                try {
                                  await context
                                      .read<ExpenseProvider>()
                                      .addExpense(
                                        expense: expense,
                                        payers: payers.isEmpty
                                            ? [
                                                ExpensePayer(
                                                  expenseId: 0,
                                                  userId: currentUser?.id ?? 0,
                                                  amountPaid: template.amount,
                                                ),
                                              ]
                                            : payers,
                                        splits: splits.isEmpty
                                            ? [
                                                ExpenseSplit(
                                                  expenseId: 0,
                                                  userId: currentUser?.id ?? 0,
                                                  amountOwed: template.amount,
                                                ),
                                              ]
                                            : splits,
                                      );
                                  await context
                                      .read<BalanceProvider>()
                                      .recalculateBalances();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Quick added from preset')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(e
                                              .toString()
                                              .replaceAll('Exception: ', ''))),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                SectionHeader(
                  title: 'Activity Log',
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecycleBinScreen(),
                        ),
                      );
                    },
                    child: const Text('Recycle Bin'),
                  ),
                ),
              ],
            ),
          ),
          expenses.isEmpty
              ? const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.receipt_long,
                    message: 'No expenses yet. Tap + to add one!',
                  ),
                )
              : SliverList.builder(
                  itemCount:
                      expenses.length + (expenseProvider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= expenses.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final expense = expenses[index];
                    return StaggeredListItem(
                      index: index,
                      child: ExpenseTile(
                        expense: expense,
                        onDismissed: () async {
                          final provider = context.read<ExpenseProvider>();
                          final balProvider = context.read<BalanceProvider>();
                          await provider.softDeleteExpense(expense.id!);
                          await balProvider.recalculateBalances();

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Expense deleted'),
                              duration: const Duration(seconds: 5),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () async {
                                  await provider.restoreExpense(expense.id!);
                                  await balProvider.recalculateBalances();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
