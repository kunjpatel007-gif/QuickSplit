import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/presentation/screens/manage_users/manage_users_screen.dart';
import 'package:campus_quicksplit/presentation/screens/presets/presets_screen.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final currentUser = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SectionHeader(title: 'Profile'),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(currentUser?.name ?? 'No User'),
            subtitle: const Text('Tap to edit your display name'),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () async {
              final controller = TextEditingController(text: currentUser?.name ?? '');
              final newName = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Edit Display Name'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      hintText: 'e.g. Mitul, Rahul...',
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (newName != null && newName.isNotEmpty && currentUser != null) {
                final updated = currentUser.copyWith(name: newName);
                userProvider.updateUser(updated);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('UPI ID'),
            subtitle: Text(currentUser?.upiId?.isNotEmpty == true ? currentUser!.upiId! : 'Not set'),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () async {
              final controller = TextEditingController(text: currentUser?.upiId ?? '');
              final newUpi = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Edit UPI ID'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID',
                      hintText: 'e.g. yourname@upi',
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (newUpi != null && currentUser != null) {
                final updated = currentUser.copyWith(upiId: newUpi);
                userProvider.updateUser(updated);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Phone Number'),
            subtitle: Text(currentUser?.phoneNumber?.isNotEmpty == true ? currentUser!.phoneNumber! : 'Not set'),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () async {
              final controller = TextEditingController(text: currentUser?.phoneNumber ?? '');
              final newPhone = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Edit Phone Number'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '10-digit number',
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (newPhone != null && currentUser != null) {
                final updated = currentUser.copyWith(phoneNumber: newPhone);
                userProvider.updateUser(updated);
              }
            },
          ),
            
          const Divider(),
          const SectionHeader(title: 'App Settings'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Theme'),
            value: themeProvider.isDarkMode,
            onChanged: (value) => themeProvider.toggleTheme(),
          ),
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('Manage Users'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Routine Presets'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PresetsScreen()),
              );
            },
          ),
          
          const Divider(),
          const SectionHeader(title: 'Data & Privacy'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Data'),
            onTap: () async {
              try {
                final expenseRepo = Provider.of<ExpenseRepository>(context, listen: false);
                final expenses = await expenseRepo.getAllActiveExpenses(limit: 10000, offset: 0);
                
                final jsonList = expenses.map((e) => {
                  'id': e.id,
                  'title': e.title,
                  'amount': e.totalAmount,
                  'category': e.category,
                  'timestamp': e.timestamp.toIso8601String(),
                }).toList();
                
                final jsonString = jsonEncode(jsonList);
                final directory = await getApplicationDocumentsDirectory();
                final file = File('${directory.path}/expenses_export.json');
                await file.writeAsString(jsonString);
                
                await Share.shareXFiles([XFile(file.path)], text: 'My QuickSplit Expenses');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to export data: $e')),
                  );
                }
              }
            },
          ),
          
          const Divider(),
          const SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Campus QuickSplit'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}
