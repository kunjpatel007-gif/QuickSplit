import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:campus_quicksplit/data/repositories/expense_repository.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/presentation/screens/manage_users/manage_users_screen.dart';
import 'package:campus_quicksplit/presentation/screens/presets/presets_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131314),
        title: Text('SYSTEM_CONFIG', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFFe5e2e3))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFe5e2e3)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFF514532), height: 2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF9e8f78), size: 16),
              const SizedBox(width: 8),
              Text('USER PROFILE', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF9e8f78), letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSettingsItem(
            context,
            icon: Icons.badge,
            title: currentUser?.name ?? 'NO_USER',
            subtitle: 'DISPLAY_NAME',
            onTap: () async {
              final controller = TextEditingController(text: currentUser?.name ?? '');
              final newName = await _showEditDialog(context, 'EDIT_NAME', controller);
              if (newName != null && newName.isNotEmpty && currentUser != null) {
                userProvider.updateUser(currentUser.copyWith(name: newName));
              }
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.payment,
            title: currentUser?.upiId?.isNotEmpty == true ? currentUser!.upiId! : 'NOT_SET',
            subtitle: 'UPI_ID',
            onTap: () async {
              final controller = TextEditingController(text: currentUser?.upiId ?? '');
              final newUpi = await _showEditDialog(context, 'EDIT_UPI', controller);
              if (newUpi != null && currentUser != null) {
                userProvider.updateUser(currentUser.copyWith(upiId: newUpi.isEmpty ? null : newUpi));
              }
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.phone,
            title: currentUser?.phoneNumber?.isNotEmpty == true ? currentUser!.phoneNumber! : 'NOT_SET',
            subtitle: 'PHONE_NUMBER',
            onTap: () async {
              final controller = TextEditingController(text: currentUser?.phoneNumber ?? '');
              final newPhone = await _showEditDialog(context, 'EDIT_PHONE', controller);
              if (newPhone != null && currentUser != null) {
                userProvider.updateUser(currentUser.copyWith(phoneNumber: newPhone.isEmpty ? null : newPhone));
              }
            },
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.settings, color: Color(0xFF9e8f78), size: 16),
              const SizedBox(width: 8),
              Text('SYSTEM PREFERENCES', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF9e8f78), letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSettingsItem(
            context,
            icon: Icons.group,
            title: 'MANAGE_USERS',
            subtitle: 'ADD_OR_EDIT_NETWORK_NODES',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.auto_awesome,
            title: 'ROUTINE_PRESETS',
            subtitle: 'CONFIGURE_AUTOMATED_SPLITS',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PresetsScreen()));
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.download,
            title: 'EXPORT_LEDGER',
            subtitle: 'DOWNLOAD_JSON_ARCHIVE',
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
        ],
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF201f20),
          border: Border.all(color: const Color(0xFF514532)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF131314),
                border: Border.all(color: const Color(0xFF514532)),
              ),
              child: Icon(icon, color: const Color(0xFFe5e2e3), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.jetBrainsMono(color: const Color(0xFF9e8f78), fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF9e8f78), size: 14),
          ],
        ),
      ),
    );
  }

  Future<String?> _showEditDialog(BuildContext context, String title, TextEditingController controller) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF201f20),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF514532), width: 2)),
        title: Text(title, style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3)),
          decoration: InputDecoration(
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF514532))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFffdca1))),
            hintStyle: GoogleFonts.jetBrainsMono(color: const Color(0xFF9e8f78)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: const Color(0xFFffb4ab))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFffb800),
              foregroundColor: const Color(0xFF131314),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('SAVE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
