import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';
import 'package:campus_quicksplit/presentation/screens/add_expense/add_expense_screen.dart';
import 'package:campus_quicksplit/presentation/screens/settings/settings_screen.dart';
import 'package:campus_quicksplit/presentation/screens/audit_log/audit_log_screen.dart';
import 'package:campus_quicksplit/presentation/screens/recycle_bin/recycle_bin_screen.dart';
import 'package:campus_quicksplit/presentation/screens/settlement/settlement_screen.dart';
import 'dart:convert';
import 'package:campus_quicksplit/core/utils/template_utils.dart';
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
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
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFffb800),
                border: Border.all(color: const Color(0xFF514532), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF9e8f78), offset: Offset(2, 2)),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Color(0xFF131314),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedIndex == 0
                      ? 'QUICKSPLIT'
                      : _selectedIndex == 1
                      ? 'SETTLEMENTS'
                      : _selectedIndex == 2
                      ? 'ANALYTICS'
                      : 'AUDIT_TRAIL',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFe5e2e3),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF3a393a),
                border: Border.all(color: const Color(0xFF514532), width: 2),
              ),
              child: const Icon(Icons.settings, color: Color(0xFFe5e2e3)),
            ),
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

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outline, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF201f20),
          selectedItemColor: const Color(0xFFffdca1),
          unselectedItemColor: const Color(0xFFe5e2e3),
          selectedLabelStyle: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          unselectedLabelStyle: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'QUICKSPLIT',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.credit_card),
              label: 'SETTLEMENTS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'ANALYTICS',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'LOG'),
          ],
        ),
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

    final double totalOwedToMe = balances.values
        .where((b) => b > 0)
        .fold(0.0, (a, b) => a + b);
    final double totalIOwe = balances.values
        .where((b) => b < 0)
        .fold(0.0, (a, b) => a + b);
    final double netLiquidity = totalOwedToMe + totalIOwe;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        key: const ValueKey('DashboardScrollView'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Liquidity Overview
                  Container(
                    margin: const EdgeInsets.only(bottom: 32, top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF201f20),
                      border: Border.all(
                        color: const Color(0xFF514532),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF131314),
                          offset: Offset(4, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -28,
                          left: 0,
                          child: Container(
                            color: const Color(0xFF131314),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'NET BALANCE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: const Color(0xFF9e8f78),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'INR ',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: const Color(0xFF9e8f78),
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      netLiquidity.toStringAsFixed(2),
                                      style: GoogleFonts.jetBrainsMono(
                                        color: const Color(0xFFe5e2e3),
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF412d00),
                                    border: Border.all(
                                      color: const Color(0xFFffdca1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        netLiquidity >= 0
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        size: 14,
                                        color: const Color(0xFFffdca1),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFffdca1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.only(top: 16),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFF514532)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOTAL RECEIVABLE',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            color: const Color(0xFF9e8f78),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: const Color(0xFFe5e2e3),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOTAL PAYABLE',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            color: const Color(0xFF9e8f78),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: const Color(0xFFffb4ab),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tactical Actions
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                    children: [
                      _buildGridAction(
                        context,
                        'ADD',
                        Icons.arrow_downward,
                        const Color(0xFFffb800),
                        const Color(0xFF131314),
                        () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddExpenseScreen(),
                            ),
                          );
                          if (mounted) await _loadData();
                        },
                      ),
                      _buildGridAction(
                        context,
                        'SCAN',
                        Icons.document_scanner,
                        const Color(0xFF201f20),
                        const Color(0xFFe5e2e3),
                        () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReceiptScannerScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridAction(
                        context,
                        'PRESETS',
                        Icons.lock_person,
                        const Color(0xFF201f20),
                        const Color(0xFFb8c3ff),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PresetsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridAction(
                        context,
                        'GRAPH',
                        Icons.bubble_chart,
                        const Color(0xFF201f20),
                        const Color(0xFFe5e2e3),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DebtGraphScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridAction(
                        context,
                        'QR',
                        Icons.qr_code_scanner,
                        const Color(0xFF201f20),
                        const Color(0xFFe5e2e3),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QrSyncScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridAction(
                        context,
                        'NFC',
                        Icons.nfc,
                        const Color(0xFF201f20),
                        const Color(0xFFffb4ab),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HceTapPayScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridAction(
                        context,
                        'NEARBY',
                        Icons.wifi_tethering,
                        const Color(0xFF201f20),
                        const Color(0xFFe5e2e3),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NearbySyncScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Active Balances
                  Row(
                    children: [
                      const Icon(Icons.hub, color: Color(0xFF9e8f78), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVE BALANCES',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF9e8f78),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: balances.isEmpty
                        ? Center(
                            child: Text(
                              'NO ACTIVE BALANCES',
                              style: GoogleFonts.jetBrainsMono(
                                color: const Color(0xFF514532),
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: balances.length,
                            itemBuilder: (context, index) {
                              final userId = balances.keys.elementAt(index);
                              final balance = balances[userId] ?? 0;
                              final user = userProvider.getUserById(userId);
                              final name = (user?.name ?? 'USER ')
                                  .toUpperCase();

                              return Container(
                                width: 120,
                                margin: const EdgeInsets.only(right: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131314),
                                  border: Border.all(
                                    color: const Color(0xFF514532),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      color: const Color(0xFF201f20),
                                      alignment: Alignment.center,
                                      child: Text(
                                        name.substring(0, 1),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 20,
                                          color: const Color(0xFFe5e2e3),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      name,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFe5e2e3),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      balance >= 0
                                          ? '+₹${balance.toStringAsFixed(0)}'
                                          : '-₹${balance.abs().toStringAsFixed(0)}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        color: balance >= 0
                                            ? const Color(0xFFffdca1)
                                            : const Color(0xFFffb4ab),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 32),

                  // Recent Transactions (Expenses)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.list_alt,
                            color: Color(0xFF9e8f78),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RECENT TRANSACTIONS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF9e8f78),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFF9e8f78),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecycleBinScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Expense List
          expenses.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'NO TRANSACTIONS FOUND',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF514532),
                        ),
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList.builder(
                    itemCount:
                        expenses.length + (expenseProvider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= expenses.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final expense = expenses[index];
                      return Dismissible(
                        key: ValueKey(expense.id),
                        onDismissed: (_) async {
                          final provider = context.read<ExpenseProvider>();
                          final balProvider = context.read<BalanceProvider>();
                          await provider.softDeleteExpense(expense.id!);
                          await balProvider.recalculateBalances();
                          // ignore: use_build_context_synchronously
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Expense deleted')),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF201f20),
                            border: Border.all(color: const Color(0xFF514532)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Text(
                                expense.title,
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFFe5e2e3),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                expense.category.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFF9e8f78),
                                  fontSize: 10,
                                ),
                              ),
                              trailing: Text(
                                '₹${expense.totalAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFFffdca1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onTap: () {},
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildGridAction(
    BuildContext context,
    String label,
    IconData icon,
    Color bgColor,
    Color fgColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: const Color(0xFF514532), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: 20),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: fgColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
