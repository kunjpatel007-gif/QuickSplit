import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  static String format(double amount) {
    return _formatter.format(amount);
  }

  static String formatCompact(double amount) {
    final value = _formatter.format(amount.abs());
    return amount < 0 ? '-$value' : '+$value';
  }

  static double roundToTwoDecimals(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
