import 'package:home_widget/home_widget.dart';

/// Bridges the Flutter side to the native Android AppWidget.
///
/// Call `updateBalanceWidget()` any time the net balance changes — e.g. from
/// `BalanceProvider.recalculateBalances()` after it recomputes, so the home
/// screen widget stays in sync with the app.
class WidgetService {
  // NOTE: replace with your actual applicationId from
  // android/app/build.gradle if it differs from this placeholder.
  static const String _androidWidgetProviderName = 'BalanceWidgetProvider';
  static const String _balanceDataKey = 'net_balance';
  static const String _lastUpdatedKey = 'net_balance_updated_at';

  static Future<void> updateBalanceWidget(double balance) async {
    await HomeWidget.saveWidgetData<double>(_balanceDataKey, balance);
    await HomeWidget.saveWidgetData<String>(
      _lastUpdatedKey,
      DateTime.now().toIso8601String(),
    );

    await HomeWidget.updateWidget(
      androidName: _androidWidgetProviderName,
    );
  }
}
