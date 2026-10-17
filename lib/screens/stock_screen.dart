import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/scroll_top_wrapper.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Map<String, dynamic>> _products = [];

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

  Map<String, dynamic>? _findProduct(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final p in _products) {
      if ((p['name'] as String).toLowerCase() == n) return p;
    }
    return null;
  }

  void _showAddOrRestockDialog({Map<String, dynamic>? preset}) {
    final nameController =
        TextEditingController(text: preset == null ? '' : preset['name'] as String);
    final qtyController = TextEditingController();
    final costController = TextEditingController();
    final priceController = TextEditingController(
        text: preset == null ? '' : _fmt(preset['sell_price'] as num));

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
            title: const Text('Add or restock'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        const InputDecoration(labelText: 'Product name'),
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
                            ? 'Restock: ${existing['quantity']} in stock now. Average cost will update.'
                            : (nameController.text.trim().isEmpty
                                ? ''
                                : 'New product'),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.primaryGreen),
                      ),
                    ),
                  ),
                  TextField(
                    controller: qtyController,
                    decoration:
                        const InputDecoration(labelText: 'Quantity bought'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  TextField(
                    controller: costController,
                    decoration:
                        const InputDecoration(labelText: 'Buy price (each)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  TextField(
                    controller: priceController,
                    decoration:
                        const InputDecoration(labelText: 'Sell price (each)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (buy > 0 && sell > 0 && sell < buy)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Sell price is lower than buy price.',
                        style: TextStyle(color: AppTheme.warningRed),
                      ),
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
                onPressed: canSave
                    ? () async {
                        if (existing != null) {
                          await DBHelper().restockProduct(
                            id: existing['id'] as int,
                            addQty: qty,
                            buyPrice: buy,
                            sellPrice: sell,
                          );
                        } else {
                          await DBHelper().insertProduct({
                            'name': nameController.text.trim(),
                            'average_cost': buy,
                            'sell_price': sell,
                            'quantity': qty,
                          });
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _loadProducts();
                      }
                    : null,
                child: Text(existing != null ? 'Restock' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MenyaAppBar(title: 'Stock'),
      body: _products.isEmpty
          ? const Center(child: Text('No products yet. Tap + to add one.'))
          : ScrollTopWrapper(
              builder: (controller) => ListView.builder(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  final qty = product['quantity'] as int;
                  return ListTile(
                    title: Text(product['name'] as String),
                    subtitle: Text(
                      'Avg cost ${_fmt(product['average_cost'] as num)} · Sell ${_fmt(product['sell_price'] as num)} RWF',
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrRestockDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}