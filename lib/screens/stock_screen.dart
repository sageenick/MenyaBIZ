import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/scroll_top_wrapper.dart';
import 'barcode_scanner_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Map<String, dynamic>> _products = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final data = await DBHelper().getProducts();
    if (!mounted) return;
    setState(() {
      _products = data;
    });
  }

  String _fmt(num v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) {
      final name = (p['name'] as String).toLowerCase();
      final code = ((p['barcode'] ?? '') as String);
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  Map<String, dynamic>? _findProduct(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final p in _products) {
      if ((p['name'] as String).toLowerCase() == n) return p;
    }
    return null;
  }

  // Scan, then open the form: known code = replenish, new code = new item
  Future<void> _scanAndOpen() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    final found = await DBHelper().findProductByBarcode(code);
    if (!mounted) return;
    if (found != null) {
      _showAddOrRestockDialog(preset: found);
    } else {
      _showAddOrRestockDialog(scannedBarcode: code);
    }
  }

  void _showAddOrRestockDialog(
      {Map<String, dynamic>? preset, String? scannedBarcode}) {
    final nameController = TextEditingController(
        text: preset == null ? '' : preset['name'] as String);
    final qtyController = TextEditingController();
    final costController = TextEditingController();
    final priceController = TextEditingController(
        text: preset == null ? '' : _fmt(preset['sell_price'] as num));
    String? barcode =
        scannedBarcode ?? (preset == null ? null : preset['barcode'] as String?);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final existing = _findProduct(nameController.text);
          final typed = nameController.text.trim().toLowerCase();
          final matches = typed.isEmpty || existing != null
              ? <Map<String, dynamic>>[]
              : _products
                  .where((p) =>
                      (p['name'] as String).toLowerCase().contains(typed))
                  .take(3)
                  .toList();
          final qty = int.tryParse(qtyController.text) ?? 0;
          final buy = double.tryParse(costController.text) ?? 0;
          final sell = double.tryParse(priceController.text) ?? 0;
          final canSave = nameController.text.trim().isNotEmpty &&
              qty > 0 &&
              buy > 0 &&
              sell > 0;

          return AlertDialog(
            title: Text(tr('add_or_restock')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        InputDecoration(labelText: tr('product_name')),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (matches.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final p in matches)
                              ActionChip(
                                label: Text(p['name'] as String),
                                onPressed: () {
                                  final n = p['name'] as String;
                                  setDialogState(() {
                                    nameController.value = TextEditingValue(
                                      text: n,
                                      selection: TextSelection.collapsed(
                                          offset: n.length),
                                    );
                                    priceController.text =
                                        _fmt(p['sell_price'] as num);
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        existing != null
                            ? trn('restock_hint', existing['quantity'])
                            : (nameController.text.trim().isEmpty
                                ? ''
                                : tr('new_product')),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.primaryGreen),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          barcode == null
                              ? tr('no_barcode')
                              : '${tr('barcode')}: $barcode',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('scan_barcode'),
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          final code = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BarcodeScannerScreen()),
                          );
                          if (code == null || !context.mounted) return;
                          final found =
                              await DBHelper().findProductByBarcode(code);
                          if (!context.mounted) return;
                          setDialogState(() {
                            barcode = code;
                            if (found != null) {
                              nameController.text = found['name'] as String;
                              priceController.text =
                                  _fmt(found['sell_price'] as num);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  TextField(
                    controller: qtyController,
                    decoration: InputDecoration(labelText: tr('qty_bought')),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  TextField(
                    controller: costController,
                    decoration: InputDecoration(labelText: tr('buy_price')),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(labelText: tr('sell_price')),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (buy > 0 && sell > 0 && sell < buy)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        tr('sell_lower_warning'),
                        style: const TextStyle(color: AppTheme.warningRed),
                      ),
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
                onPressed: canSave
                    ? () async {
                        final code = barcode;
                        if (existing != null) {
                          await DBHelper().restockProduct(
                            id: existing['id'] as int,
                            addQty: qty,
                            buyPrice: buy,
                            sellPrice: sell,
                          );
                          if (code != null && code != existing['barcode']) {
                            await DBHelper()
                                .setProductBarcode(existing['id'] as int, code);
                          }
                        } else {
                          await DBHelper().insertProduct({
                            'name': nameController.text.trim(),
                            'average_cost': buy,
                            'sell_price': sell,
                            'quantity': qty,
                            'barcode': code,
                          });
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _loadProducts();
                      }
                    : null,
                child: Text(
                    existing != null ? tr('restock_btn') : tr('add_btn')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;

    Widget body;
    if (_products.isEmpty) {
      body = Center(child: Text(tr('no_products')));
    } else if (items.isEmpty) {
      body = Center(child: Text(tr('no_product_found')));
    } else {
      body = ScrollTopWrapper(
        bottom: 140,
        builder: (controller) => ListView.builder(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 150),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final product = items[index];
            final qty = product['quantity'] as int;
            return ListTile(
              title: Text(product['name'] as String),
              subtitle: Text(
                '${tr('avg_cost')} ${_fmt(product['average_cost'] as num)} · ${tr('sell_price')} ${_fmt(product['sell_price'] as num)} RWF',
              ),
              trailing: Text(
                '$qty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: qty <= 3 ? AppTheme.warningRed : null,
                ),
              ),
              onTap: () => _showAddOrRestockDialog(preset: product),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: MenyaAppBar(
        title: tr('stock'),
        onSearchChanged: (v) => setState(() => _query = v),
      ),
      body: body,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scanInventory',
            tooltip: tr('scan_barcode'),
            onPressed: _scanAndOpen,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'addInventory',
            onPressed: () => _showAddOrRestockDialog(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}