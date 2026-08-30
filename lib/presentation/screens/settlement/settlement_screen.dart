import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/utils/intent_utils.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  @override
  @override
  Widget build(BuildContext context) {
    final balanceProvider = context.watch<BalanceProvider>();
    final userProvider = context.watch<UserProvider>();
    final netBalances = balanceProvider.balances;

    List<DebtTransaction> transactions = [];
    if (netBalances.isNotEmpty) {
      transactions = DebtSimplifier().simplifyDebts(netBalances);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131314),
        title: Text('SETTLEMENTS', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFFe5e2e3))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFF514532), height: 2),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ExpenseProvider>().loadExpenses();
          await context.read<BalanceProvider>().recalculateBalances();
        },
        child: transactions.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(child: Text('NO SETTLEMENTS NEEDED', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF514532))))
                  )
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  final fromUser = userProvider.getUserById(tx.fromUserId);
                  final toUser = userProvider.getUserById(tx.toUserId);

                  if (fromUser == null || toUser == null) return const SizedBox.shrink();

                  final bool amIPaying = userProvider.currentUser?.id == fromUser.id;
                  final bool amIReceiving = userProvider.currentUser?.id == toUser.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF201f20),
                      border: Border.all(color: const Color(0xFF514532)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${fromUser.name.toUpperCase()} OWES', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF9e8f78), fontSize: 10)),
                                  Text(toUser.name.toUpperCase(), style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.format(tx.amount), style: GoogleFonts.jetBrainsMono(color: const Color(0xFFffb4ab), fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if ((Platform.isAndroid || Platform.isIOS) && amIPaying)
                              _buildActionBtn(
                                icon: Icons.payment,
                                label: toUser.upiId != null && toUser.upiId!.isNotEmpty ? 'PAY VIA UPI' : 'ADD UPI & PAY',
                                color: const Color(0xFFffb800),
                                onTap: () => _handleUpiPayment(toUser, tx.amount),
                              ),
                            if ((Platform.isAndroid || Platform.isIOS) && amIPaying)
                              _buildActionBtn(
                                icon: Icons.qr_code_scanner,
                                label: 'SCAN GPAY QR',
                                color: const Color(0xFFe5e2e3),
                                onTap: () => _scanGPayQr(toUser, tx.amount),
                              ),
                            if ((Platform.isAndroid || Platform.isIOS) && amIReceiving && fromUser.phoneNumber != null && fromUser.phoneNumber!.isNotEmpty)
                              _buildActionBtn(
                                icon: Icons.message,
                                label: 'NUDGE',
                                color: const Color(0xFFb8c3ff),
                                onTap: () => IntentUtils.launchWhatsApp(context, fromUser.phoneNumber!, tx.amount),
                              ),
                            _buildActionBtn(
                              icon: Icons.check,
                              label: 'MARK SETTLED',
                              color: const Color(0xFF16A34A),
                              onTap: () => _showSettlementProofDialog(fromUser, toUser, tx.amount),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF131314),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _scanGPayQr(User toUser, double amount) async {
    final upiId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _GPayQrScannerScreen(payeeName: toUser.name),
      ),
    );

    if (upiId != null && upiId.isNotEmpty && mounted) {
      final userProvider = context.read<UserProvider>();
      final updated = toUser.copyWith(upiId: upiId);
      await userProvider.updateUser(updated);
      
      // ignore: use_build_context_synchronously
      await IntentUtils.launchUpi(context, upiId, toUser.name, amount);
    }
  }

  Future<void> _handleUpiPayment(User toUser, double amount) async {
    if (toUser.upiId != null && toUser.upiId!.isNotEmpty) {
      // UPI ID exists — launch directly
      await IntentUtils.launchUpi(context, toUser.upiId!, toUser.name, amount);
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
        await IntentUtils.launchUpi(context, newUpiId, toUser.name, amount);
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
