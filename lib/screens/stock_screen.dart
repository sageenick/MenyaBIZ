import 'package:flutter/material.dart';
import '../database/db_helper.dart';

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
    setState(() {
      _products = data;
    });
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Product name'),
            ),
            TextField(
              controller: costController,
              decoration: const InputDecoration(labelText: 'Buy price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Sell price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
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
              if (nameController.text.isEmpty) return;

              await DBHelper().insertProduct({
                'name': nameController.text,
                'average_cost': double.tryParse(costController.text) ?? 0,
                'sell_price': double.tryParse(priceController.text) ?? 0,
                'quantity': int.tryParse(qtyController.text) ?? 0,
              });

              Navigator.pop(context);
              _loadProducts();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: _products.isEmpty
          ? const Center(child: Text('No products yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ListTile(
                  title: Text(product['name']),
                  subtitle: Text('Qty: ${product['quantity']} · Sell: ${product['sell_price']} RWF'),
                  trailing: Text('${product['quantity']}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}