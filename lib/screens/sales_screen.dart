import 'package:flutter/material.dart';
import '../database/db_helper.dart';

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
    setState(() {
      _products = products;
      _sales = sales;
    });
  }

  void _showRecordSaleDialog() {
    Map<String, dynamic>? selectedProduct;
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    String? warningText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final profit = selectedProduct != null &&
                  priceController.text.isNotEmpty &&
                  qtyController.text.isNotEmpty
              ? (double.tryParse(priceController.text) ?? 0) -
                  (selectedProduct!['average_cost'] as num).toDouble()
              : null;

          return AlertDialog(
            title: const Text('Record a sale'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: _products
                      .map((p) => DropdownMenuItem(value: p, child: Text(p['name'])))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedProduct = value;
                      priceController.text = value!['sell_price'].toString();
                    });
                  },
                ),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Quantity sold'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Sell price'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (profit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Profit per unit: ${profit.toStringAsFixed(0)} RWF',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (warningText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(warningText!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedProduct == null || qtyController.text.isEmpty) return;

                  final qty = int.tryParse(qtyController.text) ?? 0;
                  final available = selectedProduct!['quantity'] as int;

                  if (qty > available) {
                    setDialogState(() {
                      warningText = 'Only $available left in stock — continue anyway?';
                    });
                    return;
                  }

                  await DBHelper().insertSale({
                    'product_id': selectedProduct!['id'],
                    'quantity': qty,
                    'sell_price': double.tryParse(priceController.text) ?? 0,
                    'date': DateTime.now().toIso8601String(),
                  });

                  await DBHelper().updateProduct(selectedProduct!['id'], {
                    'quantity': available - qty,
                  });

                  Navigator.pop(context);
                  _loadData();
                },
                child: const Text('Save'),
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
      appBar: AppBar(title: const Text('Sales')),
      body: _sales.isEmpty
          ? const Center(child: Text('No sales yet. Tap + to record one.'))
          : ListView.builder(
              itemCount: _sales.length,
              itemBuilder: (context, index) {
                final sale = _sales[index];
                return ListTile(
                  title: Text('Qty: ${sale['quantity']} · ${sale['sell_price']} RWF'),
                  subtitle: Text(sale['date'].toString().substring(0, 16)),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _products.isEmpty ? null : _showRecordSaleDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}