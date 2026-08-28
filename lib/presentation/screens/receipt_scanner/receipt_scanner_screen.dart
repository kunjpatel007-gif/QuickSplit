import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final TextEditingController _pasteController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  TextRecognizer? _textRecognizer;
  List<Map<String, dynamic>> _extractedItems = [];
  final Map<int, List<Map<String, dynamic>>> _assignedItems = {};
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    }
  }

  @override
  void dispose() {
    _pasteController.dispose();
    _titleController.dispose();
    _textRecognizer?.close();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    if (Platform.isWindows) {
      _parseText(_pasteController.text);
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    
    if (pickedFile != null && _textRecognizer != null) {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      _parseText(recognizedText.text);
    }
  }

  void _parseText(String text) {
    final lines = text.split('\n');
    final RegExp priceRegex = RegExp(r'(\d+\.\d{2})$');
    
    List<Map<String, dynamic>> items = [];
    double total = 0.0;

    for (final line in lines) {
      final match = priceRegex.firstMatch(line.trim());
      if (match != null) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          final amount = double.tryParse(amountStr) ?? 0.0;
          final name = line.replaceAll(amountStr, '').trim();
          final lowerName = name.toLowerCase();
          
          if (lowerName.contains('total') || lowerName.contains('amount due') || lowerName.contains('balance')) {
            if (amount > total) {
              total = amount;
            }
          } else if (lowerName.contains('tax') || 
                     lowerName.contains('tip') || 
                     lowerName.contains('cash') || 
                     lowerName.contains('change') || 
                     lowerName.contains('visa') || 
                     lowerName.contains('mastercard') || 
                     lowerName.contains('paid') ||
                     lowerName.contains('card')) {
            // Ignore these receipt footers
            continue;
          } else if (name.isNotEmpty) {
            items.add({'name': name, 'amount': amount, 'id': DateTime.now().microsecondsSinceEpoch.toString()});
          }
        }
      }
    }

    setState(() {
      _extractedItems = items;
      _totalAmount = total > 0 ? total : items.fold(0.0, (sum, item) => sum + item['amount']);
    });
  }

  Future<void> _createExpense() async {
    if (_titleController.text.isEmpty || _assignedItems.isEmpty) return;
    
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    final expense = Expense(
      title: _titleController.text,
      totalAmount: _totalAmount,
      category: 'Receipt',
      timestamp: DateTime.now(),
      isRecurring: false,
      isDeleted: false,
    );

    List<ExpenseSplit> splits = [];
    
    double assignedTotal = 0.0;
    _assignedItems.forEach((userId, items) {
      assignedTotal += items.fold<double>(0.0, (sum, item) => sum + item['amount']);
    });

    _assignedItems.forEach((userId, items) {
      final userItemsTotal = items.fold<double>(0.0, (sum, item) => sum + item['amount']);
      
      // Calculate proportional share (including taxes/tips proportionally)
      double finalAmountOwed = 0.0;
      if (assignedTotal > 0) {
        final ratio = userItemsTotal / assignedTotal;
        finalAmountOwed = _totalAmount * ratio;
      }

      splits.add(ExpenseSplit(
        expenseId: 0, 
        userId: userId,
        amountOwed: finalAmountOwed,
      ));
    });

    final currentUserId = userProvider.currentUser?.id ?? 0;

    await expenseProvider.addExpense(
      expense: expense,
      payers: [ExpensePayer(expenseId: 0, userId: currentUserId, amountPaid: _totalAmount)],
      splits: splits,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildScannerInput() {
    if (Platform.isWindows) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pasteController,
                decoration: const InputDecoration(
                  labelText: 'Paste Receipt Text',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _scanReceipt,
              child: const Text('Parse'),
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Receipt'),
        onPressed: _scanReceipt,
      ),
    );
  }

  Widget _buildExtractedItems() {
    if (_extractedItems.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      width: double.infinity,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: _extractedItems.map((item) {
          return Draggable<Map<String, dynamic>>(
            data: item,
            feedback: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: Chip(label: Text('${item['name']} - ${CurrencyFormatter.format(item['amount'])}')),
            ),
            childWhenDragging: Chip(
              label: Text('${item['name']} - ${CurrencyFormatter.format(item['amount'])}'),
              backgroundColor: cs.outlineVariant,
            ),
            child: Chip(label: Text('${item['name']} - ${CurrencyFormatter.format(item['amount'])}')),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserTargets() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final users = userProvider.users;
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return DragTarget<Map<String, dynamic>>(
                onAcceptWithDetails: (details) {
                  final item = details.data;
                  setState(() {
                    _extractedItems.removeWhere((e) => e['id'] == item['id']);
                    if (!_assignedItems.containsKey(user.id!)) {
                      _assignedItems[user.id!] = [];
                    }
                    _assignedItems[user.id!]!.add(item);
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  final assignedCount = _assignedItems[user.id]?.length ?? 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: candidateData.isNotEmpty ? cs.primary : cs.outline,
                        width: candidateData.isNotEmpty ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: candidateData.isNotEmpty ? cs.primaryContainer : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(child: Text(user.name[0])),
                        const SizedBox(height: AppSpacing.sm),
                        Text(user.name),
                        Text('$assignedCount items', style: tt.bodySmall),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Scanner')),
      body: Column(
        children: [
          _buildScannerInput(),
          if (_extractedItems.isNotEmpty || _assignedItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Expense Title',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text('Total: ${CurrencyFormatter.format(_totalAmount)}', 
                  key: ValueKey(_totalAmount),
                  style: tt.titleMedium),
              ),
            ),
            const Divider(),
            const Text('Drag items to assign:'),
            Expanded(
              child: SingleChildScrollView(
                child: _buildExtractedItems(),
              ),
            ),
            const Divider(),
            _buildUserTargets(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ElevatedButton(
                onPressed: _createExpense,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('Create Expense'),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
