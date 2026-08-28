import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/core/utils/input_validators.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';
import 'package:intl/intl.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({Key? key}) : super(key: key);

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<UserProvider>().loadUsers());
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => const _UserDialog(),
    );
  }

  void _showEditUserDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => _UserDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, provider, child) {
          if (provider.users.isEmpty) {
            return const EmptyState(
              icon: Icons.group,
              message: 'No users found.',
            );
          }
          
          return ListView.builder(
            itemCount: provider.users.length,
            itemBuilder: (context, index) {
              final user = provider.users[index];
              final isCurrent = provider.currentUser?.id == user.id;
              
              return ListTile(
                leading: CircleAvatar(
                  child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                ),
                title: Text(user.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCurrent && user.syncId.isNotEmpty)
                      Text('UUID: ${user.syncId}', style: tt.bodySmall?.copyWith(fontFamily: 'monospace')),
                    if (user.upiId != null && user.upiId!.isNotEmpty)
                      Text('UPI: ${user.upiId}'),
                    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                      Text('Phone: ${user.phoneNumber}'),
                    Text('Joined: ${DateFormat.yMMMd().format(user.createdAt)}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
                trailing: isCurrent 
                    ? Icon(Icons.star, color: cs.tertiary) 
                    : null,
                isThreeLine: true,
                onTap: () => _showEditUserDialog(user), // Changed to edit on tap
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  final User? user;
  
  const _UserDialog({Key? key, this.user}) : super(key: key);

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _upiController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _upiController = TextEditingController(text: widget.user?.upiId ?? '');
    _phoneController = TextEditingController(text: widget.user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final upiId = _upiController.text.trim();
      final phone = _phoneController.text.trim();
      
      final provider = context.read<UserProvider>();
      
      if (widget.user == null) {
        provider.addUser(name);
      } else {
        provider.updateUser(widget.user!.copyWith(
          name: name,
          upiId: upiId.isEmpty ? null : upiId,
          phoneNumber: phone.isEmpty ? null : phone,
        ));
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit User' : 'Add User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: InputValidators.validateName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _upiController,
                decoration: const InputDecoration(labelText: 'UPI ID (Optional)'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return null;
                  return InputValidators.validateUpiId(val);
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return null;
                  return InputValidators.validatePhoneNumber(val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
