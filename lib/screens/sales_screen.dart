import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/scroll_top_wrapper.dart';
import 'barcode_scanner_screen.dart';
import 'new_sale_screen.dart';

class _SaleGroup {
  final List<Map<String, dynamic>> rows = [];
  String date = '';
  String? payment;
  String? ebmNo;
  double total = 0;
  double profit = 0;
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _sales = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final products = await DBHelper().getProducts();
    final sales = await DBHelper().getSales();
    if (!mounted) return;
    setState(() {
      _products = products;
      _sales = sales;
    });
  }

  String _productName(int id) {
    for (final p in _products) {
      if (p['id'] == id) return p['name'] as String;
    }
    return '-';
  }

  String _payLabel(String? p) {
    switch (p) {
      case 'cash':
        return tr('pay_cash');
      case 'momo':
        return tr('pay_momo');
      case 'credit':
        return tr('pay_credit');
      default:
        return '';
    }
  }

  List<_SaleGroup> _groups() {
    final map = <String, _SaleGroup>{};
    for (final s in _sales) {
      final saleId = s['sale_id'];
      final key = saleId != null ? 's$saleId' : 'r${s['id']}';
      final g = map.putIfAbsent(key, () {
        final x = _SaleGroup();
        x.date = s['date'] as String;
        x.payment = s['payment'] as String?;
        x.ebmNo = s['ebm_no'] as String?;
        return x;
      });
      g.rows.add(s);
      final qty = (s['quantity'] as num).toDouble();
      final price = (s['sell_price'] as num).toDouble();
      final cost = (s['cost'] as num).toDouble();
      g.total += price * qty;
      g.profit += (price - cost) * qty;
    }
    var list = map.values.toList();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((g) => g.rows.any((r) => _productName(r['product_id'] as int)
              .toLowerCase()
              .contains(q)))
          .toList();
    }
    return list;
  }

  Future<void> _confirmDelete(_SaleGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(tr('delete_sale_title')),
        content: Text(tr('delete_sale_body')),
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
    await DBHelper().deleteSaleGroup(g.rows);
    _loadData();
  }

  Future<void> _openNewSale({Map<String, dynamic>? product}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => NewSaleScreen(initialProduct: product)),
    );
    if (saved == true) _loadData();
  }

  Future<void> _scanAndSell() async {
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
      _openNewSale(product: found);
    }
  }

  Widget _saleCard(_SaleGroup g) {
    final isLoss = g.profit < 0;
    final date = g.date.substring(0, 16).replaceFirst('T', ' ');
    final pay = _payLabel(g.payment);
    return InkWell(
      onLongPress: () => _confirmDelete(g),
      child: Container(
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
            Row(
              children: [
                Expanded(
                  child: Text(date,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                if (pay.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: g.payment == 'credit'
                          ? const Color(0xFFFAEEDA)
                          : const Color(0xFFE6F1FB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pay,
                      style: TextStyle(
                        fontSize: 11,
                        color: g.payment == 'credit'
                            ? const Color(0xFF633806)
                            : const Color(0xFF0C447C),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final r in g.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_productName(r['product_id'] as int)}  ${r['quantity']} x ${formatMoney(r['sell_price'] as num)}',
                      ),
                    ),
                    Text(
                      formatMoney((r['quantity'] as num) *
                          (r['sell_price'] as num)),
                    ),
                  ],
                ),
              ),
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isLoss
                        ? '${tr('loss')} ${formatMoney(-g.profit)}'
                        : '${tr('profit')} ${formatMoney(g.profit)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isLoss
                          ? AppTheme.warningRed
                          : AppTheme.primaryGreen,
                    ),
                  ),
                ),
                Text('${formatMoney(g.total)} RWF',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            if (g.ebmNo != null && g.ebmNo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${tr('ebm_label')}: ${g.ebmNo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final hasProducts = _products.isNotEmpty;

    Widget body;
    if (_products.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(tr('add_stock_first'), textAlign: TextAlign.center),
        ),
      );
    } else if (_sales.isEmpty) {
      body = Center(child: Text(tr('no_sales')));
    } else if (groups.isEmpty) {
      body = Center(child: Text(tr('no_product_found')));
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(tr('longpress_delete_sale'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ),
          Expanded(
            child: ScrollTopWrapper(
              bottom: 140,
              builder: (controller) => ListView.builder(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 150),
                itemCount: groups.length,
                itemBuilder: (context, index) => _saleCard(groups[index]),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: MenyaAppBar(
        title: tr('sales'),
        onSearchChanged: (v) => setState(() => _query = v),
      ),
      body: body,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scanSales',
            tooltip: tr('scan_barcode'),
            onPressed: hasProducts ? _scanAndSell : null,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'addSale',
            onPressed: hasProducts ? () => _openNewSale() : null,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}