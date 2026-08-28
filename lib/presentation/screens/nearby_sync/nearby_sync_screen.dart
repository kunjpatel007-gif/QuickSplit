import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';

/// "Nearby Sync" screen — uses `nearby_connections`
/// (Bluetooth/Wi-Fi Direct under the hood).
/// handles larger JSON payloads more reliably than an NDEF NFC tag would.
class NearbySyncScreen extends StatefulWidget {
  final Expense? expenseToShare;

  const NearbySyncScreen({super.key, this.expenseToShare});

  @override
  State<NearbySyncScreen> createState() => _NearbySyncScreenState();
}

class _NearbySyncScreenState extends State<NearbySyncScreen> {
  static const String _serviceId = 'com.campusquicksplit.nearby.sync';
  static const Strategy _strategy = Strategy.P2P_STAR;
  static const String _localDisplayName = 'QuickSplit User';

  String _status = 'Idle';
  String? _connectedEndpointId;
  bool _isBusy = false;

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
    if (!_isBusy) {
      // First explicitly request the required native permissions
      // Request all permissions (the package handles OS-specific skipping automatically if configured)
      final statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices, 
      ].request();
      
      // Determine what was granted
      bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
      
      // Bluetooth permissions might be permanentlyDenied/restricted on older Android versions where they don't exist
      bool btScanGranted = (statuses[Permission.bluetoothScan]?.isGranted ?? false) || (statuses[Permission.bluetoothScan]?.isRestricted ?? true);
      bool btAdvGranted = (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) || (statuses[Permission.bluetoothAdvertise]?.isRestricted ?? true);
      bool btConnGranted = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) || (statuses[Permission.bluetoothConnect]?.isRestricted ?? true);
      // We safely bypass strict verification of Bluetooth/Wi-Fi permissions here because
      // older Android versions (11, 12) report them as permanentlyDenied since they don't exist.
      // The .request() call above successfully prompts the user natively on Android 13+.
      if (!locationGranted) {
        if (!mounted) return false;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permissions Denied'),
            content: const Text(
              'Nearby Sync requires Location, Bluetooth, and Nearby Devices (Wi-Fi) permissions to function.\n\n'
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
      
      // Optionally remind user to turn ON Bluetooth / Location hardware if they granted permissions but the toggles are off
      if (!mounted) return false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hardware Required'),
          content: const Text(
            'Permissions granted!\n\n'
            'Please ensure your Location, Bluetooth, and Wi-Fi toggles are physically turned ON before continuing. '
            '(Android 13+ requires you to turn them on manually)',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      );
      return proceed == true;
    }
    return true;
  }

  Future<void> _startAdvertising() async {
    if (!await _ensurePermissions()) {
      setState(() => _status = 'Missing required permissions.');
      return;
    }

    final localName = Provider.of<UserProvider>(context, listen: false).currentUser?.name ?? 'QuickSplit User';

    setState(() {
      _isBusy = true;
      _status = 'Advertising as "$localName" — waiting for a peer…';
    });

    await Nearby().startAdvertising(
      localName,
      _strategy,
      serviceId: _serviceId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: (endpointId, status) {
        if (status == Status.CONNECTED) {
          setState(() => _status = 'Connected! Exchanging profiles…');
          _sendMyProfile(endpointId);
        } else {
          setState(() => _status = 'Connection result: $status');
        }
      },
      onDisconnected: (endpointId) => _onDisconnected(),
    );
  }

  Future<void> _startDiscovery() async {
    if (!await _ensurePermissions()) {
      setState(() => _status = 'Missing required permissions.');
      return;
    }

    final localName = Provider.of<UserProvider>(context, listen: false).currentUser?.name ?? 'QuickSplit User';

    setState(() {
      _isBusy = true;
      _status = 'Discovering nearby devices…';
    });

    await Nearby().startDiscovery(
      localName,
      _strategy,
      serviceId: _serviceId,
      onEndpointFound: (endpointId, name, serviceId) {
        Nearby().requestConnection(
          localName,
          endpointId,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: (id, status) {
            if (status == Status.CONNECTED) {
              setState(() => _status = 'Connected! Exchanging profiles…');
              _sendMyProfile(id);
            } else {
              setState(() => _status = 'Connection result: $status');
            }
          },
          onDisconnected: (id) => _onDisconnected(),
        );
      },
      onEndpointLost: (endpointId) {
        setState(() => _status = 'A nearby device went out of range.');
      },
    );
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (fromEndpointId, payload) async {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          await _handleIncomingPayload(payload.bytes!);
        }
      },
      onPayloadTransferUpdate: (fromEndpointId, payloadTransferUpdate) {},
    );
    setState(() {
      _connectedEndpointId = endpointId;
      _status = 'Authenticating with ${info.endpointName}…';
    });
  }

  Future<void> _sendMyProfile(String endpointId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final me = userProvider.currentUser;
    if (me == null) return;

    final payload = {
      'type': 'profile',
      'syncId': me.syncId,
      'userName': me.name,
      'upiId': me.upiId,
      'phoneNumber': me.phoneNumber,
    };
    await Nearby().sendBytesPayload(endpointId, utf8.encode(jsonEncode(payload)));
  }

  void _onDisconnected() {
    setState(() {
      _connectedEndpointId = null;
      _status = 'Disconnected.';
    });
  }

  Future<void> _handleIncomingPayload(List<int> bytes) async {
    try {
      final jsonString = utf8.decode(bytes);
      final Map<String, dynamic> map = jsonDecode(jsonString);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userRepo = Provider.of<UserRepository>(context, listen: false);

      // Handle Profile Payload
      if (map['type'] == 'profile') {
        final name = map['userName'] as String;
        final syncId = map['syncId'] as String?;
        
        User? user;
        // Try syncId first (UUID), fall back to name for backward compatibility
        if (syncId != null && syncId.isNotEmpty) {
          user = await userRepo.getUserBySyncId(syncId);
        }
        user ??= await userRepo.getUserByName(name);
        
        if (user == null) {
          // Create new user with the received syncId
          final newUser = User(
            syncId: syncId ?? '',
            name: name,
            createdAt: DateTime.now(),
          );
          await userRepo.insertUser(newUser);
          await userProvider.loadUsers();
          if (syncId != null && syncId.isNotEmpty) {
            user = await userRepo.getUserBySyncId(syncId);
          } else {
            user = await userRepo.getUserByName(name);
          }
        }
        
        if (user != null) {
          // Update details if they sent them
          final upi = map['upiId'] as String?;
          final phone = map['phoneNumber'] as String?;
          if ((upi != null && upi.isNotEmpty) || (phone != null && phone.isNotEmpty)) {
            await userProvider.updateUser(user.copyWith(
              upiId: upi ?? user.upiId,
              phoneNumber: phone ?? user.phoneNumber,
              name: name, // Update name in case they changed it
            ));
          }
        }
        
        if (mounted) {
          setState(() => _status = 'Synced profile with "$name".');
        }
        return;
      }

      // Handle Expense Payload
      final expense = Expense(
        title: map['title'] as String,
        totalAmount: (map['totalAmount'] as num).toDouble(),
        category: (map['category'] as String?) ?? 'Uncategorized',
        timestamp: DateTime.now(),
        isRecurring: false,
        isDeleted: false,
      );

      if (!mounted) return;
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

      List<ExpensePayer> payers = [];
      if (map['payers'] != null) {
        for (var p in map['payers']) {
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
      if (map['splits'] != null) {
        for (var s in map['splits']) {
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

      setState(() => _status = 'Received and saved "${expense.title}".');
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Failed to parse incoming expense: $e');
      }
    }
  }

  Future<void> _sendExpense() async {
    final endpointId = _connectedEndpointId;
    final expense = widget.expenseToShare;

    if (endpointId == null) {
      setState(() => _status = 'No connected peer to send to.');
      return;
    }
    if (expense == null) {
      setState(() => _status = 'No expense was passed to this screen to share.');
      return;
    }

    final expenseRepo = Provider.of<ExpenseRepository>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final payers = await expenseRepo.getPayersForExpense(expense.id!);
    final splits = await expenseRepo.getSplitsForExpense(expense.id!);

    final payersJson = payers.map((p) {
      final user = userProvider.users.firstWhere((u) => u.id == p.userId, orElse: () => User(name: 'Unknown', createdAt: DateTime.now()));
      return {'userName': user.name, 'amountPaid': p.amountPaid};
    }).toList();

    final splitsJson = splits.map((s) {
      final user = userProvider.users.firstWhere((u) => u.id == s.userId, orElse: () => User(name: 'Unknown', createdAt: DateTime.now()));
      return {'userName': user.name, 'amountOwed': s.amountOwed};
    }).toList();

    final payload = {
      'title': expense.title,
      'totalAmount': expense.totalAmount,
      'category': expense.category,
      'payers': payersJson,
      'splits': splitsJson,
    };

    await Nearby().sendBytesPayload(endpointId, utf8.encode(jsonEncode(payload)));
    setState(() => _status = 'Sent "${expense.title}".');
  }

  @override
  Widget build(BuildContext context) {
    final hasExpenseToShare = widget.expenseToShare != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Sync')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status, style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.wifi_tethering),
              label: Text(hasExpenseToShare ? 'Advertise (Send this expense)' : 'Advertise'),
              onPressed: _isBusy ? null : _startAdvertising,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Discover & Receive'),
              onPressed: _isBusy ? null : _startDiscovery,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Send Expense to Connected Peer'),
              onPressed: (_connectedEndpointId != null && hasExpenseToShare)
                  ? _sendExpense
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop / Reset'),
              onPressed: () async {
                await _teardownConnections();
                setState(() {
                  _isBusy = false;
                  _connectedEndpointId = null;
                  _status = 'Idle';
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
