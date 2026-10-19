import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/scroll_top_wrapper.dart';
import 'barcode_scanner_screen.dart';

String _priceText(num v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

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

  List<Map<String, dynamic>> get _visibleSales {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sales;
    return _sales
        .where((s) =>
            _productName(s['product_id'] as int).toLowerCase().contains(q))
        .toList();
  }

  Future<void> _confirmDeleteSale(Map<String, dynamic> sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('delete_sale_title')),
        content: Text(tr('delete_sale_body')),
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
    await DBHelper().deleteSale(sale['id'] as int);
    _loadData();
  }

  // Scan an item, then open the sale form with it already selected
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
      _showRecordSaleSheet(preselected: found);
    }
  }

  void _showRecordSaleSheet({Map<String, dynamic>? preselected}) {
    Map<String, dynamic>? selected = preselected;
    final searchController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    String? scanMessage;
    if (preselected != null) {
      priceController.text = _priceText(preselected['sell_price'] as num);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final chosen = selected;
          final query = searchController.text.trim().toLowerCase();
          final matches = _products
              .where((p) =>
                  query.isEmpty ||
                  (p['name'] as String).toLowerCase().contains(query))
              .toList();

          final qty = int.tryParse(qtyController.text) ?? 0;
          final price = double.tryParse(priceController.text) ?? 0;
          final available = chosen == null ? 0 : chosen['quantity'] as int;
          final cost =
              chosen == null ? 0.0 : (chosen['average_cost'] as num).toDouble();
          final profitPerUnit = price - cost;
          final overselling = chosen != null && qty > available;
          final canSave = chosen != null && qty > 0 && price > 0;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('record_sale'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (chosen == null) ...[
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: tr('search_product'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: tr('scan_barcode'),
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: () async {
                              final code = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BarcodeScannerScreen()),
                              );
                              if (code == null || !context.mounted) return;
                              final found =
                                  await DBHelper().findProductByBarcode(code);
                              if (!context.mounted) return;
                              setSheetState(() {
                                if (found == null) {
                                  scanMessage = tr('scan_not_found');
                                } else {
                                  scanMessage = null;
                                  selected = found;
                                  priceController.text =
                                      _priceText(found['sell_price'] as num);
                                }
                              });
                            },
                          ),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      if (scanMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            scanMessage!,
                            style: const TextStyle(color: AppTheme.warningRed),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: matches.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(tr('no_product_found')),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: matches.length,
                                itemBuilder: (context, index) {
                                  final p = matches[index];
                                  final left = p['quantity'] as int;
                                  return ListTile(
                                    title: Text(p['name'] as String),
                                    subtitle: Text(
                                        '${formatMoney(p['sell_price'] as num)} RWF'),
                                    trailing: Text(
                                      '$left ${tr('in_stock')}',
                                      style: TextStyle(
                                        color: left <= 0
                                            ? AppTheme.warningRed
                                            : null,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onTap: () {
                                      setSheetState(() {
                                        selected = p;
                                        priceController.text = _priceText(
                                            p['sell_price'] as num);
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3DE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chosen['name'] as String,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text('$available ${tr('in_stock')}'),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setSheetState(() {
                                  selected = null;
                                  qtyController.clear();
                                  priceController.clear();
                                });
                              },
                              child: Text(tr('change_item')),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: qtyController,
                        autofocus: true,
                        decoration:
                            InputDecoration(labelText: tr('qty_sold')),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      TextField(
                        controller: priceController,
                        decoration:
                            InputDecoration(labelText: tr('sell_price_each')),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 12),
                      if (qty > 0 && price > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: profitPerUnit >= 0
                                ? const Color(0xFFEAF3DE)
                                : const Color(0xFFFCEBEB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${tr('total')}: ${formatMoney(qty * price)} RWF'),
                              const SizedBox(height: 4),
                              Text(
                                profitPerUnit >= 0
                                    ? '${tr('profit')}: ${formatMoney(qty * profitPerUnit)} RWF'
                                    : '${tr('loss')}: ${formatMoney(-(qty * profitPerUnit))} RWF',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: profitPerUnit >= 0
                                      ? AppTheme.primaryGreen
                                      : AppTheme.warningRed,
                                ),
                              ),
                              Text(
                                '${tr('per_item')}: ${formatMoney(profitPerUnit)} RWF (${tr('cost_label')} ${formatMoney(cost)})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      if (overselling)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            trn('only_left_warning', available),
                            style: const TextStyle(color: AppTheme.warningRed),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(tr('cancel')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: canSave
                              ? () async {
                                  final c = selected;
                                  if (c == null) return;
                                  await DBHelper().recordSale(
                                    productId: c['id'] as int,
                                    quantity: qty,
                                    sellPrice: price,
                                    cost: cost,
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                  _loadData();
                                }
                              : null,
                          child: Text(
                              overselling ? tr('sell_anyway') : tr('save')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sales = _visibleSales;

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
    } else if (sales.isEmpty) {
      body = Center(child: Text(tr('no_product_found')));
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr('longpress_delete_sale'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          Expanded(
            child: ScrollTopWrapper(
              bottom: 140,
              builder: (controller) => ListView.builder(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 150),
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  final qty = sale['quantity'] as int;
                  final price = (sale['sell_price'] as num).toDouble();
                  final cost = (sale['cost'] as num).toDouble();
                  final total = price * qty;
                  final profit = (price - cost) * qty;
                  final date = sale['date']
                      .toString()
                      .substring(0, 16)
                      .replaceFirst('T', ' ');
                  return ListTile(
                    onLongPress: () => _confirmDeleteSale(sale),
                    title: Text(_productName(sale['product_id'] as int)),
                    subtitle: Text('$qty x ${formatMoney(price)} RWF · $date'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${formatMoney(total)} RWF',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          profit >= 0
                              ? '${tr('profit')} ${formatMoney(profit)}'
                              : '${tr('loss')} ${formatMoney(-profit)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: profit >= 0
                                ? AppTheme.primaryGreen
                                : AppTheme.warningRed,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    final hasProducts = _products.isNotEmpty;

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
            onPressed: hasProducts ? () => _showRecordSaleSheet() : null,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}