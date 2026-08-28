import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';
import 'package:campus_quicksplit/presentation/screens/dashboard/dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _uuidController = TextEditingController();
  bool _isImporting = false;

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final settingsRepo = context.read<SettingsRepository>();
    
    // Create new user (automatically generates UUID)
    await userProvider.createAndSetUser(name, settingsRepo);
  }

  Future<void> _importProfile() async {
    final uuid = _uuidController.text.trim();
    final name = _nameController.text.trim();
    if (uuid.isEmpty || name.isEmpty) return;

    final userProvider = context.read<UserProvider>();
    final settingsRepo = context.read<SettingsRepository>();
    
    // Create user with explicit UUID so they can sync back their history later
    await userProvider.createAndSetUser(name, settingsRepo, syncId: uuid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  onPressed: _importProfile,
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
    );
  }
}
