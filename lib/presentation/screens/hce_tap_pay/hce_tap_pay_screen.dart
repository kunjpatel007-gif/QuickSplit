import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/domain/services/hce_pay_service.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/core/utils/intent_utils.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

enum HceMode { none, paying, receiving }

class HceTapPayScreen extends StatefulWidget {
  const HceTapPayScreen({super.key});

  @override
  State<HceTapPayScreen> createState() => _HceTapPayScreenState();
}

class _HceTapPayScreenState extends State<HceTapPayScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _isHceAvailable = true;
  bool _isScanning = false;
  HceMode _mode = HceMode.none;
  String _statusMessage = 'Select whether you are paying or receiving.';
  
  User? _peerUser;
  double? _debtAmount;
  bool _peerOwesMe = false;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _initHce();
  }

  Future<void> _initHce() async {
    final available = await HcePayService.isNfcAvailable();
    if (!mounted) return;
    
    setState(() {
      _isHceAvailable = available;
    });
  }

  Future<void> _startPaying() async {
    setState(() {
      _mode = HceMode.paying;
      _isScanning = true;
      _statusMessage = 'Hold phones back-to-back to read their ID';
      _peerUser = null;
      _debtAmount = null;
      _peerOwesMe = false;
      _settled = false;
    });

    await HcePayService.stopBroadcasting(); // Ensure HCE is off
    await HcePayService.startReading(
      onPeerDetected: _handlePeerDetected,
    );
  }

  Future<void> _startReceiving() async {
    setState(() {
      _mode = HceMode.receiving;
      _isScanning = true;
      _statusMessage = 'Broadcasting... Ask them to tap your phone';
      _peerUser = null;
      _debtAmount = null;
      _peerOwesMe = false;
      _settled = false;
    });

    await HcePayService.stopReading(); // Ensure Reader is off
    
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser != null) {
      final upiId = currentUser.upiId ?? '';
      await HcePayService.startBroadcasting(
        userName: currentUser.name,
        upiId: upiId,
      );
    }
  }

  void _reset() async {
    await HcePayService.stopReading();
    await HcePayService.stopBroadcasting();
    if (!mounted) return;
    
    setState(() {
      _mode = HceMode.none;
      _isScanning = false;
      _isProcessingRead = false;
      _statusMessage = 'Select whether you are paying or receiving.';
      _peerUser = null;
      _debtAmount = null;
      _peerOwesMe = false;
      _settled = false;
    });
  }

  bool _isProcessingRead = false;

  Future<void> _handlePeerDetected(String peerName, String peerUpi) async {
    // DO NOT call stopReading() here! 
    // If we stop reading, the Android OS re-takes control of the NFC chip and spams the "Empty Tag" system popup.
    // By leaving it in Reader Mode, we suppress the OS popup perfectly!
    
    if (_isProcessingRead || _peerUser != null) return; // Ignore duplicate taps while holding
    
    _isProcessingRead = true;

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _statusMessage = 'Processing...';
    });

    if (peerName == 'ERROR') {
      setState(() {
        _statusMessage = 'Read Error: $peerUpi';
        _isScanning = true;
      });
      _isProcessingRead = false;
      return;
    }

    final userRepository = context.read<UserRepository>();
    final peer = await userRepository.getUserByName(peerName);

    if (!mounted) return;

    if (peer == null) {
      setState(() {
        _statusMessage = 'Unknown user — sync profiles first via Nearby Sync';
      });
      _isProcessingRead = false;
      return;
    }

    setState(() {
      _peerUser = peer;
    });

    _calculateDebts(peer, peerUpi);
  }

  void _calculateDebts(User peer, String peerUpi) {
    final balanceProvider = context.read<BalanceProvider>();
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    
    if (currentUser == null) return;

    final balances = balanceProvider.balances;
    final transactions = DebtSimplifier().simplifyDebts(balances);

    DebtTransaction? myDebtToPeer;
    DebtTransaction? peerDebtToMe;

    for (final t in transactions) {
      if (t.fromUserId == currentUser.id && t.toUserId == peer.id) {
        myDebtToPeer = t;
      } else if (t.fromUserId == peer.id && t.toUserId == currentUser.id) {
        peerDebtToMe = t;
      }
    }

    if (myDebtToPeer != null && myDebtToPeer.amount > 0) {
      final amount = myDebtToPeer.amount;
      
      if (peerUpi.isEmpty) {
        setState(() {
          _debtAmount = amount;
          _peerOwesMe = false;
          _settled = false;
          _statusMessage = '${peer.name} has no UPI ID saved. Ask them to add it first!';
        });
        _isProcessingRead = false;
      } else {
        setState(() {
          _debtAmount = amount;
          _peerOwesMe = false;
          _settled = false;
          _statusMessage = 'Launching GPay for ${CurrencyFormatter.format(amount)}...';
        });
        IntentUtils.launchUpi(context, peerUpi, peer.name, amount);
        _isProcessingRead = false;
      }
      
    } else if (peerDebtToMe != null && peerDebtToMe.amount > 0) {
      setState(() {
        _debtAmount = peerDebtToMe!.amount;
        _peerOwesMe = true;
        _settled = false;
        _statusMessage = '';
      });
      _isProcessingRead = false;
    } else {
      setState(() {
        _settled = true;
        _statusMessage = '';
      });
      _isProcessingRead = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initHce(); // Re-check NFC status when returning from settings
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    HcePayService.stopBroadcasting();
    HcePayService.stopReading();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('HCE Tap-to-Pay'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isHceAvailable) ...[
                const Icon(
                  Icons.nfc_rounded,
                  size: 100,
                  color: Colors.grey,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'HCE (NFC) is turned off or not available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    HcePayService.openNfcSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Turn on HCE (NFC) in Settings'),
                ),
              ] else if (_isScanning)
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Icon(
                    Icons.nfc_rounded,
                    size: 120,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.nfc_rounded,
                  size: 100,
                  color: theme.colorScheme.secondary,
                ),
              const SizedBox(height: AppSpacing.xl),
              
              if (_peerUser != null && _debtAmount != null && !_peerOwesMe)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Icon(Icons.payment, size: 48, color: theme.colorScheme.primary),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Paying ${_peerUser!.name}',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          CurrencyFormatter.format(_debtAmount!),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_peerUser != null && _debtAmount != null && _peerOwesMe)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Icon(Icons.call_received, size: 48, color: theme.colorScheme.tertiary),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '${_peerUser!.name} owes you',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          CurrencyFormatter.format(_debtAmount!),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Waiting for their payment...'),
                      ],
                    ),
                  ),
                )
              else if (_peerUser != null && _settled)
                Card(
                  elevation: 4,
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 48, color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'You\'re all settled with ${_peerUser!.name}!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
              const SizedBox(height: AppSpacing.lg),
              
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _statusMessage.contains('no UPI ID') ? theme.colorScheme.error : null,
                ),
              ),
                
              const SizedBox(height: AppSpacing.xxl),
              
              if (_isHceAvailable && _mode == HceMode.none) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _startPaying,
                        icon: const Icon(Icons.payment),
                        label: const Text('I am Paying'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _startReceiving,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.call_received),
                            SizedBox(width: 8),
                            Flexible(child: Text('I am Receiving', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (_mode != HceMode.none) ...[
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel / Reset'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
