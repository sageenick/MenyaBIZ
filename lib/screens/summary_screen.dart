import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  String _period = 'month';
  Report? _report;
  double _owedToYou = 0;
  double _youOwe = 0;
  double _stockValue = 0;
  double _assetsTotal = 0;

  static const _labels = {
    'today': 'Today',
    'week': 'Last 7 days',
    'month': 'This month',
    'all': 'All time',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final tomorrow0 = DateTime(now.year, now.month, now.day + 1);

    DateTime? start;
    DateTime? end;
    if (_period == 'today') {
      start = today0;
      end = tomorrow0;
    } else if (_period == 'week') {
      start = DateTime(now.year, now.month, now.day - 6);
      end = tomorrow0;
    } else if (_period == 'month') {
      start = DateTime(now.year, now.month, 1);
      end = tomorrow0;
    }

    final report = await ReportService.forRange(start, end);
    final debts = await DBHelper().getDebts();
    final products = await DBHelper().getProducts();
    final expenses = await DBHelper().getExpenses();

    double owedToYou = 0;
    double youOwe = 0;
    for (final d in debts) {
      if ((d['paid'] ?? 0) == 1) continue;
      final amount = (d['amount'] as num).toDouble();
      if (d['direction'] == 'owed_to_you') {
        owedToYou += amount;
      } else {
        youOwe += amount;
      }
    }

    double stockValue = 0;
    for (final p in products) {
      stockValue +=
          (p['quantity'] as num).toDouble() * (p['average_cost'] as num).toDouble();
    }

    double assets = 0;
    for (final e in expenses) {
      if (e['category'] == 'asset') assets += (e['amount'] as num).toDouble();
    }

    if (!mounted) return;
    setState(() {
      _report = report;
      _owedToYou = owedToYou;
      _youOwe = youOwe;
      _stockValue = stockValue;
      _assetsTotal = assets;
    });
  }

  Future<void> _copySummary() async {
    final r = _report;
    if (r == null) return;
    final text = 'MenyaBiz summary (${_labels[_period]})\n'
        'Sales: ${formatMoney(r.sales)} RWF\n'
        'Cost of goods: ${formatMoney(r.goodsCost)} RWF\n'
        'Expenses: ${formatMoney(r.expenses)} RWF\n'
        'Net profit: ${formatMoney(r.netProfit)} RWF\n'
        'They owe me: ${formatMoney(_owedToYou)} RWF\n'
        'I owe: ${formatMoney(_youOwe)} RWF\n'
        'Stock value: ${formatMoney(_stockValue)} RWF';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied. Paste it in WhatsApp or SMS.')),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: color == null ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final isLoss = r != null && r.netProfit < 0;

    return Scaffold(
      appBar: const MenyaAppBar(title: 'Full summary'),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final key in _labels.keys)
                      ChoiceChip(
                        label: Text(_labels[key]!),
                        selected: _period == key,
                        onSelected: (_) {
                          setState(() => _period = key);
                          _load();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _card(
                  color: isLoss
                      ? const Color(0xFFFCEBEB)
                      : const Color(0xFFEAF3DE),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoss ? 'Loss' : 'Net profit',
                        style: TextStyle(
                          color: isLoss
                              ? AppTheme.warningRed
                              : AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatMoney(r.netProfit)} RWF',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isLoss
                              ? const Color(0xFF501313)
                              : const Color(0xFF173404),
                        ),
                      ),
                      Text('${r.salesCount} sales · ${_labels[_period]}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                _card(
                  child: Column(
                    children: [
                      _row('Sales', '${formatMoney(r.sales)} RWF'),
                      _row('Cost of goods', '- ${formatMoney(r.goodsCost)} RWF'),
                      _row('Expenses', '- ${formatMoney(r.expenses)} RWF'),
                      const Divider(),
                      _row('Net profit', '${formatMoney(r.netProfit)} RWF',
                          bold: true,
                          color: isLoss
                              ? AppTheme.warningRed
                              : AppTheme.primaryGreen),
                    ],
                  ),
                ),
                _card(
                  child: Column(
                    children: [
                      _row('They owe you', '${formatMoney(_owedToYou)} RWF',
                          color: AppTheme.primaryGreen),
                      _row('You owe', '${formatMoney(_youOwe)} RWF',
                          color: AppTheme.warningRed),
                    ],
                  ),
                ),
                _card(
                  child: Column(
                    children: [
                      _row('Stock value (at cost)',
                          '${formatMoney(_stockValue)} RWF'),
                      _row('Materials bought',
                          '${formatMoney(_assetsTotal)} RWF'),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _copySummary,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy summary to share'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}