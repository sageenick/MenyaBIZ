import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _todaySales = 0;
  double _todayExpenses = 0;
  double _todayProfit = 0;
  List<Map<String, dynamic>> _lowStock = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    final sales = await DBHelper().getSales();
    final expenses = await DBHelper().getExpenses();
    final products = await DBHelper().getProducts();

    final today = DateTime.now();
    bool isToday(String dateStr) {
      final d = DateTime.parse(dateStr);
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }

    double todaySalesTotal = 0;
    for (final sale in sales) {
      if (isToday(sale['date'])) {
        todaySalesTotal += (sale['sell_price'] as num) * (sale['quantity'] as num);
      }
    }

    double todayExpensesTotal = 0;
    for (final expense in expenses) {
      if (isToday(expense['date'])) {
        todayExpensesTotal += (expense['amount'] as num).toDouble();
      }
    }

    final lowStockItems = products.where((p) => (p['quantity'] as int) <= 3).toList();

    setState(() {
      _todaySales = todaySalesTotal;
      _todayExpenses = todayExpensesTotal;
      _todayProfit = todaySalesTotal - todayExpensesTotal;
      _lowStock = lowStockItems;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MenyaBiz')),
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's profit", style: TextStyle(color: Color(0xFF3B6D11))),
                  const SizedBox(height: 4),
                  Text(
                    '${_todayProfit.toStringAsFixed(0)} RWF',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF173404),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sales ${_todaySales.toStringAsFixed(0)} · Expenses ${_todayExpenses.toStringAsFixed(0)}',
                    style: const TextStyle(color: