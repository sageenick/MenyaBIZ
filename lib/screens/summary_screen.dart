import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import 'pro_screens.dart';

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

  static const _periods = ['today', 'week', 'month', 'all'];

  String _label(String key) {
    switch (key) {
      case 'today':
        return tr('today');
      case 'week':
        return tr('week');
      case 'month':
        return tr('month');
      default:
        return tr('all_time');
    }
  }

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
      final balance = (d['amount'] as num).toDouble() -
          ((d['paid_amount'] ?? 0) as num).toDouble();
      if (d['direction'] == 'owed_to_you') {
        owedToYou += balance;
      } else {
        youOwe += balance;
      }
    }

    double stockValue = 0;
    for (final p in products) {
      stockValue += (p['quantity'] as num).toDouble() *
          (p['average_cost'] as num).toDouble();
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
    var text = 'MenyaBiz - ${_label(_period)}\n'
        '${tr('sales_amount')}: ${formatMoney(r.sales)} RWF\n'
        '${tr('cost_goods')}: ${formatMoney(r.goodsCost)} RWF\n'
        '${tr('expenses')}: ${formatMoney(r.expenses)} RWF\n'
        '${tr('net_profit')}: ${formatMoney(r.netProfit)} RWF\n'
        '${tr('owed_to_you')}: ${formatMoney(_owedToYou)} RWF\n'
        '${tr('you_owe')}: ${formatMoney(_youOwe)} RWF\n'
        '${tr('stock_value')}: ${formatMoney(_stockValue)} RWF';
    if (AppSettings.instance.vatEnabled) {
      text += '\n${tr('vat_collected')}: ${formatMoney(r.vatCollected)} RWF\n'
          '${tr('vat_paid')}: ${formatMoney(r.vatPaid)} RWF\n'
          '${tr('vat_estimate')}: ${formatMoney(r.vatDue)} RWF';
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('copied_msg'))),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          const SizedBox(width: 8),
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

  Widget _periodChip(String key) {
    final selected = _period == key;
    return ChoiceChip(
      label: Text(_label(key)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: selected,
      selectedColor: AppTheme.accentBlue,
      backgroundColor: Colors.white,
      showCheckmark: false,
      side: BorderSide(
        color: selected ? AppTheme.accentBlue : Colors.grey.shade400,
      ),
      onSelected: (_) {
        setState(() => _period = key);
        _load();
      },
    );
  }

  Widget _reportTile(
      IconData icon, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(sub,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (!isPro) const Icon(Icons.lock, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final r = _report;
        final isLoss = r != null && r.netProfit < 0;
        final vatOn = AppSettings.instance.vatEnabled;

        return Scaffold(
          appBar: MenyaAppBar(title: tr('full_summary')),
          body: r == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final key in _periods) _periodChip(key),
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
                            isLoss ? tr('loss') : tr('net_profit'),
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
                          Text(
                              '${r.salesCount} ${tr('sales_word')} · ${_label(_period)}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    _card(
                      child: Column(
                        children: [
                          _row(tr('sales_amount'),
                              '${formatMoney(r.sales)} RWF'),
                          _row(tr('cost_goods'),
                              '- ${formatMoney(r.goodsCost)} RWF'),
                          _row(tr('gross_profit'),
                              '${formatMoney(r.grossProfit)} RWF'),
                          _row(tr('expenses'),
                              '- ${formatMoney(r.expenses)} RWF'),
                          const Divider(),
                          _row(tr('net_profit'),
                              '${formatMoney(r.netProfit)} RWF',
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
                          _row(tr('owed_to_you'),
                              '${formatMoney(_owedToYou)} RWF',
                              color: AppTheme.primaryGreen),
                          _row(tr('you_owe'), '${formatMoney(_youOwe)} RWF',
                              color: AppTheme.warningRed),
                        ],
                      ),
                    ),
                    _card(
                      child: Column(
                        children: [
                          _row(tr('stock_value'),
                              '${formatMoney(_stockValue)} RWF'),
                          _row(tr('materials_bought'),
                              '${formatMoney(_assetsTotal)} RWF'),
                        ],
                      ),
                    ),
                    if (vatOn)
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row(tr('vat_collected'),
                                '${formatMoney(r.vatCollected)} RWF'),
                            _row(tr('vat_paid'),
                                '- ${formatMoney(r.vatPaid)} RWF'),
                            const Divider(),
                            _row(tr('vat_estimate'),
                                '${formatMoney(r.vatDue)} RWF',
                                bold: true),
                            const SizedBox(height: 4),
                            Text(tr('vat_note'),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(tr('more_reports'),
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEDFE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PRO',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3C3489))),
                          ),
                        ],
                      ),
                    ),
                    _reportTile(
                      Icons.swap_horiz,
                      tr('cash_flow'),
                      tr('cash_flow_sub'),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const SampleReportScreen(kind: 'cashflow')),
                      ),
                    ),
                    _reportTile(
                      Icons.balance,
                      tr('balance_sheet'),
                      tr('balance_sheet_sub'),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const SampleReportScreen(kind: 'balance')),
                      ),
                    ),
                    _reportTile(
                      Icons.picture_as_pdf,
                      tr('bank_pdf'),
                      tr('bank_pdf_sub'),
                      () => openSubscription(context),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _copySummary,
                      icon: const Icon(Icons.copy),
                      label: Text(tr('copy_summary')),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
        );
      },
    );
  }
}