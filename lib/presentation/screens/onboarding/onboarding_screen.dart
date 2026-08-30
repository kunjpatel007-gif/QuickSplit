import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _uuidController = TextEditingController();
  bool _isImporting = false;
  bool _isScanning = false;
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _nameController.dispose();
    _uuidController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final settingsRepo = context.read<SettingsRepository>();
    
    await userProvider.createAndSetUser(name, settingsRepo);
  }

  Future<void> _importProfileManually() async {
    final uuid = _uuidController.text.trim();
    final name = _nameController.text.trim();
    if (uuid.isEmpty || name.isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final settingsRepo = context.read<SettingsRepository>();
    
    await userProvider.createAndSetUser(name, settingsRepo, syncId: uuid);
  }

  Future<void> _processScannedQR(String data) async {
    try {
      final decodedBytes = base64Decode(data);
      String jsonString;
      
      try {
        final decompressedBytes = gzip.decode(decodedBytes);
        jsonString = utf8.decode(decompressedBytes);
      } catch (_) {
        jsonString = utf8.decode(decodedBytes);
      }
      
      final List<dynamic> decoded = jsonDecode(jsonString);
      
      // Extract all profiles from the payload
      final List<Map<String, dynamic>> profiles = decoded
          .cast<Map<String, dynamic>>()
          .where((e) => e['type'] == 'profile')
          .toList();

      if (profiles.isEmpty) {
        throw Exception('No profiles found in QR');
      }

      await _scannerController?.stop();
      _scannerController?.dispose();
      _scannerController = null;
      setState(() => _isScanning = false);

      if (!mounted) return;

      // Show dialog to let user pick their identity
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Which profile is you?'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final p = profiles[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(p['userName'] ?? 'Unknown'),
                  subtitle: const Text('Tap to select your profile', style: TextStyle(fontSize: 10)),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    
                    // Create the user locally and set as Current User
                    final userProvider = context.read<UserProvider>();
                    final settingsRepo = context.read<SettingsRepository>();
                    
                    await userProvider.createAndSetUser(
                      p['userName'], 
                      settingsRepo, 
                      syncId: p['syncId']
                    );
                    
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Identity restored! Run QR Sync to import expenses.'))
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid DB Sync QR code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning && _scannerController != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan DB Sync QR'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await _scannerController?.stop();
              _scannerController?.dispose();
              _scannerController = null;
              setState(() => _isScanning = false);
            },
          ),
        ),
        body: MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _processScannedQR(barcode.rawValue!);
                break;
              }
            }
          },
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                const Icon(Icons.account_circle, size: 80, color: Colors.blue),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Welcome to QuickSplit',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                if (!_isImporting) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _createProfile,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('Create New Profile'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => setState(() => _isImporting = true),
                    child: const Text('I already have a profile UUID'),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR from old phone'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    onPressed: () {
                      if (!Platform.isWindows) {
                        _scannerController = MobileScannerController();
                      }
                      setState(() => _isScanning = true);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("OR TYPE MANUALLY")),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _uuidController,
                    decoration: const InputDecoration(
                      labelText: 'Profile UUID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                      helperText: 'Enter your UUID to restore your identity',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _importProfileManually,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('Import Profile'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => setState(() => _isImporting = false),
                    child: const Text('Go back to create profile'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
