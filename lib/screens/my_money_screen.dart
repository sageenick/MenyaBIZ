import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class MyMoneyScreen extends StatefulWidget {
  const MyMoneyScreen({super.key});

  @override
  State<MyMoneyScreen> createState() => _MyMoneyScreenState();
}

class _MyMoneyScreenState extends State<MyMoneyScreen> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _debts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final expenses = await DBHelper().getExpenses();
    final debts = await DBHelper().getDebts();
    setState(() {
      _expenses = expenses;
      _debts = debts;
    });
  }

  void _showAddExpenseDialog() {
    final typeController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: typeController,
              decoration: const InputDecoration(labelText: 'What (transport, rent...)'),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (typeController.text.isEmpty || amountController.text.isEmpty) return;
              await DBHelper().insertExpense({
                'type': typeController.text,
                'amount': double.tryParse(amountController.text) ?? 0,
                'date': DateTime.now().toIso8601String(),
              });
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDebtDialog() {
    final personController = TextEditingController();
    final amountController = TextEditingController();
    String direction = 'owed_to_you';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add debt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: direction,
                items: const [
                  DropdownMenuItem(value: 'owed_to_you', child: Text('Owed to you')),
                  DropdownMenuItem(value: 'you_owe', child: Text('You owe')),
                ],
                onChanged: (value) => setDialogState(() => direction = value!),
              ),
              TextField(
                controller: personController,
                decoration: const InputDecoration(labelText: 'Person/supplier name'),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (personController.text.isEmpty || amountController.text.isEmpty) return;
                await DBHelper().insertDebt({
                  'direction': direction,
                  'person': personController.text,
                  'amount': double.tryParse(amountController.text) ?? 0,
                  'due_date': null,
                  'date': DateTime.now().toIso8601String(),
                });
                Navigator.pop(context);
                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My money'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expenses'),
              Tab(text: 'Debts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _expenses.isEmpty
                ? const Center(child: Text('No expenses yet.'))
                : ListView.builder(
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final e = _expenses[index];
                      return ListTile(
                        title: Text(e['type']),
                        trailing: Text('${e['amount']} RWF'),
                        subtitle: Text(e['date'].toString().substring(0, 10)),
                      );
                    },
                  ),
            _debts.isEmpty
                ? const Center(child: Text('No debts yet.'))
                : ListView.builder(
                    itemCount: _debts.length,
                    itemBuilder: (context, index) {
                      final d = _debts[index];
                      final isOwedToYou = d['direction'] == 'owed_to_you';
                      return ListTile(
                        title: Text(d['person']),
                        subtitle: Text(isOwedToYou ? 'Owed to you' : 'You owe'),
                        trailing: Text(
                          '${d['amount']} RWF',
                          style: TextStyle(color: isOwedToYou ? Colors.green : Colors.red),
                        ),
                      );
                    },
                  ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final tabIndex = DefaultTabController.of(context).index;
            if (tabIndex == 0) {
              _showAddExpenseDialog();
            } else {
              _showAddDebtDialog();
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}