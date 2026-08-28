import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class ProRataScreen extends StatefulWidget {
  const ProRataScreen({Key? key}) : super(key: key);

  @override
  State<ProRataScreen> createState() => _ProRataScreenState();
}

class ParticipantEntry {
  int? userId;
  final TextEditingController amountController;

  ParticipantEntry({this.userId}) : amountController = TextEditingController();

  void dispose() {
    amountController.dispose();
  }
}

class _ProRataScreenState extends State<ProRataScreen> {
  final List<ParticipantEntry> _participants = [];
  final TextEditingController _overheadController = TextEditingController();
  final ProRataEngine _proRataEngine = ProRataEngine();
  Map<int, double>? _results;
  Map<int, double>? _overheadShares;

  @override
  void initState() {
    super.initState();
    _addParticipant();
    _addParticipant();
  }

  @override
  void dispose() {
    _overheadController.dispose();
    for (var p in _participants) {
      p.dispose();
    }
    super.dispose();
  }

  void _addParticipant() {
    setState(() {
      _participants.add(ParticipantEntry());
    });
  }

  void _removeParticipant(int index) {
    if (_participants.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 participants required')),
      );
      return;
    }
    setState(() {
      _participants[index].dispose();
      _participants.removeAt(index);
    });
  }

  void _calculate() {
    final double overhead = double.tryParse(_overheadController.text) ?? 0.0;
    if (overhead <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Overhead must be greater than 0')),
      );
      return;
    }

    if (_participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 participants required')),
      );
      return;
    }

    Map<int, double> userDishTotals = {};
    for (var p in _participants) {
      if (p.userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select users for all entries')),
        );
        return;
      }
      final double amt = double.tryParse(p.amountController.text) ?? 0.0;
      if (amt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All dish amounts must be > 0')),
        );
        return;
      }
      userDishTotals[p.userId!] = (userDishTotals[p.userId!] ?? 0) + amt;
    }

    setState(() {
      _results = _proRataEngine.calculateTotalWithOverhead(
        userDishTotals: userDishTotals,
        totalOverhead: overhead,
      );
      _overheadShares = _proRataEngine.distributeOverhead(
        userDishTotals: userDishTotals,
        totalOverhead: overhead,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final users = userProvider.users as List<User>;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pro-Rata Splitter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Split delivery fees, GST, and packaging charges proportionally based on each person\'s order amount',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _overheadController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total Overhead (taxes + delivery + packaging)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Participants', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final p = _participants[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: p.userId,
                          items: users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                          onChanged: (val) {
                            setState(() { p.userId = val; });
                          },
                          decoration: const InputDecoration(labelText: 'User', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: p.amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Dish Total', border: OutlineInputBorder()),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: cs.error),
                        onPressed: () => _removeParticipant(index),
                      ),
                    ],
                  ),
                );
              },
            ),
            TextButton.icon(
              onPressed: _addParticipant,
              icon: const Icon(Icons.add),
              label: const Text('Add Participant'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _calculate,
                child: const Text('Calculate'),
              ),
            ),
            if (_results != null && _overheadShares != null) ...[
              const SizedBox(height: 24),
              Text('Results', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text('Formula: Overhead × (Your Dishes / Total Dishes)', style: tt.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _results!.length,
                itemBuilder: (context, index) {
                  final userId = _results!.keys.elementAt(index);
                  final user = userProvider.getUserById(userId) as User?;
                  final total = _results![userId]!;
                  final share = _overheadShares![userId]!;
                  final dishTotal = total - share;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? 'Unknown', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Dish Total:'),
                              Text(CurrencyFormatter.format(dishTotal)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Overhead Share:', style: TextStyle(color: cs.tertiary)),
                              Text(CurrencyFormatter.format(share), style: TextStyle(color: cs.tertiary)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Final Amount:', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                              Text(CurrencyFormatter.format(total), style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            ]
          ],
        ),
      ),
    );
  }
}
