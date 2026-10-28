import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/contact_actions.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import 'pro_screens.dart';

class ContactsScreen extends StatefulWidget {
  final String kind; // 'customer' or 'supplier'
  const ContactsScreen({super.key, required this.kind});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _low = [];

  bool get _isCustomer => widget.kind == 'customer';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await DBHelper().getContacts(widget.kind);
    final d = await DBHelper().getDebts();
    final p = await DBHelper().getProducts();
    if (!mounted) return;
    setState(() {
      _contacts = c;
      _debts = d;
      _low = p.where((x) => (x['quantity'] as int) <= 3).toList();
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  double _balanceFor(String name) {
    final dir = _isCustomer ? 'owed_to_you' : 'you_owe';
    double t = 0;
    for (final d in _debts) {
      if (d['direction'] != dir || (d['paid'] ?? 0) == 1) continue;
      if ((d['person'] as String).trim().toLowerCase() !=
          name.trim().toLowerCase()) {
        continue;
      }
      t += (d['amount'] as num).toDouble() -
          ((d['paid_amount'] ?? 0) as num).toDouble();
    }
    return t;
  }

  Future<void> _call(String phone) async {
    final ok = await callNumber(phone);
    if (!ok) _snack(tr('cannot_open'));
  }

  Future<void> _message(Map<String, dynamic> c, double balance) async {
    if (_isCustomer && !isPro) {
      openSubscription(context);
      return;
    }
    final phone = (c['phone'] as String?) ?? '';
    final name = c['name'] as String;
    final text = _isCustomer
        ? trp('reminder_msg', [name, formatMoney(balance)])
        : trp('order_msg', [name]);
    final ok = await openWhatsApp(phone, text);
    if (!ok) _snack(tr('cannot_open'));
  }

  void _showAddDialog() {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(_isCustomer ? tr('add_customer') : tr('add_supplier')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: tr('contact_name')),
              ),
              TextField(
                controller: phoneC,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('phone')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.trim().isEmpty) return;
              await DBHelper().insertContact({
                'kind': widget.kind,
                'name': nameC.text.trim(),
                'phone':
                    phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
              });
              if (!dc.mounted) return;
              Navigator.pop(dc);
              _load();
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(trn('delete_item_title', c['name'] as String)),
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
    await DBHelper().deleteContact(c['id'] as int);
    _load();
  }

  Widget _buySoonCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('buy_soon'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (_low.isEmpty)
            Text(tr('nothing_to_buy'),
                style: const TextStyle(color: Colors.grey))
          else
            for (final p in _low)
              Text('${p['name']}: ${p['quantity']} ${tr('left')}',
                  style: const TextStyle(color: AppTheme.warningRed)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MenyaAppBar(
          title: _isCustomer ? tr('customers') : tr('suppliers')),
      body: Column(
        children: [
          if (!_isCustomer) _buySoonCard(),
          Expanded(
            child: _contacts.isEmpty
                ? Center(
                    child: Text(_isCustomer
                        ? tr('no_customers')
                        : tr('no_suppliers')))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final c = _contacts[index];
                      final name = c['name'] as String;
                      final phone = (c['phone'] as String?) ?? '';
                      final balance = _balanceFor(name);
                      final parts = <String>[
                        if (phone.isNotEmpty) phone,
                        if (balance > 0)
                          trp(_isCustomer ? 'owes_you' : 'you_owe_them',
                              [formatMoney(balance)]),
                      ];
                      final showMessage = phone.isNotEmpty &&
                          (_isCustomer ? balance > 0 : true);
                      return ListTile(
                        onLongPress: () => _confirmDelete(c),
                        title: Text(name),
                        subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (phone.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.call),
                                onPressed: () => _call(phone),
                              ),
                            if (showMessage)
                              IconButton(
                                icon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.message, size: 22),
                                    if (_isCustomer && !isPro)
                                      const Icon(Icons.lock, size: 12),
                                  ],
                                ),
                                onPressed: () => _message(c, balance),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}