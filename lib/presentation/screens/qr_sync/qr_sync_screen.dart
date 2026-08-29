import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class QrSyncScreen extends StatefulWidget {
  const QrSyncScreen({Key? key}) : super(key: key);

  @override
  State<QrSyncScreen> createState() => _QrSyncScreenState();
}

class _QrSyncScreenState extends State<QrSyncScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _selectedExpenseIds = {};
  MobileScannerController? _scannerController;
  final TextEditingController _pasteController = TextEditingController();
  List<Map<String, dynamic>>? _scannedExpenses;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (!Platform.isWindows) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController?.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  Future<String> _generatePayload(List<Expense> expenses) async {
    final expenseRepo = Provider.of<ExpenseRepository>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    List<Map<String, dynamic>> payloadList = [];

    // First, add all user profiles with syncIds
    for (var user in userProvider.users) {
      payloadList.add({
        'type': 'profile',
        'syncId': user.syncId,
        'userName': user.name,
        'upiId': user.upiId,
        'phoneNumber': user.phoneNumber,
      });
    }

    for (var e in expenses) {
      final payers = await expenseRepo.getPayersForExpense(e.id!);
      final splits = await expenseRepo.getSplitsForExpense(e.id!);
      
      final payersJson = payers.map((p) {
        final user = userProvider.users.firstWhere((u) => u.id == p.userId, orElse: () => User(name: 'Unknown', createdAt: DateTime.now()));
        return {'syncId': user.syncId, 'userName': user.name, 'amountPaid': p.amountPaid};
      }).toList();

      final splitsJson = splits.map((s) {
        final user = userProvider.users.firstWhere((u) => u.id == s.userId, orElse: () => User(name: 'Unknown', createdAt: DateTime.now()));
        return {'syncId': user.syncId, 'userName': user.name, 'amountOwed': s.amountOwed};
      }).toList();

      payloadList.add({
        'title': e.title,
        'totalAmount': e.totalAmount,
        'category': e.category,
        'timestamp': e.timestamp.toIso8601String(),
        'payers': payersJson,
        'splits': splitsJson,
      });
    }
    
    final jsonBytes = utf8.encode(jsonEncode(payloadList));
    final compressedBytes = gzip.encode(jsonBytes);
    return base64Encode(compressedBytes);
  }

  void _shareViaWhatsApp(String base64String, {bool isProfile = false}) {
    final text = isProfile ? 'Import my profile in QuickSplit:' : 'Import my expenses in QuickSplit:';
    Share.share('$text https://quicksplit.app/sync?data=$base64String');
  }

  void _processScannedData(String data) {
    try {
      final decodedBytes = base64Decode(data);
      String jsonString;
      
      // Try to decompress with gzip first, fallback to raw utf8 if it's an old uncompressed QR
      try {
        final decompressedBytes = gzip.decode(decodedBytes);
        jsonString = utf8.decode(decompressedBytes);
      } catch (_) {
        jsonString = utf8.decode(decodedBytes);
      }
      
      final List<dynamic> decoded = jsonDecode(jsonString);
      setState(() {
        _scannedExpenses = decoded.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR code or payload format')),
      );
    }
  }

  Future<void> _importExpenses() async {
    if (_scannedExpenses == null) return;
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userRepo = Provider.of<UserRepository>(context, listen: false);
    final expenseRepo = Provider.of<ExpenseRepository>(context, listen: false);
    
    int importedCount = 0;
    int skippedCount = 0;
    
    for (final expenseData in _scannedExpenses!) {
      // Handle Profile Payload
      if (expenseData['type'] == 'profile') {
        final name = expenseData['userName'] as String;
        final syncId = expenseData['syncId'] as String?;
        
        User? user;
        if (syncId != null && syncId.isNotEmpty) {
          user = await userRepo.getUserBySyncId(syncId);
        }
        user ??= await userRepo.getUserByName(name);
        
        if (user == null) {
          final newUser = User(
            syncId: syncId ?? '',
            name: name,
            createdAt: DateTime.now(),
          );
          await userRepo.insertUser(newUser);
          await userProvider.loadUsers();
        } else {
          // Update existing user's details
          final upi = expenseData['upiId'] as String?;
          final phone = expenseData['phoneNumber'] as String?;
          await userProvider.updateUser(user.copyWith(
            upiId: upi ?? user.upiId,
            phoneNumber: phone ?? user.phoneNumber,
            name: name,
          ));
        }
        continue;
      }

      // === Settlement Deduplication ===
      // If this is a Settlement expense with a UPI TXN ID, check if we already have it
      final category = expenseData['category'] as String? ?? 'Uncategorized';
      final title = expenseData['title'] as String? ?? '';
      if (category == 'Settlement' && title.contains('TXN:')) {
        // Extract TXN ID from the title
        final txnMatch = RegExp(r'TXN:\s*(\S+)').firstMatch(title);
        if (txnMatch != null) {
          final txnId = txnMatch.group(1)!.replaceAll(')', '');
          // Check if this TXN already exists in our local expenses
          final existingExpenses = await expenseRepo.getAllActiveExpenses(limit: 999, offset: 0);
          final alreadyExists = existingExpenses.any((e) =>
              e.category == 'Settlement' && e.title.contains(txnId));
          if (alreadyExists) {
            skippedCount++;
            continue; // Skip duplicate settlement
          }
        }
      }

      // Handle Expense Payload
      final expense = Expense(
        title: title,
        totalAmount: (expenseData['totalAmount'] as num).toDouble(),
        category: category,
        timestamp: DateTime.parse(expenseData['timestamp']),
        isRecurring: false,
        isDeleted: false,
      );
      
      // Deduplication check
      final existingExpenses = expenseProvider.expenses;
      bool isDuplicate = false;
      for (var ex in existingExpenses) {
        if (ex.title == expense.title && ex.totalAmount == expense.totalAmount) {
          if (ex.timestamp.year == expense.timestamp.year && 
              ex.timestamp.month == expense.timestamp.month && 
              ex.timestamp.day == expense.timestamp.day) {
            isDuplicate = true;
            break;
          }
        }
      }
      
      if (isDuplicate) {
        skippedCount++;
        continue;
      }
      
      // Helper to resolve a user from a payer/split entry
      Future<User?> resolveUser(Map<String, dynamic> entry) async {
        final syncId = entry['syncId'] as String?;
        final userName = entry['userName'] as String;
        User? user;
        if (syncId != null && syncId.isNotEmpty) {
          user = await userRepo.getUserBySyncId(syncId);
        }
        user ??= await userRepo.getUserByName(userName);
        if (user == null) {
          final newUser = User(syncId: syncId ?? '', name: userName, createdAt: DateTime.now());
          await userRepo.insertUser(newUser);
          await userProvider.loadUsers();
          if (syncId != null && syncId.isNotEmpty) {
            user = await userRepo.getUserBySyncId(syncId);
          } else {
            user = await userRepo.getUserByName(userName);
          }
        }
        return user;
      }

      List<ExpensePayer> payers = [];
      if (expenseData['payers'] != null) {
        for (var p in expenseData['payers']) {
          final user = await resolveUser(p as Map<String, dynamic>);
          if (user != null) {
            payers.add(ExpensePayer(expenseId: 0, userId: user.id!, amountPaid: (p['amountPaid'] as num).toDouble()));
          }
        }
      }

      List<ExpenseSplit> splits = [];
      if (expenseData['splits'] != null) {
        for (var s in expenseData['splits']) {
          final user = await resolveUser(s as Map<String, dynamic>);
          if (user != null) {
            splits.add(ExpenseSplit(expenseId: 0, userId: user.id!, amountOwed: (s['amountOwed'] as num).toDouble()));
          }
        }
      }

      try {
        await expenseProvider.addExpense(
          expense: expense,
          payers: payers,
          splits: splits,
        );
        importedCount++;
      } catch (e) {
        skippedCount++; // Count as duplicate/error and skip
      }
    }

    if (importedCount > 0) {
      await context.read<BalanceProvider>().recalculateBalances();
    }
    
    if (!mounted) return;
    
    final msg = skippedCount > 0
        ? '$importedCount expenses imported, $skippedCount duplicate settlements skipped'
        : '$importedCount expenses imported successfully';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
    setState(() {
      _scannedExpenses = null;
    });
  }

  Widget _buildGenerateTab() {
    final cs = Theme.of(context).colorScheme;
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final expenses = provider.expenses;
        
        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Show My Profile QR'),
                onPressed: () async {
                  final me = Provider.of<UserProvider>(context, listen: false).currentUser;
                  if (me != null) {
                    final payload = [
                      {
                        'type': 'profile',
                        'syncId': me.syncId,
                        'userName': me.name,
                        'upiId': me.upiId,
                        'phoneNumber': me.phoneNumber,
                      }
                    ];
                    final base64String = base64Encode(utf8.encode(jsonEncode(payload)));
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('My Profile QR'),
                        content: SizedBox(
                          width: 250,
                          height: 250,
                          child: QrImageView(
                            data: base64String,
                            size: 250,
                            backgroundColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _shareViaWhatsApp(base64String, isProfile: true);
                            },
                            child: const Text('Share Link'),
                          ),
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
                        ],
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 32),
              
              if (expenses.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('No expenses to share yet!')),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    'To prevent database corruption and preserve audit logs, you can only sync your entire database history at once.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<String>(
                  future: _generatePayload(expenses),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    );
                  }
                  final payload = snapshot.data!;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: QrImageView(
                          data: payload,
                          size: 250,
                          backgroundColor: cs.onSurface,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Share via WhatsApp'),
                          onPressed: () => _shareViaWhatsApp(payload),
                        ),
                      ),
                    ],
                  );
                },
              ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildScanTab() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (_scannedExpenses != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Preview Scanned Expenses', style: tt.titleMedium),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _scannedExpenses!.length,
              itemBuilder: (context, index) {
                final item = _scannedExpenses![index];
                final isProfile = item['type'] == 'profile';
                final isExpense = item['type'] == 'expense' || item['type'] == null; // null for backward compatibility
                
                if (isProfile) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(item['userName'] ?? 'Unknown Profile'),
                    subtitle: const Text('Profile Data'),
                  );
                } else if (isExpense) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.receipt)),
                    title: Text(item['title'] ?? 'Unknown Expense'),
                    trailing: Text(CurrencyFormatter.format(item['totalAmount'] ?? 0.0)),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _scannedExpenses = null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _importExpenses,
                  child: const Text('Import All'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (Platform.isWindows) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _pasteController,
              decoration: const InputDecoration(
                labelText: 'Paste Base64 Payload',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                if (_pasteController.text.isNotEmpty) {
                  _processScannedData(_pasteController.text);
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _processScannedData(barcode.rawValue!);
                break;
              }
            }
          },
        ),
        Center(
          child: Icon(Icons.qr_code_scanner, size: 250, color: cs.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Expenses'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Generate QR'),
            Tab(text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGenerateTab(),
          _buildScanTab(),
        ],
      ),
    );
  }
}
