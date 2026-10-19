import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Report? _today;
  double _thisWeek = 0;
  double _lastWeek = 0;
  List<Map<String, dynamic>> _lowStock = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final tomorrow0 = DateTime(now.year, now.month, now.day + 1);
    final weekStart = DateTime(now.year, now.month, now.day - 6);
    final lastWeekStart = DateTime(now.year, now.month, now.day - 13);

    final today = await ReportService.forRange(today0, tomorrow0);
    final week = await ReportService.forRange(weekStart, tomorrow0);
    final lastWeek = await ReportService.forRange(lastWeekStart, weekStart);
    final products = await DBHelper().getProducts();
    final lowStock =
        products.where((p) => (p['quantity'] as int) <= 3).toList();

    if (!mounted) return;
    setState(() {
      _today = today;
      _thisWeek = week.netProfit;
      _lastWeek = lastWeek.netProfit;
      _lowStock = lowStock;
    });
  }

  String _trendText() {
    if (_lastWeek > 0) {
      final pct = ((_thisWeek - _lastWeek) / _lastWeek * 100).round();
      final arrow = pct >= 0 ? '↑' : '↓';
      return '$arrow ${pct.abs()}% ${tr('vs_last_week')}';
    }
    return '${tr('last7_days')}: ${formatMoney(_thisWeek)} RWF';
  }

  @override
  Widget build(BuildContext context) {
    final t = _today;
    final profit = t?.netProfit ?? 0;
    final isLoss = profit < 0;
    final cardColor =
        isLoss ? const Color(0xFFFCEBEB) : const Color(0xFFEAF3DE);
    final labelColor =
        isLoss ? const Color(0xFFA32D2D) : const Color(0xFF3B6D11);
    final bigColor =
        isLoss ? const Color(0xFF501313) : const Color(0xFF173404);
    final trendGood = _lastWeek > 0 ? _thisWeek >= _lastWeek : _thisWeek >= 0;

    return Scaffold(
      appBar: const MenyaAppBar(title: 'MenyaBiz'),
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('todays_profit'),
                      style: TextStyle(color: labelColor)),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMoney(profit)} RWF',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: bigColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${tr('sales_amount')} ${formatMoney(t?.sales ?? 0)} · ${tr('expenses')} ${formatMoney(t?.expenses ?? 0)}',
                    style: TextStyle(color: labelColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('this_week')),
                  Flexible(
                    child: Text(
                      _trendText(),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: trendGood
                            ? AppTheme.primaryGreen
                            : AppTheme.warningRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_lowStock.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('stock_alert'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    for (final item in _lowStock)
                      Text(
                          '${item['name']}: ${item['quantity']} ${tr('left')}',
                          style: const TextStyle(color: AppTheme.warningRed)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SummaryScreen()),
                );
                _loadHomeData();
              },
              icon: const Icon(Icons.bar_chart),
              label: Text(tr('view_summary')),
            ),
          ],
        ),
      ),
    );
  }
}