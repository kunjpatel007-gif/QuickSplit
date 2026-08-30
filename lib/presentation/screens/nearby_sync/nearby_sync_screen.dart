import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/core/utils/sync_utils.dart';
/// "Nearby Sync" screen — uses `nearby_connections`
/// (Bluetooth/Wi-Fi Direct under the hood).
/// Supports:
///   - Full DB sync (all expenses + users)
///   - Single-expense share (pass `expenseToShare`)
class NearbySyncScreen extends StatefulWidget {
  final Expense? expenseToShare;

  const NearbySyncScreen({super.key, this.expenseToShare});

  @override
  State<NearbySyncScreen> createState() => _NearbySyncScreenState();
}

class _NearbySyncScreenState extends State<NearbySyncScreen> {
  static const String _serviceId = 'com.campusquicksplit.nearby.sync';
  static const Strategy _strategy = Strategy.P2P_STAR;

  String _status = 'Idle';
  String? _connectedEndpointId;
  bool _isBusy = false;
  bool _isSending = false;
  int _syncedCount = 0;

  @override
  void dispose() {
    _teardownConnections();
    super.dispose();
  }

  Future<void> _teardownConnections() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
  }

  Future<bool> _ensurePermissions() async {
    if (_isBusy) return true;

    final statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();

    bool locationGranted = statuses[Permission.location]?.isGranted ?? false;

    if (!locationGranted) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permissions Denied'),
          content: const Text(
            'Nearby Sync requires Location, Bluetooth, and Nearby Devices (Wi-Fi) permissions.\n\n'
            'Please grant them in Settings to continue.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hardware Required'),
        content: const Text(
          'Permissions granted!\n\n'
          'Please ensure Location, Bluetooth, and Wi-Fi are all turned ON before continuing.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    return proceed == true;
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (fromEndpointId, payload) async {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          await _handleIncomingPayload(payload.bytes!);
        }
      },
      onPayloadTransferUpdate: (fromEndpointId, update) {},
    );
    setState(() {
      _connectedEndpointId = endpointId;
      _status = 'Connected with ${info.endpointName} — ready to sync.';
    });
  }

  void _onDisconnected() {
    setState(() {
      _connectedEndpointId = null;
      _isBusy = false;
      _status = 'Disconnected.';
    });
  }

  Future<void> _startAdvertising() async {
    if (!await _ensurePermissions()) {
      setState(() => _status = 'Missing required permissions.');
      return;
    }
    final localName = context.read<UserProvider>().currentUser?.name ?? 'QuickSplit User';
    setState(() {
      _isBusy = true;
      _status = 'Advertising as "$localName" — waiting for peer…';
    });

    await Nearby().startAdvertising(
      localName,
      _strategy,
      serviceId: _serviceId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: (endpointId, status) {
        if (status == Status.CONNECTED) {
          setState(() => _status = 'Connected! Ready to sync.');
        } else {
          setState(() => _status = 'Connection status: $status');
        }
      },
      onDisconnected: (_) => _onDisconnected(),
    );
  }

  Future<void> _startDiscovery() async {
    if (!await _ensurePermissions()) {
      setState(() => _status = 'Missing required permissions.');
      return;
    }
    final localName = context.read<UserProvider>().currentUser?.name ?? 'QuickSplit User';
    setState(() {
      _isBusy = true;
      _status = 'Discovering nearby devices…';
    });

    try {
      await Nearby().startDiscovery(
        localName,
        _strategy,
        serviceId: _serviceId,
        onEndpointFound: (endpointId, name, serviceId) {
          setState(() => _status = 'Found "$name" — connecting…');
          Nearby().requestConnection(
            localName,
            endpointId,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                setState(() => _status = 'Connected! Ready to sync.');
              } else {
                setState(() => _status = 'Connection status: $status');
              }
            },
            onDisconnected: (_) => _onDisconnected(),
          );
        },
        onEndpointLost: (endpointId) {
          setState(() => _status = 'A nearby device went out of range.');
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _status = 'Discovery failed: $e\n\nMake sure Wi-Fi, Bluetooth, and Location are ON.';
        });
      }
    }
  }

  // ─── Send full DB ────────────────────────────────────────────────────────────

  Future<void> _sendFullDb() async {
    final endpointId = _connectedEndpointId;
    if (endpointId == null) {
      setState(() => _status = 'No connected peer. Advertise or Discover first.');
      return;
    }

    setState(() {
      _isSending = true;
      _status = 'Collecting all expenses from DB…';
    });

    final expenseRepo = context.read<ExpenseRepository>();
    final userProvider = context.read<UserProvider>();

    // Serialize all expenses
    final allExpenses = context.read<ExpenseProvider>().expenses;
    final expensesJson = <Map<String, dynamic>>[];

    for (final expense in allExpenses) {
      if (expense.id == null) continue;
      final payers = await expenseRepo.getPayersForExpense(expense.id!);
      final splits = await expenseRepo.getSplitsForExpense(expense.id!);

      final payersJson = payers.map((p) {
        final user = userProvider.users.firstWhere(
          (u) => u.id == p.userId,
          orElse: () => User(name: 'Unknown', createdAt: DateTime.now()),
        );
        return SyncUtils.buildUserPayload(user, p.amountPaid, 'amountPaid');
      }).toList();

      final splitsJson = splits.map((s) {
        final user = userProvider.users.firstWhere(
          (u) => u.id == s.userId,
          orElse: () => User(name: 'Unknown', createdAt: DateTime.now()),
        );
        return SyncUtils.buildUserPayload(user, s.amountOwed, 'amountOwed');
      }).toList();

      expensesJson.add({
        'title': expense.title,
        'totalAmount': expense.totalAmount,
        'category': expense.category,
        'timestamp': expense.timestamp.toIso8601String(),
        'isRecurring': expense.isRecurring,
        'payers': payersJson,
        'splits': splitsJson,
      });
    }

    // Serialize all users (so the receiver can match by syncId)
    final usersJson = userProvider.users.map((u) => {
      'syncId': u.syncId,
      'userName': u.name,
      'upiId': u.upiId,
      'phoneNumber': u.phoneNumber,
    }).toList();

    final payload = {
      'type': 'full_sync',
      'expenseCount': expensesJson.length,
      'users': usersJson,
      'expenses': expensesJson,
    };

    final rawBytes = utf8.encode(jsonEncode(payload));
    final bytes = gzip.encode(rawBytes);
    await Nearby().sendBytesPayload(endpointId, bytes);

    if (mounted) {
      setState(() {
        _isSending = false;
        _status = 'Sent full DB: ${expensesJson.length} expense(s) + ${usersJson.length} user(s).';
      });
    }
  }

  // ─── Send single expense ─────────────────────────────────────────────────────

  Future<void> _sendSingleExpense() async {
    final endpointId = _connectedEndpointId;
    final expense = widget.expenseToShare;

    if (endpointId == null) {
      setState(() => _status = 'No connected peer.');
      return;
    }
    if (expense == null) {
      setState(() => _status = 'No expense was passed to share.');
      return;
    }

    setState(() => _isSending = true);

    final expenseRepo = context.read<ExpenseRepository>();
    final userProvider = context.read<UserProvider>();

    final payers = await expenseRepo.getPayersForExpense(expense.id!);
    final splits = await expenseRepo.getSplitsForExpense(expense.id!);

    final payersJson = payers.map((p) {
      final user = userProvider.users.firstWhere(
        (u) => u.id == p.userId,
        orElse: () => User(name: 'Unknown', createdAt: DateTime.now()),
      );
      return SyncUtils.buildUserPayload(user, p.amountPaid, 'amountPaid');
    }).toList();

    final splitsJson = splits.map((s) {
      final user = userProvider.users.firstWhere(
        (u) => u.id == s.userId,
        orElse: () => User(name: 'Unknown', createdAt: DateTime.now()),
      );
      return SyncUtils.buildUserPayload(user, s.amountOwed, 'amountOwed');
    }).toList();

    final payload = {
      'type': 'single_expense',
      'title': expense.title,
      'totalAmount': expense.totalAmount,
      'category': expense.category,
      'timestamp': expense.timestamp.toIso8601String(),
      'isRecurring': expense.isRecurring,
      'payers': payersJson,
      'splits': splitsJson,
    };

    await Nearby().sendBytesPayload(endpointId, utf8.encode(jsonEncode(payload)));
    if (mounted) {
      setState(() {
        _isSending = false;
        _status = 'Sent "${expense.title}".';
      });
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────────

  Future<void> _handleIncomingPayload(List<int> bytes) async {
    try {
      List<int> decodedBytes;
      try {
        decodedBytes = gzip.decode(bytes);
      } catch (_) {
        decodedBytes = bytes; // Fallback to raw if not compressed
      }
      final map = jsonDecode(utf8.decode(decodedBytes)) as Map<String, dynamic>;
      final type = map['type'] as String?;

      if (type == 'profile') {
        await _handleProfilePayload(map);
        return;
      }

      if (type == 'full_sync') {
        await _handleFullSyncPayload(map);
        return;
      }

      // Legacy / single_expense
      await _handleSingleExpensePayload(map);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Sync failed: $e';
        });
      }
    }
  }

  Future<void> _handleProfilePayload(Map<String, dynamic> map) async {
    final name = map['userName'] as String;
    final syncId = map['syncId'] as String?;
    final userProvider = context.read<UserProvider>();
    final userRepo = context.read<UserRepository>();

    User? user;
    if (syncId != null && syncId.isNotEmpty) {
      user = await userRepo.getUserBySyncId(syncId);
    }
    user ??= await userRepo.getUserByName(name);

    if (user == null) {
      await userRepo.insertUser(User(syncId: syncId ?? '', name: name, createdAt: DateTime.now()));
      await userProvider.loadUsers();
      user = syncId != null && syncId.isNotEmpty
          ? await userRepo.getUserBySyncId(syncId)
          : await userRepo.getUserByName(name);
    }

    if (user != null) {
      final upi = map['upiId'] as String?;
      final phone = map['phoneNumber'] as String?;
      if ((upi != null && upi.isNotEmpty) || (phone != null && phone.isNotEmpty)) {
        await userProvider.updateUser(user.copyWith(
          upiId: upi ?? user.upiId,
          phoneNumber: phone ?? user.phoneNumber,
          name: name,
        ));
      }
    }

    if (mounted) setState(() => _status = 'Synced profile: "$name".');
  }

  Future<void> _handleFullSyncPayload(Map<String, dynamic> map) async {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    final userRepo = context.read<UserRepository>();
    final expenseProvider = context.read<ExpenseProvider>();

    setState(() => _status = 'Receiving full DB…');

    // 1. Upsert all users first so expense resolution works
    final users = map['users'] as List<dynamic>? ?? [];
    for (final u in users) {
      final m = u as Map<String, dynamic>;
      final syncId = m['syncId'] as String?;
      final name = m['userName'] as String;
      User? existing;
      if (syncId != null && syncId.isNotEmpty) existing = await userRepo.getUserBySyncId(syncId);
      existing ??= await userRepo.getUserByName(name);
      if (existing == null) {
        await userRepo.insertUser(User(
          syncId: syncId ?? '',
          name: name,
          upiId: m['upiId'] as String?,
          phoneNumber: m['phoneNumber'] as String?,
          createdAt: DateTime.now(),
        ));
      }
    }
    if (mounted) await userProvider.loadUsers();

    // 2. Import each expense
    final expenses = map['expenses'] as List<dynamic>? ?? [];
    int added = 0;
    int skipped = 0;

    for (final e in expenses) {
      final m = e as Map<String, dynamic>;
      final title = m['title'] as String;
      final amount = (m['totalAmount'] as num).toDouble();
      final ts = m['timestamp'] != null
          ? DateTime.parse(m['timestamp'] as String)
          : DateTime.now();

      // Dedup check
      final existing = expenseProvider.expenses;
      final isDuplicate = existing.any((ex) =>
          ex.title == title &&
          ex.totalAmount == amount &&
          ex.timestamp.year == ts.year &&
          ex.timestamp.month == ts.month &&
          ex.timestamp.day == ts.day);

      if (isDuplicate) {
        skipped++;
        continue;
      }

      final expense = Expense(
        title: title,
        totalAmount: amount,
        category: (m['category'] as String?) ?? 'Uncategorized',
        timestamp: ts,
        isRecurring: (m['isRecurring'] as bool?) ?? false,
        isDeleted: false,
      );

      final payers = await _resolvePayersFromJson(m['payers'], userRepo, userProvider);
      final splits = await _resolveSplitsFromJson(m['splits'], userRepo, userProvider);

      final res = await expenseProvider.addExpense(expense: expense, payers: payers, splits: splits);
      if (res == -1) {
        skipped++;
      } else {
        added++;
      }

      if (mounted) setState(() => _status = 'Importing… ($added imported, $skipped skipped)');
    }

    if (mounted) {
      await context.read<ExpenseProvider>().loadExpenses();
      await context.read<UserProvider>().loadUsers();
      await context.read<BalanceProvider>().recalculateBalances();
      setState(() {
        _syncedCount = added;
        _status = 'Full sync done! Imported $added expense(s), skipped $skipped duplicate(s).';
      });
    }
  }

  Future<void> _handleSingleExpensePayload(Map<String, dynamic> map) async {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    final userRepo = context.read<UserRepository>();
    final expenseProvider = context.read<ExpenseProvider>();

    final title = map['title'] as String;
    final amount = (map['totalAmount'] as num).toDouble();
    final ts = map['timestamp'] != null
        ? DateTime.parse(map['timestamp'] as String)
        : DateTime.now();

    final isDuplicate = expenseProvider.expenses.any((ex) => SyncUtils.isDuplicateExpense(ex, title, amount, ts));

    if (isDuplicate) {
      if (mounted) setState(() => _status = 'Skipped duplicate: "$title".');
      return;
    }

    final expense = Expense(
      title: title,
      totalAmount: amount,
      category: (map['category'] as String?) ?? 'Uncategorized',
      timestamp: ts,
      isRecurring: (map['isRecurring'] as bool?) ?? false,
      isDeleted: false,
    );

    final payers = await _resolvePayersFromJson(map['payers'], userRepo, userProvider);
    final splits = await _resolveSplitsFromJson(map['splits'], userRepo, userProvider);

    await expenseProvider.addExpense(expense: expense, payers: payers, splits: splits);
    if (mounted) {
      await context.read<ExpenseProvider>().loadExpenses();
      await context.read<BalanceProvider>().recalculateBalances();
      setState(() => _status = 'Received and saved "$title".');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────



  Future<List<ExpensePayer>> _resolvePayersFromJson(
    dynamic payersRaw,
    UserRepository userRepo,
    UserProvider userProvider,
  ) async {
    final result = <ExpensePayer>[];
    if (payersRaw == null) return result;
    for (final p in payersRaw as List<dynamic>) {
      final m = p as Map<String, dynamic>;
      final user = await SyncUtils.resolveUser(m, userRepo, userProvider);
      if (user != null) {
        result.add(ExpensePayer(
          expenseId: 0,
          userId: user.id!,
          amountPaid: (m['amountPaid'] as num).toDouble(),
        ));
      }
    }
    return result;
  }

  Future<List<ExpenseSplit>> _resolveSplitsFromJson(
    dynamic splitsRaw,
    UserRepository userRepo,
    UserProvider userProvider,
  ) async {
    final result = <ExpenseSplit>[];
    if (splitsRaw == null) return result;
    for (final s in splitsRaw as List<dynamic>) {
      final m = s as Map<String, dynamic>;
      final user = await SyncUtils.resolveUser(m, userRepo, userProvider);
      if (user != null) {
        result.add(ExpenseSplit(
          expenseId: 0,
          userId: user.id!,
          amountOwed: (m['amountOwed'] as num).toDouble(),
        ));
      }
    }
    return result;
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasExpense = widget.expenseToShare != null;
    final isConnected = _connectedEndpointId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Sync')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _status.contains('done') || _status.contains('Synced') || _status.contains('Sent')
                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                  : _status.contains('fail') || _status.contains('Fail') || _status.contains('Denied')
                      ? cs.errorContainer
                      : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected ? Icons.link : Icons.link_off,
                          size: 16,
                          color: isConnected ? const Color(0xFF16A34A) : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnected ? 'Connected' : 'Not connected',
                          style: tt.labelSmall?.copyWith(
                            color: isConnected ? const Color(0xFF16A34A) : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_status, style: tt.bodyMedium),
                    if (_syncedCount > 0) ...[
                      const SizedBox(height: 4),
                      Text('$_syncedCount expense(s) imported this session.',
                          style: tt.bodySmall?.copyWith(color: const Color(0xFF16A34A))),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Step 1: Establish connection
            Text('Step 1 — Connect', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Advertise'),
                    onPressed: _isBusy ? null : _startAdvertising,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Discover'),
                    onPressed: _isBusy ? null : _startDiscovery,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Step 2: Sync
            Text('Step 2 — Sync Data', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),

            // Full DB Sync (always shown, primary action)
            FilledButton.icon(
              icon: _isSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              label: const Text('Full DB Sync (Send All Expenses)'),
              onPressed: isConnected && !_isSending ? _sendFullDb : null,
            ),

            const SizedBox(height: 10),

            // Single expense (only shown when passed)
            if (hasExpense) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.send),
                label: Text('Send "${widget.expenseToShare!.title}" only'),
                onPressed: isConnected && !_isSending ? _sendSingleExpense : null,
              ),
              const SizedBox(height: 10),
            ],

            const Spacer(),

            // Stop
            OutlinedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop / Reset'),
              onPressed: () async {
                await _teardownConnections();
                if (mounted) {
                  setState(() {
                    _isBusy = false;
                    _isSending = false;
                    _connectedEndpointId = null;
                    _syncedCount = 0;
                    _status = 'Idle';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
