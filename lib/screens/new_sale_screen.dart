import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pay_method_selector.dart';
import '../widgets/top_bar.dart';
import 'barcode_scanner_screen.dart';

String _lastPayment = 'cash';

class _Line {
  final Map<String, dynamic> product;
  int qty;
  double price;
  _Line(this.product, this.qty, this.price);

  double get cost => (product['average_cost'] as num).toDouble();
  int get onHand => product['quantity'] as int;
}

class NewSaleScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;
  const NewSaleScreen({super.key, this.initialProduct});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _customers = [];
  final List<_Line> _lines = [];

  final TextEditingController _searchC = TextEditingController();
  final TextEditingController _givenC = TextEditingController();
  final TextEditingController _customerC = TextEditingController();
  final TextEditingController _phoneC = TextEditingController();
  final TextEditingController _ebmC = TextEditingController();

  String _payment = _lastPayment;
  DateTime? _due;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p != null) {
      _lines.add(_Line(p, 1, (p['sell_price'] as num).toDouble()));
    }
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    _givenC.dispose();
    _customerC.dispose();
    _phoneC.dispose();
    _ebmC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await DBHelper().getProducts();
    final customers = await DBHelper().getContacts('customer');
    if (!mounted) return;
    setState(() {
      _products = products;
      _customers = customers;
    });
  }

  double get _total =>
      _lines.fold<double>(0, (a, l) => a + l.qty * l.price);

  double get _profit =>
      _lines.fold<double>(0, (a, l) => a + (l.price - l.cost) * l.qty);

  String _priceText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _addProduct(Map<String, dynamic> p) {
    setState(() {
      final i = _lines.indexWhere((l) => l.product['id'] == p['id']);
      if (i >= 0) {
        _lines[i].qty += 1;
      } else {
        _lines.add(_Line(p, 1, (p['sell_price'] as num).toDouble()));
      }
      _searchC.clear();
    });
  }

  Future<void> _scanItem() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    final found = await DBHelper().findProductByBarcode(code);
    if (!mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('scan_not_found'))),
      );
    } else {
      _addProduct(found);
    }
  }

  Future<void> _scanEbm() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    setState(() => _ebmC.text = code);
  }

  void _editPrice(_Line l) {
    final c = TextEditingController(text: _priceText(l.price));
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(tr('sell_price_each')),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(c.text) ?? 0;
              if (v > 0) setState(() => l.price = v);
              Navigator.pop(dc);
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
    final lines = <Map<String, dynamic>>[
      for (final l in _lines)
        {
          'product_id': l.product['id'],
          'quantity': l.qty,
          'sell_price': l.price,
          'cost': l.cost,
        },
    ];
    final name = _customerC.text.trim();
    final phone = _phoneC.text.trim();
    final ebm = _ebmC.text.trim();

    await DBHelper().recordBasketSale(
      lines: lines,
      payment: _payment,
      ebmNo: ebm.isEmpty ? null : ebm,
      customer: name.isEmpty ? null : name,
      phone: phone.isEmpty ? null : phone,
      dueDate: _due,
    );

    if (_payment == 'credit' && name.isNotEmpty) {
      final known = _customers.any(
          (c) => (c['name'] as String).toLowerCase() == name.toLowerCase());
      if (!known) {
        await DBHelper().insertContact({
          'kind': 'customer',
          'name': name,
          'phone': phone.isEmpty ? null : phone,
        });
      }
    }

    _lastPayment = _payment;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger.showSnackBar(SnackBar(content: Text(tr('sale_saved'))));
  }

  BoxDecoration _card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _lineRow(_Line l) {
    final over = l.qty > l.onHand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.product['name'] as String,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (over)
                  Text(trn('line_over_stock', l.onHand),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.warningRed)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _stepBtn(Icons.remove, () {
            setState(() {
              if (l.qty <= 1) {
                _lines.remove(l);
              } else {
                l.qty -= 1;
              }
            });
          }),
          SizedBox(
            width: 28,
            child: Text('${l.qty}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          _stepBtn(Icons.add, () => setState(() => l.qty += 1)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editPrice(l),
            child: SizedBox(
              width: 64,
              child: Text(
                formatMoney(l.qty * l.price),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _lines.remove(l)),
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.close, size: 18, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final profit = _profit;
    final isLoss = profit < 0;

    final q = _searchC.text.trim().toLowerCase();
    final matches = q.isEmpty
        ? <Map<String, dynamic>>[]
        : _products
            .where((p) => (p['name'] as String).toLowerCase().contains(q))
            .take(5)
            .toList();

    final given = double.tryParse(_givenC.text) ?? 0;
    final typedName = _customerC.text.trim().toLowerCase();
    final customerMatches = typedName.isEmpty
        ? <Map<String, dynamic>>[]
        : _customers
            .where((c) {
              final n = (c['name'] as String).toLowerCase();
              return n.contains(typedName) && n != typedName;
            })
            .take(3)
            .toList();

    final needCustomer =
        _payment == 'credit' && _customerC.text.trim().isEmpty;
    final canComplete = _lines.isNotEmpty && total > 0 && !needCustomer;

    return Scaffold(
      appBar: MenyaAppBar(title: tr('new_sale')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: tr('add_item_hint'),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: tr('scan_barcode'),
                icon: const Icon(Icons.qr_code_scanner,
                    color: AppTheme.accentBlue),
                onPressed: _scanItem,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (matches.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: _card(),
              child: Column(
                children: [
                  for (final p in matches)
                    ListTile(
                      dense: true,
                      title: Text(p['name'] as String),
                      subtitle:
                          Text('${formatMoney(p['sell_price'] as num)} RWF'),
                      trailing: Text(
                        '${p['quantity']} ${tr('in_stock')}',
                        style: TextStyle(
                          color: (p['quantity'] as int) <= 0
                              ? AppTheme.warningRed
                              : null,
                        ),
                      ),
                      onTap: () => _addProduct(p),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Container(
            decoration: _card(),
            child: _lines.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(tr('basket_empty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: Colors.grey.shade300),
                        _lineRow(_lines[i]),
                      ],
                    ],
                  ),
          ),
          if (_lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(tr('tap_amount_hint'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLoss ? const Color(0xFFFCEBEB) : const Color(0xFFEAF3DE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('total'),
                        style: TextStyle(
                            fontSize: 12,
                            color: isLoss
                                ? AppTheme.warningRed
                                : AppTheme.primaryGreen)),
                    Text('${formatMoney(total)} RWF',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(isLoss ? tr('loss') : tr('profit'),
                        style: TextStyle(
                            fontSize: 12,
                            color: isLoss
                                ? AppTheme.warningRed
                                : AppTheme.primaryGreen)),
                    Text(formatMoney(profit.abs()),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(tr('payment'),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          PayMethodSelector(
            value: _payment,
            onChanged: (v) => setState(() => _payment = v),
          ),
          const SizedBox(height: 10),
          if (_payment == 'cash')
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _givenC,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('cash_given'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: given <= 0
                          ? Colors.white
                          : (given >= total
                              ? const Color(0xFFEAF3DE)
                              : const Color(0xFFFCEBEB)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          given > 0 && given < total
                              ? trn('short_by', formatMoney(total - given))
                              : tr('change'),
                          style: TextStyle(
                            fontSize: 11,
                            color: given > 0 && given < total
                                ? AppTheme.warningRed
                                : Colors.grey,
                          ),
                        ),
                        Text(
                          given >= total && total > 0
                              ? formatMoney(given - total)
                              : '-',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (_payment == 'credit') ...[
            TextField(
              controller: _customerC,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('customer_name'),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (customerMatches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final c in customerMatches)
                      ActionChip(
                        label: Text(c['name'] as String),
                        onPressed: () {
                          setState(() {
                            _customerC.text = c['name'] as String;
                            final ph = c['phone'] as String?;
                            if (ph != null && ph.isNotEmpty) {
                              _phoneC.text = ph;
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneC,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('phone'),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _due == null
                        ? tr('due_date')
                        : _due!.toIso8601String().substring(0, 10),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(onPressed: _pickDue, child: Text(tr('pick_date'))),
              ],
            ),
            if (needCustomer)
              Text(tr('need_customer'),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.warningRed)),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _ebmC,
            decoration: InputDecoration(
              labelText: tr('ebm_no'),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                tooltip: tr('scan_barcode'),
                icon: const Icon(Icons.qr_code_scanner,
                    color: AppTheme.accentBlue),
                onPressed: _scanEbm,
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(tr('ebm_hint'),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: canComplete && !_saving ? _complete : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(tr('complete_sale')),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}