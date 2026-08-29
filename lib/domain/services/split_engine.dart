import 'package:campus_quicksplit/data/models/models.dart';

enum SplitMode { uniform, specific, ratio }

class SplitEngine {
  List<ExpenseSplit> calculateUniformSplit({
    required int expenseId,
    required double totalAmount,
    required List<int> participantIds,
  }) {
    if (participantIds.isEmpty) return [];

    final int count = participantIds.length;
    final double truncatedAmount =
        double.parse((totalAmount / count).toStringAsFixed(2));
    final double remainder =
        double.parse((totalAmount - (truncatedAmount * count)).toStringAsFixed(2));

    final List<ExpenseSplit> splits = [];
    for (int i = 0; i < count; i++) {
      double amount = truncatedAmount;
      if (i == 0) {
        amount += remainder;
      }
      splits.add(ExpenseSplit(
        expenseId: expenseId,
        userId: participantIds[i],
        amountOwed: double.parse(amount.toStringAsFixed(2)),
      ));
    }
    return splits;
  }

  List<ExpenseSplit> calculateSpecificSplit({
    required int expenseId,
    required Map<int, double> userAmounts,
  }) {
    final List<ExpenseSplit> splits = [];
    userAmounts.forEach((userId, amount) {
      splits.add(ExpenseSplit(
        expenseId: expenseId,
        userId: userId,
        amountOwed: amount,
      ));
    });
    return splits;
  }

  List<ExpenseSplit> calculateProRataSplit({
    required int expenseId,
    required Map<int, double> userDishTotals,
    required double totalOverhead,
  }) {
    final List<ExpenseSplit> splits = [];
    double subtotal = 0.0;
    
    for (var amount in userDishTotals.values) {
      subtotal += amount;
    }

    if (subtotal <= 0) {
      return calculateSpecificSplit(expenseId: expenseId, userAmounts: userDishTotals);
    }

    double calculatedTotal = 0.0;
    userDishTotals.forEach((userId, amount) {
      final double taxShare = (amount / subtotal) * totalOverhead;
      final double finalAmount = double.parse((amount + taxShare).toStringAsFixed(2));
      calculatedTotal += finalAmount;
      splits.add(ExpenseSplit(
        expenseId: expenseId,
        userId: userId,
        amountOwed: finalAmount,
      ));
    });

    final expectedTotal = subtotal + totalOverhead;
    final double remainder = double.parse((expectedTotal - calculatedTotal).toStringAsFixed(2));
    
    if (remainder != 0.0 && splits.isNotEmpty) {
      splits[0] = ExpenseSplit(
        expenseId: expenseId,
        userId: splits[0].userId,
        amountOwed: double.parse((splits[0].amountOwed + remainder).toStringAsFixed(2)),
      );
    }

    return splits;
  }

  List<ExpenseSplit> calculateRatioSplit({
    required int expenseId,
    required double totalAmount,
    required Map<int, double> userRatios,
  }) {
    if (userRatios.isEmpty) return [];

    final List<ExpenseSplit> splits = [];
    double calculatedTotal = 0.0;

    int firstUserId = userRatios.keys.first;

    userRatios.forEach((userId, ratio) {
      final double amount =
          double.parse((totalAmount * (ratio / 100)).toStringAsFixed(2));
      calculatedTotal += amount;
      splits.add(ExpenseSplit(
        expenseId: expenseId,
        userId: userId,
        amountOwed: amount,
      ));
    });

    final double remainder =
        double.parse((totalAmount - calculatedTotal).toStringAsFixed(2));
    if (remainder != 0.0) {
      final int index = splits.indexWhere((s) => s.userId == firstUserId);
      if (index != -1) {
        splits[index] = ExpenseSplit(
          expenseId: expenseId,
          userId: firstUserId,
          amountOwed: double.parse(
              (splits[index].amountOwed + remainder).toStringAsFixed(2)),
        );
      }
    }

    return splits;
  }

  bool validateSpecificSplit(double totalAmount, Map<int, double> userAmounts, {double totalOverhead = 0.0}) {
    double sum = 0.0;
    for (final amount in userAmounts.values) {
      sum += amount;
    }
    return (sum + totalOverhead - totalAmount).abs() < 0.01;
  }

  bool validateRatioSplit(Map<int, double> userRatios) {
    double sum = 0.0;
    for (final ratio in userRatios.values) {
      sum += ratio;
    }
    return (sum - 100.0).abs() < 0.01;
  }
}
