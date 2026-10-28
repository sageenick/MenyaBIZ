import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/balance_service.dart';
import '../services/contact_actions.dart';
import '../services/report_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pay_method_selector.dart';
import '../widgets/top_bar.dart';
import '../widgets/scroll_top_wrapper.dart';
import 'pro_screens.dart';

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

bool _isSettled(Map<String, dynamic> d) =>
    (d['paid'] ?? 0) == 1 || _num(d['amount']) - _num(d['paid_amount']) <= 0;

int _overdueDays(Map<String, dynamic> d) {
  final due = d['due_date'] as String?;
  if (due == null || _isSettled(d)) return 0;
  final dd = DateTime.parse(due);
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(dd.year, dd.month, dd.day))
      .inDays;
  return days > 0 ? days : 0;
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
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _debts = [];
  Balances _bal = const Balances(0, 0);
  String _query = '';
  String _debtView = 'owed_to_you';
  String _lastPay = 'cash';

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
    final all = await DBHelper().getExpenses();
    final debts = await DBHelper().getDebts();
    final bal = await BalanceService.current();
    if (!mounted) return;
    setState(() {
      _expenses = all.where((e) => e['category'] != 'asset').toList();
      _materials = all.where((e) => e['category'] == 'asset').toList();
      _debts = debts;
      _bal = bal;
    });
  }

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> items, String key) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((e) => ((e[key] ?? '') as String).toLowerCase().contains(q))
        .toList();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- Balances ----------

  void _showBalanceActions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(tr('adjust_balance')),
              onTap: () {
                Navigator.pop(sheetContext);
                _editBalances();
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(tr('move_money')),
              onTap: () {
                Navigator.pop(sheetContext);
                _showMoveDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editBalances() {
    final cashC = TextEditingController(text: _bal.cash.round().toString());
    final momoC = TextEditingController(text: _bal.momo.round().toString());
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(tr('adjust_balance')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cashC,
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
              decoration: InputDecoration(labelText: tr('cash_balance')),
            ),
            TextField(
              controller: momoC,
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
              decoration: InputDecoration(labelText: tr('momo_balance')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              await BalanceService.adjustTo(
                cash: double.tryParse(cashC.text) ?? _bal.cash,
                momo: double.tryParse(momoC.text) ?? _bal.momo,
              );
              if (!dc.mounted) return;
              Navigator.pop(dc);
              _loadData();
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog() {
    final amountC = TextEditingController();
    String dir = 'momo_cash';
    showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: Text(tr('move_money')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: dir,
                items: [
                  DropdownMenuItem(
                      value: 'momo_cash', child: Text(tr('momo_to_cash'))),
                  DropdownMenuItem(
                      value: 'cash_momo', child: Text(tr('cash_to_momo'))),
                ],
                onChanged: (v) => setS(() => dir = v!),
              ),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('amount')),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dc), child: Text(tr('cancel'))),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountC.text) ?? 0;
                if (amt <= 0) return;
                await DBHelper().transferMoney(
                  from: dir == 'momo_cash' ? 'momo' : 'cash',
                  to: dir == 'momo_cash' ? 'cash' : 'momo',
                  amount: amt,
                );
                if (!dc.mounted) return;
                Navigator.pop(dc);
                _snack(tr('moved_msg'));
                _loadData();
              },
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Expenses, withdrawals, assets ----------

  void _showSimpleAddDialog({
    required String title,
    required String nameLabel,
    required String category,
  }) {
    final nameC = TextEditingController();
    final amountC = TextEditingController();
    String pay = _lastPay;
    showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameC,
                  decoration: InputDecoration(labelText: nameLabel),
                ),
                TextField(
                  controller: amountC,
                  decoration: InputDecoration(labelText: tr('amount')),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Text(tr('paid_from'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                PayMethodSelector(
                  value: pay,
                  allowCredit: false,
                  onChanged: (v) => setS(() => pay = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dc), child: Text(tr('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (nameC.text.trim().isEmpty || amountC.text.isEmpty) return;
                await DBHelper().insertExpense({
                  'type': nameC.text.trim(),
                  'amount': double.tryParse(amountC.text) ?? 0,
                  'category': category,
                  'pay_method': pay,
                  'date': DateTime.now().toIso8601String(),
                });
                _lastPay = pay;
                if (!dc.mounted) return;
                Navigator.pop(dc);
                _loadData();
              },
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseChoice() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(tr('add_expense')),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSimpleAddDialog(
                  title: tr('add_expense'),
                  nameLabel: tr('expense_hint'),
                  category: 'expense',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text(tr('withdrawal')),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSimpleAddDialog(
                  title: tr('withdrawal'),
                  nameLabel: tr('withdrawal_hint'),
                  category: 'withdrawal',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteExpense(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(trn('delete_item_title', e['type'] as String)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(tr('cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await DBHelper().deleteExpense(e['id'] as int);
    _loadData();
  }

  Widget _balanceTile(String label, IconData icon, double value) {
    return Expanded(
      child: GestureDetector(
        onTap: _showBalanceActions,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(label,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  const Icon(Icons.edit, size: 12, color: Colors.grey),
                ],
              ),
              Text(
                formatMoney(value),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: value < 0 ? AppTheme.warningRed : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownCard() {
    final totals = <String, double>{};
    final now = DateTime.now();
    for (final e in _expenses) {
      if (e['category'] != 'expense') continue;
      final d = DateTime.parse(e['date'] as String);
      if (d.year != now.year || d.month != now.month) continue;
      final raw = (e['type'] as String).trim();
      if (raw.isEmpty) continue;
      final key = raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      totals[key] = (totals[key] ?? 0) + _num(e['amount']);
    }
    if (totals.isEmpty) return const SizedBox.shrink();
    final sum = totals.values.fold<double>(0, (a, b) => a + b);
    final top = (totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('by_category'),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          for (final t in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(t.key,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sum <= 0 ? 0.0 : t.value / sum,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                        color: AppTheme.accentBlue,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text('${(t.value / sum * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _entryTile(Map<String, dynamic> e) {
    final isW = e['category'] == 'withdrawal';
    return ListTile(
      onLongPress: () => _confirmDeleteExpense(e),
      title: Text(e['type'] as String),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e['date'].toString().substring(0, 10)),
          if (isW)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFAEEDA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(tr('withdrawal_tag'),
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF633806))),
            ),
        ],
      ),
      trailing: Text('${formatMoney(e['amount'] as num)} RWF',
          style: TextStyle(color: isW ? Colors.grey : null)),
    );
  }

  Widget _entryList(List<Map<String, dynamic>> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(tr('longpress_delete'),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ),
        Expanded(
          child: ScrollTopWrapper(
            builder: (controller) => ListView.builder(
              controller: controller,
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length,
              itemBuilder: (context, index) => _entryTile(items[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _expensesTab() {
    final items = _filter(_expenses, 'type');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              _balanceTile(tr('cash'), Icons.payments, _bal.cash),
              const SizedBox(width: 8),
              _balanceTile(tr('momo'), Icons.phone_android, _bal.momo),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(tr('balance_hint'),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ),
        _breakdownCard(),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(tr('no_expenses')))
              : _entryList(items),
        ),
      ],
    );
  }

  Widget _assetsTab() {
    if (!isPro) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text(tr('assets_locked'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => openSubscription(context),
                child: Text(tr('see_plans')),
              ),
            ],
          ),
        ),
      );
    }
    final items = _filter(_materials, 'type');
    return items.isEmpty
        ? Center(child: Text(tr('no_materials')))
        : _entryList(items);
  }

  // ---------- Debts ----------

  void _showAddDebtDialog(String initialDirection) {
    final personC = TextEditingController();
    final phoneC = TextEditingController();
    final amountC = TextEditingController();
    String direction = initialDirection;
    DateTime? due;

    showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
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
                  onChanged: (v) => setS(() => direction = v!),
                ),
                TextField(
                  controller: personC,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: tr('person_name')),
                ),
                TextField(
                  controller: phoneC,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: tr('phone')),
                ),
                TextField(
                  controller: amountC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('amount')),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        due == null
                            ? tr('due_date')
                            : due!.toIso8601String().substring(0, 10),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 1095)),
                        );
                        if (d != null) setS(() => due = d);
                      },
                      child: Text(tr('pick_date')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dc), child: Text(tr('cancel'))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountC.text) ?? 0;
                if (personC.text.trim().isEmpty || amount <= 0) return;
                await DBHelper().insertDebt({
                  'direction': direction,
                  'person': personC.text.trim(),
                  'phone':
                      phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                  'amount': amount,
                  'paid_amount': 0,
                  'paid': 0,
                  'due_date': due?.toIso8601String(),
                  'date': DateTime.now().toIso8601String(),
                });
                if (!dc.mounted) return;
                Navigator.pop(dc);
                if (mounted) setState(() => _debtView = direction);
                _loadData();
              },
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentDialog(Map<String, dynamic> d) {
    final balance = _num(d['amount']) - _num(d['paid_amount']);
    final c = TextEditingController(text: balance.round().toString());
    final receivable = d['direction'] == 'owed_to_you';
    String pay = _lastPay;
    showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: Text(tr('add_payment')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: c,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('payment_amount')),
                ),
                const SizedBox(height: 12),
                Text(receivable ? tr('received_into') : tr('paid_from'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                PayMethodSelector(
                  value: pay,
                  allowCredit: false,
                  onChanged: (v) => setS(() => pay = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dc), child: Text(tr('cancel'))),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(c.text) ?? 0;
                if (amt <= 0) return;
                await DBHelper().addDebtPayment(d['id'] as int, amt, pay);
                _lastPay = pay;
                if (!dc.mounted) return;
                Navigator.pop(dc);
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
    final settled = _isSettled(d);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (settled)
              ListTile(
                leading: const Icon(Icons.undo),
                title: Text(tr('mark_unpaid')),
                onTap: () async {
                  await DBHelper().reopenDebt(d['id'] as int);
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  _loadData();
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(tr('add_payment')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddPaymentDialog(d);
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

  Future<void> _remind(Map<String, dynamic> d) async {
    if (!isPro) {
      openSubscription(context);
      return;
    }
    final phone = (d['phone'] as String?) ?? '';
    if (phone.isEmpty) {
      _snack(tr('no_phone'));
      return;
    }
    final balance = _num(d['amount']) - _num(d['paid_amount']);
    final ok = await openWhatsApp(
      phone,
      trp('reminder_msg', [d['person'] as String, formatMoney(balance)]),
    );
    if (!ok) _snack(tr('cannot_open'));
  }

  Future<void> _call(String phone) async {
    final ok = await callNumber(phone);
    if (!ok) _snack(tr('cannot_open'));
  }

  double _outstanding(String direction) {
    double t = 0;
    for (final d in _debts) {
      if (d['direction'] == direction && !_isSettled(d)) {
        t += _num(d['amount']) - _num(d['paid_amount']);
      }
    }
    return t;
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 2),
              Text('${formatMoney(total)} RWF',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
    );
  }

  Widget _debtRow(Map<String, dynamic> d) {
    final amount = _num(d['amount']);
    final paidAmt = _num(d['paid_amount']);
    final balance = amount - paidAmt;
    final settled = _isSettled(d);
    final overdue = _overdueDays(d);
    final phone = (d['phone'] as String?) ?? '';
    final isReceivable = d['direction'] == 'owed_to_you';
    final color = isReceivable ? AppTheme.primaryGreen : AppTheme.warningRed;
    final due = d['due_date'] as String?;

    Widget? statusTag;
    if (settled) {
      statusTag =
          _tag(tr('paid'), const Color(0xFFEAF3DE), const Color(0xFF27500A));
    } else if (overdue > 0) {
      statusTag = _tag(trp('overdue_days', [overdue]),
          const Color(0xFFFCEBEB), const Color(0xFF791F1F));
    } else if (due != null) {
      statusTag = _tag(trp('due_on', [due.substring(0, 10)]),
          const Color(0xFFFAEEDA), const Color(0xFF633806));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showDebtActions(d),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['person'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        '${tr('owed')} ${formatMoney(amount)} · ${tr('paid_so_far')} ${formatMoney(paidAmt)}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(tr('balance'),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      formatMoney(settled ? 0 : balance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: settled ? Colors.grey : color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: amount <= 0
                  ? 0.0
                  : (paidAmt / amount).clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
               ?statusTag,
              const Spacer(),
              if (phone.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.call, size: 22),
                  onPressed: () => _call(phone),
                ),
              if (isReceivable && !settled)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.message, size: 22),
                      if (!isPro) const Icon(Icons.lock, size: 12),
                    ],
                  ),
                  onPressed: () => _remind(d),
                ),
            ],
          ),
          if (!settled)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showAddPaymentDialog(d),
                child: Text(tr('add_payment')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _debtTab() {
    final showing = _filter(
      _debts.where((d) => d['direction'] == _debtView).toList(),
      'person',
    );
    showing.sort((a, b) {
      final sa = _isSettled(a) ? 1 : 0;
      final sb = _isSettled(b) ? 1 : 0;
      if (sa != sb) return sa - sb;
      return _overdueDays(b).compareTo(_overdueDays(a));
    });
    final isReceivable = _debtView == 'owed_to_you';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              _debtTile(
                label: tr('owed_to_you'),
                sub: tr('debtors'),
                total: _outstanding('owed_to_you'),
                color: AppTheme.primaryGreen,
                selected: isReceivable,
                onTap: () => setState(() => _debtView = 'owed_to_you'),
              ),
              const SizedBox(width: 10),
              _debtTile(
                label: tr('you_owe'),
                sub: tr('creditors'),
                total: _outstanding('you_owe'),
                color: AppTheme.warningRed,
                selected: !isReceivable,
                onTap: () => setState(() => _debtView = 'you_owe'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(tr('tap_debt_hint'),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ),
        Expanded(
          child: showing.isEmpty
              ? Center(child: Text(tr('no_debts')))
              : ScrollTopWrapper(
                  builder: (controller) => ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: showing.length,
                    itemBuilder: (context, index) => _debtRow(showing[index]),
                  ),
                ),
        ),
      ],
    );
  }

  // ---------- Screen ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
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
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr('materials_tab')),
                      if (!isPro) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock, size: 14),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _expensesTab(),
              _debtTab(),
              _assetsTab(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              final i = _tabController.index;
              if (i == 0) {
                _showExpenseChoice();
              } else if (i == 1) {
                _showAddDebtDialog(_debtView);
              } else if (isPro) {
                _showSimpleAddDialog(
                  title: tr('add_material'),
                  nameLabel: tr('material_hint'),
                  category: 'asset',
                );
              } else {
                openSubscription(context);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}