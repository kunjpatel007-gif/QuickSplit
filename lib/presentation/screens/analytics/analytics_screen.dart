import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/constants/category_icons.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final userProvider = context.watch<UserProvider>();
    final balanceProvider = context.watch<BalanceProvider>();
    
    final expenses = expenseProvider.expenses;
    final balances = balanceProvider.balances;
    
    double totalSpending = 0;
    Map<String, double> categoryTotals = {};
    double highestAmount = 0;
    
    for (var exp in expenses) {
      totalSpending += exp.totalAmount;
      categoryTotals[exp.category] = (categoryTotals[exp.category] ?? 0) + exp.totalAmount;
      if (exp.totalAmount > highestAmount) highestAmount = exp.totalAmount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131314),
        title: Text('ANALYTICS', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFFe5e2e3))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFF514532), height: 2),
        ),
      ),
      body: expenses.isEmpty
          ? RefreshIndicator(
              onRefresh: () async {
                await context.read<ExpenseProvider>().loadExpenses();
                await context.read<BalanceProvider>().recalculateBalances();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(child: Text('NO DATA', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF514532))))
                  )
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await context.read<ExpenseProvider>().loadExpenses();
                await context.read<BalanceProvider>().recalculateBalances();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Color(0xFF9e8f78), size: 16),
                      const SizedBox(width: 8),
                      Text('SYSTEM METRICS', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF9e8f78), letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Summary Row
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('TOTAL_VOL', CurrencyFormatter.format(totalSpending))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('TXN_COUNT', expenses.length.toString())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard('MAX_TXN_VAL', CurrencyFormatter.format(highestAmount), fullWidth: true),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.pie_chart_outline, color: Color(0xFF9e8f78), size: 16),
                      const SizedBox(width: 8),
                      Text('CATEGORY DISTRIBUTION', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF9e8f78), letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    height: 200,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size.infinite,
                          painter: BrutalistDonutChartPainter(
                            categoryTotals: categoryTotals,
                            totalAmount: totalSpending,
                            progress: _animation.value,
                          ),
                        );
                      }
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLegend(categoryTotals, totalSpending),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, color: Color(0xFF9e8f78), size: 16),
                      const SizedBox(width: 8),
                      Text('7-DAY TREND', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF9e8f78), letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF201f20),
                      border: Border.all(color: const Color(0xFF514532)),
                    ),
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size.infinite,
                          painter: BrutalistBarChartPainter(
                            expenses: expenses,
                            progress: _animation.value,
                          ),
                        );
                      }
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.group, color: Color(0xFF9e8f78), size: 16),
                      const SizedBox(width: 8),
                      Text('TOP SPENDERS', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF9e8f78), letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTopSpendersList(balances, userProvider),
                  const SizedBox(height: 80), // Bottom nav padding
                ],
              ),
            ),
            ), // Close RefreshIndicator
    );
  }

  Widget _buildMetricCard(String title, String value, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF201f20),
        border: Border.all(color: const Color(0xFF514532)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.jetBrainsMono(color: const Color(0xFF9e8f78), fontSize: 10, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLegend(Map<String, double> categoryTotals, double totalAmount) {
    return Column(
      children: categoryTotals.entries.map((e) {
        final percentage = totalAmount > 0 ? (e.value / totalAmount) * 100 : 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF201f20),
            border: Border.all(color: const Color(0xFF514532)),
          ),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: _getBrutalistCategoryColor(e.key), border: Border.all(color: const Color(0xFF131314)))),
              const SizedBox(width: 12),
              Expanded(child: Text(e.key.toUpperCase(), style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontWeight: FontWeight.bold))),
              Text('${CurrencyFormatter.format(e.value)} (${percentage.toStringAsFixed(1)}%)', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF9e8f78))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopSpendersList(Map<int, double> balances, UserProvider userProvider) {
    var sortedBalances = balances.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: sortedBalances.map((entry) {
        final user = userProvider.getUserById(entry.key);
        if (user == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF201f20),
            border: Border.all(color: const Color(0xFF514532)),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                color: const Color(0xFF131314),
                alignment: Alignment.center,
                child: Text((user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?'), style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(user.name.toUpperCase(), style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontWeight: FontWeight.bold))),
              Text(CurrencyFormatter.format(entry.value), style: GoogleFonts.jetBrainsMono(color: const Color(0xFFffdca1), fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

Color _getBrutalistCategoryColor(String category) {
  final Map<String, Color> colors = {
    'Food': const Color(0xFFffb4ab),
    'Travel': const Color(0xFFb8c3ff),
    'Entertainment': const Color(0xFFffb800),
    'Utilities': const Color(0xFFffdca1),
    'Shopping': const Color(0xFFe5e2e3),
    'Health': const Color(0xFFffb4ab),
    'Education': const Color(0xFFb8c3ff),
    'Other': const Color(0xFF514532),
  };
  return colors[category] ?? const Color(0xFFffb800);
}

class BrutalistDonutChartPainter extends CustomPainter {
  final Map<String, double> categoryTotals;
  final double totalAmount;
  final double progress;

  BrutalistDonutChartPainter({required this.categoryTotals, required this.totalAmount, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (totalAmount == 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = max(0.0, min(size.width / 2, size.height / 2) - 15.0);
    if (radius <= 0) return;
    
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    double startAngle = -pi / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 30;
    
    for (var entry in categoryTotals.entries) {
      final sweepAngle = (entry.value / totalAmount) * 2 * pi * progress;
      paint.color = _getBrutalistCategoryColor(entry.key);
      
      final gap = 0.05;
      final actualSweep = sweepAngle > gap ? sweepAngle - gap : sweepAngle;
      
      canvas.drawArc(rect, startAngle, actualSweep, false, paint);
      
      startAngle += sweepAngle;
    }
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: CurrencyFormatter.format(totalAmount * progress),
        style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontSize: 16, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BrutalistBarChartPainter extends CustomPainter {
  final List<Expense> expenses;
  final double progress;

  BrutalistBarChartPainter({required this.expenses, required this.progress});

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
      final diff = today.difference(DateTime(exp.timestamp.year, exp.timestamp.month, exp.timestamp.day)).inDays;
      if (diff >= 0 && diff < 7) {
        dailyTotals[6 - diff] += exp.totalAmount;
      }
    }

    double maxVal = dailyTotals.isEmpty ? 1 : dailyTotals.reduce(max);
    if (maxVal == 0) maxVal = 1;

    final barWidth = (size.width / 7) * 0.6;
    final spacing = (size.width / 7) * 0.4;
    final fillPaint = Paint()..style = PaintingStyle.fill..color = const Color(0xFFffb800);
    final borderPaint = Paint()..style = PaintingStyle.stroke..color = const Color(0xFF131314)..strokeWidth = 2;

    for (int i = 0; i < 7; i++) {
      final x = (i * (barWidth + spacing)) + (spacing / 2);
      final height = (dailyTotals[i] / maxVal) * (size.height - 20) * progress;
      final y = (size.height - 20) - height;

      final rect = Rect.fromLTWH(x, y, barWidth, height);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: dayLabels[i],
          style: GoogleFonts.jetBrainsMono(color: const Color(0xFF9e8f78), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (barWidth / 2) - (textPainter.width / 2), size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
