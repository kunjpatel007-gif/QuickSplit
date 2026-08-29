import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';
import 'package:campus_quicksplit/presentation/widgets/staggered_list_item.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final balanceProvider = context.watch<BalanceProvider>();
    final userProvider = context.watch<UserProvider>();
    final netBalances = balanceProvider.balances;

    List<DebtTransaction> transactions = [];
    if (netBalances.isNotEmpty) {
      transactions = DebtSimplifier().simplifyDebts(netBalances);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settlements')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ExpenseProvider>().loadExpenses();
          await context.read<BalanceProvider>().recalculateBalances();
        },
        child: transactions.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  child: const EmptyState(
                    icon: Icons.check_circle,
                    message: 'No settlements needed!',
                  ),
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  final fromUser = userProvider.getUserById(tx.fromUserId);
                  final toUser = userProvider.getUserById(tx.toUserId);

                  if (fromUser == null || toUser == null) {
                    return const SizedBox.shrink();
                  }

                  return StaggeredListItem(
                    index: index,
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${fromUser.name} owes ${toUser.name}',
                                    style: tt.titleMedium,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(tx.amount),
                                  style: tt.titleLarge?.copyWith(
                                    color: cs.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                // UPI Button — only if you are the one paying!
                                if ((Platform.isAndroid || Platform.isIOS) &&
                                    userProvider.currentUser?.id == fromUser.id)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _handleUpiPayment(toUser, tx.amount),
                                    icon: const Icon(Icons.payment, size: 18),
                                    label: Text(
                                      toUser.upiId != null &&
                                              toUser.upiId!.isNotEmpty
                                          ? 'Pay via UPI'
                                          : 'Add UPI & Pay',
                                    ),
                                  ),
                                // Scan GPay QR — only if you are the one paying and they don't have UPI ID
                                if ((Platform.isAndroid || Platform.isIOS) &&
                                    userProvider.currentUser?.id ==
                                        fromUser.id &&
                                    (toUser.upiId == null ||
                                        toUser.upiId!.isEmpty))
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _scanGPayQr(toUser, tx.amount),
                                    icon: const Icon(
                                      Icons.qr_code_scanner,
                                      size: 18,
                                    ),
                                    label: const Text('Scan GPay QR'),
                                  ),
                                // Nudge via WhatsApp - only if you are the one receiving!
                                if ((Platform.isAndroid || Platform.isIOS) &&
                                    userProvider.currentUser?.id == toUser.id &&
                                    fromUser.phoneNumber != null &&
                                    fromUser.phoneNumber!.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () => _launchWhatsApp(
                                      fromUser.phoneNumber!,
                                      tx.amount,
                                    ),
                                    icon: const Icon(Icons.message, size: 18),
                                    label: const Text('Nudge'),
                                  ),
                                // Mark Settled with proof
                                TextButton.icon(
                                  onPressed: () => _showSettlementProofDialog(
                                    fromUser,
                                    toUser,
                                    tx.amount,
                                  ),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Mark Settled'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// Scans a GPay/UPI QR code, extracts the UPI ID, saves it, and launches payment
  Future<void> _scanGPayQr(User toUser, double amount) async {
    final scannedUpiId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _GPayQrScannerScreen(payeeName: toUser.name),
      ),
    );

    if (scannedUpiId != null && scannedUpiId.isNotEmpty && mounted) {
      // Save the UPI ID permanently to the user's profile
      final userProvider = context.read<UserProvider>();
      final updated = toUser.copyWith(upiId: scannedUpiId);
      await userProvider.updateUser(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved UPI ID: $scannedUpiId for ${toUser.name}'),
          ),
        );
        // Now launch UPI with the saved ID and pre-filled amount
        await _launchUpi(scannedUpiId, toUser.name, amount);
      }
    }
  }

  /// Handles UPI payment — if UPI ID is missing, prompts to add it first
  Future<void> _handleUpiPayment(User toUser, double amount) async {
    if (toUser.upiId != null && toUser.upiId!.isNotEmpty) {
      // UPI ID exists — launch directly
      await _launchUpi(toUser.upiId!, toUser.name, amount);
    } else {
      // UPI ID missing — ask the user to enter it
      final controller = TextEditingController();
      final newUpiId = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Add UPI ID for ${toUser.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter their UPI ID to pay directly.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'e.g. name@ybl or name@okhdfcbank',
                  prefixIcon: Icon(Icons.payment),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save & Pay'),
            ),
          ],
        ),
      );

      if (newUpiId != null && newUpiId.isNotEmpty && mounted) {
        // Save the UPI ID permanently to the user's profile
        final userProvider = context.read<UserProvider>();
        final updated = toUser.copyWith(upiId: newUpiId);
        await userProvider.updateUser(updated);

        // Now launch UPI with the saved ID
        await _launchUpi(newUpiId, toUser.name, amount);
      }
    }
  }

  /// Shows the settlement proof dialog, then ACTUALLY creates a settlement expense
  /// to mathematically zero out the debt in the ledger
  Future<void> _showSettlementProofDialog(
    User fromUser,
    User toUser,
    double amount,
  ) async {
    final txIdController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Settlement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${fromUser.name} is settling ${CurrencyFormatter.format(amount)} with ${toUser.name}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: txIdController,
              decoration: const InputDecoration(
                labelText: 'UPI Transaction ID (Optional)',
                hintText: 'e.g. T2308151234567890',
                prefixIcon: Icon(Icons.receipt_long),
                helperText: 'Stored locally for your records only.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, txIdController.text.trim()),
            child: const Text('Confirm Settlement'),
          ),
        ],
      ),
    );

    // result is null if cancelled, empty string if no TX ID entered, or the TX ID
    if (result != null && mounted) {
      final txLabel = result.isNotEmpty ? ' (TXN: $result)' : '';

      // === MATH FIX: Create a real "Settlement" expense to zero out the debt ===
      // fromUser paid toUser the settlement amount.
      // We model this as: fromUser paid `amount`, and toUser owes `amount`.
      // This perfectly cancels out the original debt in the balance calculation.
      final settlementExpense = Expense(
        title: 'Settlement: ${fromUser.name} → ${toUser.name}$txLabel',
        totalAmount: amount,
        category: 'Settlement',
        timestamp: DateTime.now(),
        isRecurring: false,
        isDeleted: false,
      );

      final payer = ExpensePayer(
        expenseId: 0, // Will be set by the provider
        userId: fromUser.id!,
        amountPaid: amount,
      );

      final split = ExpenseSplit(
        expenseId: 0, // Will be set by the provider
        userId: toUser.id!,
        amountOwed: amount,
      );

      final expenseProvider = context.read<ExpenseProvider>();
      await expenseProvider.addExpense(
        expense: settlementExpense,
        payers: [payer],
        splits: [split],
      );

      // Log the settlement to the tamper-evident audit trail
      final auditRepo = context.read<AuditRepository>();
      final auditService = AuditService();
      final auditEntry = await auditService.createAuditEntry(
        expenseId: 0,
        actionType: 'SETTLEMENT${result.isNotEmpty ? "|TXN:$result" : ""}',
        previousAmount: amount,
        newAmount: 0.0,
        auditRepo: auditRepo,
      );
      await auditRepo.insertAuditLog(auditEntry);

      // Reload balances so the UI reflects the zeroed-out debt
      if (mounted) {
        await context.read<BalanceProvider>().recalculateBalances();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isNotEmpty
                  ? '✓ Settlement recorded with TXN: $result'
                  : '✓ Settlement recorded',
            ),
          ),
        );
      }
    }
  }

  Future<void> _launchUpi(String upiId, String name, double amount) async {
    final url = Uri.parse('upi://pay?pa=$upiId&pn=$name&am=$amount&cu=INR');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI app found. Please install Google Pay, PhonePe, or Paytm.')),
      );
    }
  }

  Future<void> _launchWhatsApp(String phone, double amount) async {
    final message = Uri.encodeComponent(
      'Hey! You owe me ₹${amount.toStringAsFixed(2)} for our shared expenses on Campus QuickSplit.',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

/// Full-screen GPay QR scanner that extracts UPI ID from a payment QR code
class _GPayQrScannerScreen extends StatefulWidget {
  final String payeeName;
  const _GPayQrScannerScreen({required this.payeeName});

  @override
  State<_GPayQrScannerScreen> createState() => _GPayQrScannerScreenState();
}

class _GPayQrScannerScreenState extends State<_GPayQrScannerScreen> {
  MobileScannerController? _scannerController;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      // Parse UPI QR code format: upi://pay?pa=xyz@upi&pn=Name&...
      if (rawValue.toLowerCase().startsWith('upi://pay')) {
        final uri = Uri.tryParse(rawValue);
        if (uri != null) {
          final upiId = uri.queryParameters['pa'];
          if (upiId != null && upiId.isNotEmpty) {
            setState(() => _hasScanned = true);
            _scannerController?.stop();
            Navigator.pop(context, upiId);
            return;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan ${widget.payeeName}\'s GPay QR')),
      body: Stack(
        children: [
          MobileScanner(controller: _scannerController!, onDetect: _onDetect),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Point the camera at ${widget.payeeName}\'s GPay or any UPI QR code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
