import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/scroll_top_wrapper.dart';

String _money(num v) {
  final s = v.round().toString();
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

class MyMoneyScreen extends StatefulWidget {
  const MyMoneyScreen({super.key});

  @override
  State<MyMoneyScreen> createState() => _MyMoneyScreenState();
}

class _MyMoneyScreenState extends State<MyMoneyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _materials = [];

  // Which debt list is showing: 'owed_to_you' or 'you_owe'
  String _debtView = 'owed_to_you';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final allExpenses = await DBHelper().getExpenses();
    final debts = await DBHelper().getDebts();
    if (!mounted) return;
    setState(() {
      _expenses = allExpenses.where((e) => e['category'] == 'expense').toList();
      _materials = allExpenses.where((e) => e['category'] == 'asset').toList();
      _debts = debts;
    });
  }

  // ---------- Expenses and materials ----------

  void _showSimpleAddDialog({
    required String title,
    required String nameLabel,
    required String category,
  }) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: nameLabel),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  amountController.text.isEmpty) {
                return;
              }
              await DBHelper().insertExpense({
                'type': nameController.text.trim(),
                'amount': double.tryParse(amountController.text) ?? 0,
                'category': category,
                'date': DateTime.now().toIso8601String(),
              });
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteExpense(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${e['type']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DBHelper().deleteExpense(e['id'] as int);
    _loadData();
  }

  Widget _expenseList(List<Map<String, dynamic>> items, String emptyText) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Long-press an item to delete it',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        Expanded(
          child: ScrollTopWrapper(
            builder: (controller) => ListView.builder(
              controller: controller,
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final e = items[index];
                return ListTile(
                  onLongPress: () => _confirmDeleteExpense(e),
                  title: Text(e['type'] as String),
                  trailing: Text('${_money(e['amount'] as num)} RWF'),
                  subtitle: Text(e['date'].toString().substring(0, 10)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Debts ----------

  void _showAddDebtDialog(String initialDirection) {
    final personController = TextEditingController();
    final amountController = TextEditingController();
    String direction = initialDirection;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add debt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: direction,
                  items: const [
                    DropdownMenuItem(
                        value: 'owed_to_you', child: Text('They owe you')),
                    DropdownMenuItem(
                        value: 'you_owe', child: Text('You owe')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => direction = value!),
                ),
                TextField(
                  controller: personController,
                  decoration:
                      const InputDecoration(labelText: 'Person/supplier name'),
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (personController.text.trim().isEmpty ||
                    amountController.text.isEmpty) {
                  return;
                }
                await DBHelper().insertDebt({
                  'direction': direction,
                  'person': personController.text.trim(),
                  'amount': double.tryParse(amountController.text) ?? 0,
                  'due_date': null,
                  'paid': 0,
                  'date': DateTime.now().toIso8601String(),
                });
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (mounted) {
                  setState(() => _debtView = direction);
                }
                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDebtActions(Map<String, dynamic> d) {
    final paid = (d['paid'] ?? 0) == 1;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(paid ? Icons.undo : Icons.check_circle),
              title: Text(paid ? 'Mark as not paid' : 'Mark as paid'),
              onTap: () async {
                await DBHelper().setDebtPaid(d['id'] as int, !paid);
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.warningRed),
              title: const Text('Delete'),
              onTap: () async {
                await DBHelper().deleteDebt(d['id'] as int);
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  double _unpaidTotal(String direction) {
    double total = 0;
    for (final d in _debts) {
      if (d['direction'] == direction && (d['paid'] ?? 0) == 0) {
        total += (d['amount'] as num).toDouble();
      }
    }
    return total;
  }

  Widget _debtCard({
    required String label,
    required double total,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_money(total)} RWF',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debtTab() {
    int paidFlag(Map<String, dynamic> m) => (m['paid'] ?? 0) as int;

    final showing = _debts.where((d) => d['direction'] == _debtView).toList()
      ..sort((a, b) => paidFlag(a).compareTo(paidFlag(b)));
    final isOwedToYou = _debtView == 'owed_to_you';
    final color = isOwedToYou ? AppTheme.primaryGreen : AppTheme.warningRed;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _debtCard(
                label: 'They owe you',
                total: _unpaidTotal('owed_to_you'),
                color: AppTheme.primaryGreen,
                selected: isOwedToYou,
                onTap: () => setState(() => _debtView = 'owed_to_you'),
              ),
              const SizedBox(width: 12),
              _debtCard(
                label: 'You owe',
                total: _unpaidTotal('you_owe'),
                color: AppTheme.warningRed,
                selected: !isOwedToYou,
                onTap: () => setState(() => _debtView = 'you_owe'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tap a debt to mark it paid or delete it',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        Expanded(
          child: showing.isEmpty
              ? const Center(child: Text('No debts here yet.'))
              : ScrollTopWrapper(
                  builder: (controller) => ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: showing.length,
                    itemBuilder: (context, index) {
                      final d = showing[index];
                      final paid = (d['paid'] ?? 0) == 1;
                      return ListTile(
                        onTap: () => _showDebtActions(d),
                        title: Text(d['person'] as String),
                        subtitle: Text(
                          '${d['date'].toString().substring(0, 10)}${paid ? ' · Paid' : ''}',
                        ),
                        trailing: Text(
                          '${_money(d['amount'] as num)} RWF',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: paid ? Colors.grey : color,
                            decoration:
                                paid ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ---------- Screen ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MenyaAppBar(
        title: 'My money',
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 15),
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Debts'),
            Tab(text: 'Materials'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _expenseList(_expenses, 'No expenses yet.'),
          _debtTab(),
          _expenseList(_materials, 'No materials/assets yet.'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final i = _tabController.index;
          if (i == 0) {
            _showSimpleAddDialog(
              title: 'Add expense',
              nameLabel: 'What (transport, rent...)',
              category: 'expense',
            );
          } else if (i == 1) {
            _showAddDebtDialog(_debtView);
          } else {
            _showSimpleAddDialog(
              title: 'Add material/asset',
              nameLabel: 'What (fridge, shelf...)',
              category: 'asset',
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}