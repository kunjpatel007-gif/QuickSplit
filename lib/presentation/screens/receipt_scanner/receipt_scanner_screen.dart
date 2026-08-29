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
  List<Map<String, dynamic>> _taxLines = [];
  final Map<int, List<Map<String, dynamic>>> _assignedItems = {};
  double _totalAmount = 0.0;
  double _taxTotal = 0.0;
  String _totalLabel = 'Total';
  File? _receiptImage;
  bool _isProcessing = false;

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

  Future<void> _pickImage(ImageSource source) async {
    if (Platform.isWindows) {
      _parseText(_pasteController.text);
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null && _textRecognizer != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
        _isProcessing = true;
        _extractedItems.clear();
        _taxLines.clear();
        _assignedItems.clear();
        _totalAmount = 0.0;
        _taxTotal = 0.0;
      });

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      
      // Reconstruct text horizontally using bounding boxes
      // ML Kit often reads column-by-column (all names, then all prices).
      // We group them by Y-coordinate overlap to reconstruct the original rows.
      List<TextLine> allLines = [];
      for (var block in recognizedText.blocks) {
        allLines.addAll(block.lines);
      }
      
      allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
      
      List<List<TextLine>> rows = [];
      for (var line in allLines) {
        bool added = false;
        for (var row in rows) {
          var rowMid = row.first.boundingBox.top + (row.first.boundingBox.height / 2);
          if (line.boundingBox.top <= rowMid && line.boundingBox.bottom >= rowMid) {
            row.add(line);
            added = true;
            break;
          }
        }
        if (!added) {
          rows.add([line]);
        }
      }
      
      StringBuffer reconstructedText = StringBuffer();
      for (var row in rows) {
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        reconstructedText.writeln(row.map((e) => e.text).join(' '));
      }
      
      _parseText(reconstructedText.toString());
    }
  }

  void _parseText(String text) {
    final lines = text.split('\n');
    final RegExp priceRegex = RegExp(r'(\d+\.\d{2})$');
    
    List<Map<String, dynamic>> items = [];
    List<Map<String, dynamic>> taxLines = [];
    double total = 0.0;
    String totalLabel = 'Total';

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
              totalLabel = name;
            }
          } else if (lowerName.contains('cash') || 
                     lowerName.contains('change') || 
                     lowerName.contains('visa') || 
                     lowerName.contains('mastercard') || 
                     lowerName.contains('paid') ||
                     lowerName.contains('tend') ||
                     lowerName.contains('card')) {
            // Payment method lines — ignore entirely
            continue;
          } else if (lowerName.contains('tax') || lowerName.contains('gst') || 
                     lowerName.contains('vat') || lowerName.contains('tip') ||
                     lowerName.contains('service charge') || lowerName.contains('fee')) {
            // Tax/tip lines — track separately, will be split proportionally
            taxLines.add({'name': name, 'amount': amount, 'type': 'tax'});
          } else if (name.isNotEmpty) {
            items.add({'name': name, 'amount': amount, 'type': 'item', 'id': DateTime.now().microsecondsSinceEpoch.toString()});
          }
        }
      }
    }

    final itemsSubtotal = items.fold(0.0, (sum, item) => sum + item['amount']);
    final taxSubtotal = taxLines.fold(0.0, (t, line) => t + (line['amount'] as double));

    setState(() {
      _extractedItems = items;
      _taxLines = taxLines;
      _taxTotal = taxSubtotal;
      _totalLabel = totalLabel;
      // Use parsed total; if none found, derive from items + taxes
      _totalAmount = total > 0 ? total : (itemsSubtotal + taxSubtotal);
      _isProcessing = false;
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
    await Provider.of<BalanceProvider>(context, listen: false).recalculateBalances();

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
              onPressed: () => _pickImage(ImageSource.camera),
              child: const Text('Parse'),
            ),
          ],
        ),
      );
    }
    
    if (_receiptImage != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _receiptImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Clear', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    setState(() {
                      _receiptImage = null;
                      _extractedItems.clear();
                      _taxLines.clear();
                      _assignedItems.clear();
                    });
                  },
                ),
              ],
            )
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          const SizedBox(height: AppSpacing.md),
          Text('Add a receipt image to extract items.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedItems() {
    if (_extractedItems.isEmpty && _taxLines.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget chipFor(Map<String, dynamic> item, {bool isTax = false}) {
      final color = isTax ? cs.error : cs.primary;
      return Draggable<Map<String, dynamic>>(
        data: item,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(20),
          child: Chip(
            avatar: Icon(isTax ? Icons.percent : Icons.receipt_long, size: 14, color: color),
            label: Text('${item['name']} · ${CurrencyFormatter.format(item['amount'])}'),
            backgroundColor: color.withValues(alpha: 0.15),
            side: BorderSide(color: color, width: 1),
          ),
        ),
        childWhenDragging: Chip(
          label: Text('${item['name']} · ${CurrencyFormatter.format(item['amount'])}'),
          backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
        ),
        child: Chip(
          avatar: Icon(isTax ? Icons.percent : Icons.receipt_long, size: 14, color: color),
          label: Text('${item['name']} · ${CurrencyFormatter.format(item['amount'])}'),
          backgroundColor: color.withValues(alpha: 0.1),
          side: BorderSide(color: color.withValues(alpha: 0.4), width: 1),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ITEMS section ──
          if (_extractedItems.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.receipt_long, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text('Items  (drag to assign)',
                    style: tt.labelLarge?.copyWith(color: cs.primary)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _extractedItems.map((item) => chipFor(item)).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── TAXES/FEES section ──
          if (_taxLines.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.percent, size: 16, color: cs.error),
                const SizedBox(width: 6),
                Text(
                  'Tax / Fees  (auto-split proportionally)',
                  style: tt.labelLarge?.copyWith(color: cs.error),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _taxLines.map((line) => Chip(
                avatar: Icon(Icons.percent, size: 14, color: cs.error),
                label: Text('${line['name']} · ${CurrencyFormatter.format(line['amount'])}'),
                backgroundColor: cs.error.withValues(alpha: 0.08),
                side: BorderSide(color: cs.error.withValues(alpha: 0.3), width: 1),
              )).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── TOTAL summary row ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_taxTotal > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Items subtotal', style: tt.bodySmall),
                      Text('Tax / Fees', style: tt.bodySmall?.copyWith(color: cs.error)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(CurrencyFormatter.format(_totalAmount - _taxTotal), style: tt.bodySmall),
                      Text(CurrencyFormatter.format(_taxTotal), style: tt.bodySmall?.copyWith(color: cs.error)),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                Text(_totalLabel, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(CurrencyFormatter.format(_totalAmount),
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
              ],
            ),
          ),
        ],
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
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(),
            ),
          if (!_isProcessing && (_extractedItems.isNotEmpty || _assignedItems.isNotEmpty)) ...[
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
            const Divider(),
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
