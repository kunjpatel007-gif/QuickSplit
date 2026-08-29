import 'package:campus_quicksplit/data/models/models.dart';

class BalanceService {
  Map<int, double> calculateNetBalances(
      List<ExpensePayer> allPayers, List<ExpenseSplit> allSplits) {
    final Map<int, double> balances = {};

    for (final payer in allPayers) {
      balances[payer.userId] = (balances[payer.userId] ?? 0.0) + payer.amountPaid;
    }

    for (final split in allSplits) {
      balances[split.userId] = (balances[split.userId] ?? 0.0) - split.amountOwed;
    }

    return balances;
  }



  double getTotalGroupSpending(List<Expense> expenses) {
    double total = 0.0;
    for (final expense in expenses) {
      total += expense.totalAmount;
    }
    return total;
  }
}
