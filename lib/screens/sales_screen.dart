import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/scroll_top_wrapper.dart';

String _money(num v) {
  final s = v.round().toString();
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _sales = [];

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
    return 'Unknown product';
  }

  Future<void> _confirmDeleteSale(Map<String, dynamic> sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this sale?'),
        content: const Text('The items will be returned to your stock.'),
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
    await DBHelper().deleteSale(sale['id'] as int);
    _loadData();
  }

  void _showRecordSaleSheet() {
    Map<String, dynamic>? selected;
    final searchController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();

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
                    const Text(
                      'Record a sale',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (chosen == null) ...[
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Search product',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: matches.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No product found'),
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
                                        'Sell ${_money(p['sell_price'] as num)} RWF'),
                                    trailing: Text(
                                      '$left left',
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
                                        final sp =
                                            (p['sell_price'] as num).toDouble();
                                        priceController.text =
                                            sp == sp.roundToDouble()
                                                ? sp.toStringAsFixed(0)
                                                : sp.toString();
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
                                  Text('$available in stock'),
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
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: qtyController,
                        autofocus: true,
                        decoration:
                            const InputDecoration(labelText: 'Quantity sold'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                            labelText: 'Sell price (each)'),
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
                              Text('Total: ${_money(qty * price)} RWF'),
                              const SizedBox(height: 4),
                              Text(
                                profitPerUnit >= 0
                                    ? 'Profit: ${_money(qty * profitPerUnit)} RWF'
                                    : 'Loss: ${_money(-(qty * profitPerUnit))} RWF',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: profitPerUnit >= 0
                                      ? AppTheme.primaryGreen
                                      : AppTheme.warningRed,
                                ),
                              ),
                              Text(
                                'Per item: ${_money(profitPerUnit)} RWF (cost ${_money(cost)})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      if (overselling)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Only $available left in stock. Tap "Sell anyway" to continue.',
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
                          child: const Text('Cancel'),
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
                          child: Text(overselling ? 'Sell anyway' : 'Save'),
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
    Widget body;
    if (_products.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Add products in the Stock tab first, then record sales here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_sales.isEmpty) {
      body = const Center(child: Text('No sales yet. Tap + to record one.'));
    } else {
      body = Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Long-press a sale to delete it',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          Expanded(
            child: ScrollTopWrapper(
              builder: (controller) => ListView.builder(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: _sales.length,
                itemBuilder: (context, index) {
                  final sale = _sales[index];
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
                    subtitle: Text('$qty x ${_money(price)} RWF · $date'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_money(total)} RWF',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          profit >= 0
                              ? 'Profit ${_money(profit)}'
                              : 'Loss ${_money(-profit)}',
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

    return Scaffold(
      appBar: const MenyaAppBar(title: 'Sales'),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: _products.isEmpty ? null : _showRecordSaleSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}