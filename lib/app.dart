import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:campus_quicksplit/core/theme/app_theme.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:campus_quicksplit/presentation/screens/add_expense/add_expense_screen.dart';
import 'package:campus_quicksplit/presentation/screens/onboarding/onboarding_screen.dart';

// NOTE: `import 'package:campus_quicksplit/data/models/expense.dart'` is a
// best guess at where `Expense` lives based on your clean-architecture split
// (lib/data, lib/domain, lib/presentation). Adjust the path if your model
// actually lives elsewhere (e.g. lib/domain/models/expense.dart).

class CampusQuickSplitApp extends StatefulWidget {
  const CampusQuickSplitApp({super.key});

  /// Exposed so the deep-link handler can push dialogs/navigation without
  /// needing a BuildContext from inside build() — the link can arrive before
  /// any widget in the tree has mounted (cold start).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<CampusQuickSplitApp> createState() => _CampusQuickSplitAppState();
}

class _CampusQuickSplitAppState extends State<CampusQuickSplitApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  Future<void> _initDeepLinkListener() async {
    // Cold start: app was launched BY the link.
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to read initial deep link: $e');
    }

    // Warm start: app already running, link arrives via stream.
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (err) => debugPrint('Deep link stream error: $err'),
    );
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme != 'quicksplit') return;

    if (uri.host == 'add') {
      final context = CampusQuickSplitApp.navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
        );
      }
      return;
    }

    if (uri.host != 'sync') return;

    final encoded = uri.queryParameters['data'];
    if (encoded == null || encoded.isEmpty) return;

    try {
      final normalized = base64Url.normalize(encoded);
      final decodedBytes = base64Url.decode(normalized);
      final decodedString = utf8.decode(decodedBytes);
      final Map<String, dynamic> payload = jsonDecode(decodedString);
      _showSyncConfirmationDialog(payload);
    } catch (e) {
      debugPrint('Failed to decode sync payload: $e');
      _showErrorSnackbar('Could not read the shared expense link.');
    }
  }

  void _showSyncConfirmationDialog(Map<String, dynamic> payload) {
    final context = CampusQuickSplitApp.navigatorKey.currentContext;
    if (context == null) return;

    final title = payload['title']?.toString() ?? 'Untitled expense';
    final amount = payload['totalAmount'] ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Incoming Shared Expense'),
        content: Text('Import "$title" for \$$amount into QuickSplit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _importSharedExpense(payload);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _importSharedExpense(Map<String, dynamic> payload) async {
    final context = CampusQuickSplitApp.navigatorKey.currentContext;
    if (context == null) return;

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userRepo = Provider.of<UserRepository>(context, listen: false);

    try {
      final expense = Expense(
        title: payload['title'] as String,
        totalAmount: (payload['totalAmount'] as num).toDouble(),
        category: (payload['category'] as String?) ?? 'Uncategorized',
        timestamp: DateTime.now(),
        isRecurring: false,
        isDeleted: false,
      );
      
      List<ExpensePayer> payers = [];
      if (payload['payers'] != null) {
        for (var p in payload['payers']) {
          User? user = await userRepo.getUserByName(p['userName']);
          if (user == null) {
            await userProvider.addUser(p['userName']);
            await userProvider.loadUsers();
            user = await userRepo.getUserByName(p['userName']);
          }
          if (user != null) {
            payers.add(ExpensePayer(expenseId: 0, userId: user.id!, amountPaid: (p['amountPaid'] as num).toDouble()));
          }
        }
      }

      List<ExpenseSplit> splits = [];
      if (payload['splits'] != null) {
        for (var s in payload['splits']) {
          User? user = await userRepo.getUserByName(s['userName']);
          if (user == null) {
            await userProvider.addUser(s['userName']);
            await userProvider.loadUsers();
            user = await userRepo.getUserByName(s['userName']);
          }
          if (user != null) {
            splits.add(ExpenseSplit(expenseId: 0, userId: user.id!, amountOwed: (s['amountOwed'] as num).toDouble()));
          }
        }
      }

      await expenseProvider.addExpense(
        expense: expense,
        payers: payers,
        splits: splits,
      );
    } catch (e) {
      debugPrint('Failed to import shared expense: $e');
      _showErrorSnackbar('Could not import the shared expense.');
    }
  }

  void _showErrorSnackbar(String message) {
    final context = CampusQuickSplitApp.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, UserProvider>(
      builder: (context, themeProvider, userProvider, child) {
        return MaterialApp(
          navigatorKey: CampusQuickSplitApp.navigatorKey,
          title: 'Campus QuickSplit',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: userProvider.currentUser == null 
              ? const OnboardingScreen() 
              : const DashboardScreen(),
        );
      },
    );
  }
}
