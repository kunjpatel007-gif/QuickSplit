class ProRataEngine {
  Map<int, double> distributeOverhead({
    required Map<int, double> userDishTotals,
    required double totalOverhead,
  }) {
    if (userDishTotals.isEmpty) return {};

    double subtotal = 0.0;
    for (final amount in userDishTotals.values) {
      subtotal += amount;
    }

    if (subtotal == 0) return {};

    final Map<int, double> distribution = {};
    double calculatedTotal = 0.0;
    int maxDishUserId = userDishTotals.keys.first;
    double maxDishAmount = userDishTotals[maxDishUserId]!;

    userDishTotals.forEach((userId, dishTotal) {
      if (dishTotal > maxDishAmount) {
        maxDishAmount = dishTotal;
        maxDishUserId = userId;
      }
      final double fee = double.parse((totalOverhead * (dishTotal / subtotal)).toStringAsFixed(2));
      distribution[userId] = fee;
      calculatedTotal += fee;
    });

    final double remainder = double.parse((totalOverhead - calculatedTotal).toStringAsFixed(2));
    if (remainder != 0.0) {
      distribution[maxDishUserId] = double.parse(((distribution[maxDishUserId] ?? 0.0) + remainder).toStringAsFixed(2));
    }

    return distribution;
  }

  Map<int, double> calculateTotalWithOverhead({
    required Map<int, double> userDishTotals,
    required double totalOverhead,
  }) {
    final Map<int, double> overheads = distributeOverhead(
      userDishTotals: userDishTotals,
      totalOverhead: totalOverhead,
    );

    final Map<int, double> totals = {};
    userDishTotals.forEach((userId, dishTotal) {
      totals[userId] = double.parse((dishTotal + (overheads[userId] ?? 0.0)).toStringAsFixed(2));
    });

    return totals;
  }
}
