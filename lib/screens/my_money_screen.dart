import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/scroll_top_wrapper.dart';

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
  String _query = '';

  // 'owed_to_you' (Receivables) or 'you_owe' (Payables)
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

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> items, String key) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((e) => (e[key] as String).toLowerCase().contains(q))
        .toList();
  }

  // ---------- Expenses and assets ----------

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
                decoration: InputDecoration(labelText: tr('amount')),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
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
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteExpense(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(trn('delete_item_title', e['type'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DBHelper().deleteExpense(e['id'] as int);
    _loadData();
  }

  Widget _expenseList(List<Map<String, dynamic>> all, String emptyText) {
    final items = _filter(all, 'type');
    if (items.isEmpty) return Center(child: Text(emptyText));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('longpress_delete'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  trailing: Text('${formatMoney(e['amount'] as num)} RWF'),
                  subtitle: Text(e['date'].toString().substring(0, 10)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Debts (Receivables / Payables) ----------

  void _showAddDebtDialog(String initialDirection) {
    final personController = TextEditingController();
    final amountController = TextEditingController();
    String direction = initialDirection;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('add_debt')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: direction,
                  items: [
                    DropdownMenuItem(
                        value: 'owed_to_you', child: Text(tr('owed_to_you'))),
                    DropdownMenuItem(
                        value: 'you_owe', child: Text(tr('you_owe'))),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => direction = value!),
                ),
                TextField(
                  controller: personController,
                  decoration: InputDecoration(labelText: tr('person_name')),
                ),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: tr('amount')),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('cancel')),
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
              child: Text(tr('save')),
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
              title: Text(paid ? tr('mark_unpaid') : tr('mark_paid')),
              onTap: () async {
                await DBHelper().setDebtPaid(d['id'] as int, !paid);
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.warningRed),
              title: Text(tr('delete')),
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

  double _outstandingTotal(String direction) {
    double total = 0;
    for (final d in _debts) {
      if (d['direction'] == direction && (d['paid'] ?? 0) == 0) {
        total += (d['amount'] as num).toDouble();
      }
    }
    return total;
  }

  Widget _debtTile({
    required String label,
    required String sub,
    required double total,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.bold),
              ),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                '${formatMoney(total)} RWF',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ledgerHeader() {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(tr('col_name'), style: style)),
          Expanded(flex: 3, child: Text(tr('col_date'), style: style)),
          Expanded(
            flex: 4,
            child: Text(tr('col_amount'),
                textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }

  Widget _debtTab() {
    int paidFlag(Map<String, dynamic> m) => (m['paid'] ?? 0) as int;

    final showing = _filter(
      _debts.where((d) => d['direction'] == _debtView).toList(),
      'person',
    )..sort((a, b) => paidFlag(a).compareTo(paidFlag(b)));
    final isReceivable = _debtView == 'owed_to_you';
    final color = isReceivable ? AppTheme.primaryGreen : AppTheme.warningRed;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              _debtTile(
                label: tr('owed_to_you'),
                sub: tr('debtors'),
                total: _outstandingTotal('owed_to_you'),
                color: AppTheme.primaryGreen,
                selected: isReceivable,
                onTap: () => setState(() => _debtView = 'owed_to_you'),
              ),
              const SizedBox(width: 10),
              _debtTile(
                label: tr('you_owe'),
                sub: tr('creditors'),
                total: _outstandingTotal('you_owe'),
                color: AppTheme.warningRed,
                selected: !isReceivable,
                onTap: () => setState(() => _debtView = 'you_owe'),
              ),
            ],
          ),
        ),
        _ledgerHeader(),
        Expanded(
          child: showing.isEmpty
              ? Center(child: Text(tr('no_debts')))
              : ScrollTopWrapper(
                  builder: (controller) => ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: showing.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final d = showing[index];
                      final paid = (d['paid'] ?? 0) == 1;
                      return InkWell(
                        onTap: () => _showDebtActions(d),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d['person'] as String,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    if (paid)
                                      Text(tr('paid'),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.primaryGreen)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  d['date'].toString().substring(0, 10),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  formatMoney(d['amount'] as num),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: paid ? Colors.grey : color,
                                    decoration: paid
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('tap_debt_hint'),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 70),
      ],
    );
  }

  // ---------- Screen ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MenyaAppBar(
        title: tr('my_money'),
        onSearchChanged: (v) => setState(() => _query = v),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: [
            Tab(text: tr('expenses_tab')),
            Tab(text: tr('debts_tab')),
            Tab(text: tr('materials_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _expenseList(_expenses, tr('no_expenses')),
          _debtTab(),
          _expenseList(_materials, tr('no_materials')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final i = _tabController.index;
          if (i == 0) {
            _showSimpleAddDialog(
              title: tr('add_expense'),
              nameLabel: tr('expense_hint'),
              category: 'expense',
            );
          } else if (i == 1) {
            _showAddDebtDialog(_debtView);
          } else {
            _showSimpleAddDialog(
              title: tr('add_material'),
              nameLabel: tr('material_hint'),
              category: 'asset',
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}