import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

bool get isPro => AppSettings.instance.proPreview;

void openSubscription(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
  );
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  Widget _plan(String title, String list, Color color, bool pro) {
    final lines = list.split('\n');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: pro ? color : Colors.grey.shade300, width: pro ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final on = isPro;
        return Scaffold(
          appBar: AppBar(title: Text(tr('subscription'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _plan(tr('plan_free_title'), tr('plan_free_list'),
                  AppTheme.accentBlue, false),
              _plan(tr('plan_pro_title'), tr('plan_pro_list'),
                  AppTheme.primaryGreen, true),
              Text(tr('preview_note'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              if (on)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(tr('pro_active'),
                      style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold)),
                ),
              ElevatedButton(
                onPressed: () => AppSettings.instance.setProPreview(!on),
                child: Text(on ? tr('preview_off') : tr('preview_on')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SampleReportScreen extends StatelessWidget {
  final String kind; // 'cashflow' or 'balance'
  const SampleReportScreen({super.key, required this.kind});

  Widget _row(String label, num value, {bool bold = false, bool minus = false}) {
    final style =
        TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text('${minus ? '- ' : ''}${formatMoney(value)} RWF', style: style),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cash = kind == 'cashflow';
    return Scaffold(
      appBar: AppBar(
          title: Text(cash ? tr('cash_flow') : tr('balance_sheet'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(tr('sample_banner'),
                style: const TextStyle(color: Color(0xFF633806))),
          ),
          const SizedBox(height: 12),
          if (cash)
            _card([
              _row(tr('cf_in'), 120000),
              _row(tr('cf_goods'), 70000, minus: true),
              _row(tr('cf_expenses'), 19000, minus: true),
              const Divider(),
              _row(tr('cf_net'), 31000, bold: true),
            ])
          else ...[
            _card([
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('bs_assets'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              _row(tr('bs_cash'), 225000),
              _row(tr('bs_inventory'), 64000),
              _row(tr('owed_to_you'), 18000),
              _row(tr('bs_fixed'), 90000),
              const Divider(),
              _row(tr('bs_total_assets'), 397000, bold: true),
            ]),
            _card([
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('bs_liabilities'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              _row(tr('you_owe'), 7500),
              const Divider(),
              _row(tr('bs_equity'), 389500, bold: true),
            ]),
          ],
          Text(tr('estimate_note'),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          if (!isPro)
            ElevatedButton(
              onPressed: () => openSubscription(context),
              child: Text(tr('see_plans')),
            ),
        ],
      ),
    );
  }
}