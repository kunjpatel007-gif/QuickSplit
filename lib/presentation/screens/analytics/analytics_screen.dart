import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/constants/app_constants.dart';
import 'package:campus_quicksplit/core/constants/category_icons.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final expenseProvider = Provider.of<ExpenseProvider>(
      context,
      listen: false,
    );
    final balanceProvider = Provider.of<BalanceProvider>(
      context,
      listen: false,
    );
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final expenses = expenseProvider.expenses as List<Expense>;
    final totalSpending = balanceProvider.totalSpending as double;
    final balances = balanceProvider.balances as Map<int, double>;

    Map<String, double> categoryTotals = {};
    for (var expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.totalAmount;
    }

    String mostUsedCategory = 'None';
    double maxCat = 0;
    categoryTotals.forEach((key, value) {
      if (value > maxCat) {
        maxCat = value;
        mostUsedCategory = key;
      }
    });

    double avgExpense = expenses.isEmpty ? 0 : totalSpending / expenses.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Spend Analytics')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ExpenseProvider>().loadExpenses();
          await context.read<BalanceProvider>().recalculateBalances();
        },
        child: expenses.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  child: const EmptyState(
                    icon: Icons.analytics,
                    message: 'No expenses yet to analyze.',
                  ),
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total',
                            totalSpending,
                            context,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'Average',
                            avgExpense,
                            context,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Count',
                            expenses.length.toDouble(),
                            context,
                            isCount: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'Top Cat',
                            0,
                            context,
                            textValue: mostUsedCategory,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Category Breakdown'),
                    const SizedBox(height: 16),
                    Center(
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(200, 200),
                            painter: DonutChartPainter(
                              categoryTotals: categoryTotals,
                              totalAmount: totalSpending,
                              progress: _animation.value,
                              onSurface: cs.onSurface,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildLegend(categoryTotals, totalSpending, tt),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Last 7 Days Trend'),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: BarChartPainter(
                              expenses: expenses,
                              progress: _animation.value,
                              primary: cs.primary,
                              onSurface: cs.onSurface,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Top Spenders'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTopSpendersList(balances, userProvider, tt),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    BuildContext context, {
    bool isCount = false,
    String? textValue,
  }) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(title, style: tt.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              textValue ??
                  (isCount
                      ? amount.toInt().toString()
                      : CurrencyFormatter.format(amount)),
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(
    Map<String, double> categoryTotals,
    double totalAmount,
    TextTheme tt,
  ) {
    return Column(
      children: categoryTotals.entries.map((e) {
        final percentage = totalAmount > 0 ? (e.value / totalAmount) * 100 : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: CategoryIcons.getColor(e.key),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(e.key, style: tt.bodyMedium)),
              Text(
                '${CurrencyFormatter.format(e.value)} (${percentage.toStringAsFixed(1)}%)',
                style: tt.bodyMedium,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopSpendersList(
    Map<int, double> balances,
    dynamic userProvider,
    TextTheme tt,
  ) {
    var sortedBalances = balances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedBalances.length,
      itemBuilder: (context, index) {
        final entry = sortedBalances[index];
        final user = userProvider.getUserById(entry.key);
        if (user == null) return const SizedBox.shrink();
        return ListTile(
          leading: CircleAvatar(child: Text(user.name.substring(0, 1))),
          title: Text(user.name, style: tt.bodyLarge),
          trailing: Text(
            CurrencyFormatter.format(entry.value),
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<String, double> categoryTotals;
  final double totalAmount;
  final double progress;
  final Color onSurface;

  DonutChartPainter({
    required this.categoryTotals,
    required this.totalAmount,
    required this.progress,
    required this.onSurface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -pi / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30;

    if (totalAmount == 0) return;

    for (var entry in categoryTotals.entries) {
      final sweepAngle = (entry.value / totalAmount) * 2 * pi * progress;
      paint.color = CategoryIcons.getColor(entry.key);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: CurrencyFormatter.format(totalAmount * progress),
        style: TextStyle(
          color: onSurface,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - (textPainter.width / 2),
        center.dy - (textPainter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BarChartPainter extends CustomPainter {
  final List<Expense> expenses;
  final double progress;
  final Color primary;
  final Color onSurface;

  BarChartPainter({
    required this.expenses,
    required this.progress,
    required this.primary,
    required this.onSurface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<double> dailyTotals = List.filled(7, 0.0);
    List<String> dayLabels = List.filled(7, '');

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: 6 - i));
      dayLabels[i] = '${date.day}/${date.month}';
    }

    for (var exp in expenses) {
      final diff = today
          .difference(
            DateTime(
              exp.timestamp.year,
              exp.timestamp.month,
              exp.timestamp.day,
            ),
          )
          .inDays;
      if (diff >= 0 && diff < 7) {
        dailyTotals[6 - diff] += exp.totalAmount;
      }
    }

    double maxVal = dailyTotals.isEmpty ? 1 : dailyTotals.reduce(max);
    if (maxVal == 0) maxVal = 1;

    final barWidth = (size.width / 7) * 0.6;
    final spacing = (size.width / 7) * 0.4;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = primary;

    for (int i = 0; i < 7; i++) {
      final x = (i * (barWidth + spacing)) + (spacing / 2);
      final height = (dailyTotals[i] / maxVal) * size.height * progress;
      final y = size.height - height;

      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, height), paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: dayLabels[i],
          style: TextStyle(color: onSurface, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth / 2) - (textPainter.width / 2), size.height + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
