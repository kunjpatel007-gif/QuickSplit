class DebtTransaction {
  final int fromUserId;
  final int toUserId;
  final double amount;

  const DebtTransaction({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });
}

class DebtSimplifier {
  List<DebtTransaction> simplifyDebts(Map<int, double> netBalances) {
    List<MapEntry<int, double>> debtors = [];
    List<MapEntry<int, double>> creditors = [];

    netBalances.forEach((userId, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(userId, balance));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(userId, balance));
      }
    });

    final List<DebtTransaction> transactions = [];

    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      debtors.sort((a, b) => a.value.abs().compareTo(b.value.abs()));
      creditors.sort((a, b) => a.value.compareTo(b.value));

      var maxDebtor = debtors.removeLast();
      var maxCreditor = creditors.removeLast();

      double settlementAmount = maxDebtor.value.abs() < maxCreditor.value 
          ? maxDebtor.value.abs() 
          : maxCreditor.value;

      transactions.add(DebtTransaction(
        fromUserId: maxDebtor.key,
        toUserId: maxCreditor.key,
        amount: double.parse(settlementAmount.toStringAsFixed(2)),
      ));

      double remainingDebtorBalance = maxDebtor.value + settlementAmount;
      double remainingCreditorBalance = maxCreditor.value - settlementAmount;

      if (remainingDebtorBalance < -0.01) {
        debtors.add(MapEntry(maxDebtor.key, remainingDebtorBalance));
      }
      if (remainingCreditorBalance > 0.01) {
        creditors.add(MapEntry(maxCreditor.key, remainingCreditorBalance));
      }
    }

    return transactions;
  }
}
