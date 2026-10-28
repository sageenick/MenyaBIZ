import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import 'contacts_screen.dart';
import 'learn_screen.dart';
import 'receipts_screen.dart';

class _Tip {
  final IconData icon;
  final Color color;
  final String text;
  const _Tip(this.icon, this.color, this.text);
}

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  List<double> _daily = List.filled(7, 0.0);
  List<String> _labels = List.filled(7, '');
  List<_Tip> _tips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final daily = await ReportService.dailyNet(7);
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final labels = [
      for (var i = 6; i >= 0; i--)
        '${DateTime(now.year, now.month, now.day - i).day}'
    ];
    final sales = await DBHelper().getSales();
    final products = await DBHelper().getProducts();
    final expenses = await DBHelper().getExpenses();
    final debts = await DBHelper().getDebts();
    final tips = <_Tip>[];

    final since = DateTime(now.year, now.month, now.day - 6);
    final qtyById = <int, int>{};
    for (final s in sales) {
      if (DateTime.parse(s['date'] as String).isBefore(since)) continue;
      final id = s['product_id'] as int;
      qtyById[id] = (qtyById[id] ?? 0) + (s['quantity'] as int);
    }
    if (qtyById.isNotEmpty) {
      final best = qtyById.entries.reduce((a, b) => a.value >= b.value ? a : b);
      for (final p in products) {
        if (p['id'] == best.key) {
          tips.add(_Tip(Icons.emoji_events, AppTheme.primaryGreen,
              trp('tip_best', [p['name'] as String])));
        }
      }
    }

    final totals = <String, double>{};
    for (final e in expenses) {
      if (e['category'] != 'expense') continue;
      final d = DateTime.parse(e['date'] as String);
      if (d.year != now.year || d.month != now.month) continue;
      final raw = (e['type'] as String).trim();
      if (raw.isEmpty) continue;
      final key = raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      totals[key] = (totals[key] ?? 0) + (e['amount'] as num).toDouble();
    }
    if (totals.isNotEmpty) {
      final sum = totals.values.fold<double>(0, (a, b) => a + b);
      final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final pct = sum > 0 ? (top.value / sum * 100).round() : 0;
      if (pct >= 20) {
        tips.add(_Tip(Icons.pie_chart, AppTheme.accentBlue,
            trp('tip_expense', [top.key, pct])));
      }
    }

    for (final p in products.where((x) => (x['quantity'] as int) <= 3).take(2)) {
      tips.add(_Tip(Icons.warning_amber, AppTheme.warningRed,
          trp('tip_low', [p['name'] as String, p['quantity'] as int])));
    }

    int overdueCount = 0;
    double overdueSum = 0;
    for (final d in debts) {
      if (d['direction'] != 'owed_to_you' || (d['paid'] ?? 0) == 1) continue;
      final due = d['due_date'] as String?;
      if (due == null) continue;
      final dd = DateTime.parse(due);
      if (DateTime(dd.year, dd.month, dd.day).isBefore(today0)) {
        overdueCount++;
        overdueSum += (d['amount'] as num).toDouble() -
            ((d['paid_amount'] ?? 0) as num).toDouble();
      }
    }
    if (overdueCount > 0) {
      tips.add(_Tip(Icons.schedule, AppTheme.warningRed,
          trp('tip_overdue', [overdueCount, formatMoney(overdueSum)])));
    }
    if (tips.isEmpty) {
      tips.add(_Tip(Icons.lightbulb_outline, Colors.grey, tr('tip_none')));
    }

    if (!mounted) return;
    setState(() {
      _daily = daily;
      _labels = labels;
      _tips = tips;
    });
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      );

  double _barHeight(double v, double maxAbs) {
    if (maxAbs == 0) return 2.0;
    final h = v.abs() / maxAbs * 80;
    return h < 2.0 ? 2.0 : h;
  }

  Widget _chartCard() {
    double maxAbs = 0;
    for (final v in _daily) {
      if (v.abs() > maxAbs) maxAbs = v.abs();
    }
    final total = _daily.fold<double>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('profit_7days'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                '${total >= 0 ? '+' : '-'} ${formatMoney(total.abs())} RWF',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      total >= 0 ? AppTheme.primaryGreen : AppTheme.warningRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final v in _daily)
                  Container(
                    width: 26,
                    height: _barHeight(v, maxAbs),
                    decoration: BoxDecoration(
                      color: v >= 0
                          ? AppTheme.primaryGreen
                          : AppTheme.warningRed,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in _labels)
                SizedBox(
                  width: 26,
                  child: Text(l,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipsCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (final t in _tips)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(t.icon, size: 20, color: t.color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.text)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, Color color, Widget screen) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => screen));
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MenyaAppBar(title: tr('business')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _chartCard(),
            const SizedBox(height: 10),
            _tipsCard(),
            const SizedBox(height: 14),
            Text(tr('tools'),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: [
                _tool(Icons.people, tr('customers'), AppTheme.accentBlue,
                    const ContactsScreen(kind: 'customer')),
                _tool(Icons.local_shipping, tr('suppliers'),
                    AppTheme.accentBlue, const ContactsScreen(kind: 'supplier')),
                _tool(Icons.school, tr('learn'), AppTheme.primaryGreen,
                    const LearnScreen()),
                _tool(Icons.receipt_long, tr('receipts'), AppTheme.primaryGreen,
                    const ReceiptsScreen()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}