import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../l10n/strings.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';
import 'barcode_scanner_screen.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  List<Map<String, dynamic>> _receipts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await DBHelper().getReceipts();
    if (!mounted) return;
    setState(() => _receipts = r);
  }

  Future<void> _confirmDelete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(trn('delete_item_title', r['supplier'] as String)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(tr('cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await DBHelper().deleteReceipt(r['id'] as int);
    _load();
  }

  void _showAddDialog() {
    final supplierC = TextEditingController();
    final noC = TextEditingController();
    final totalC = TextEditingController();
    final vatC = TextEditingController();
    String? raw;
    bool vatEdited = false;
    const decimal = TextInputType.numberWithOptions(decimal: true);

    showDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, setS) {
          return AlertDialog(
            title: Text(tr('add_receipt')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: supplierC,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: tr('supplier')),
                  ),
                  TextField(
                    controller: noC,
                    decoration: InputDecoration(labelText: tr('receipt_no')),
                  ),
                  TextField(
                    controller: totalC,
                    keyboardType: decimal,
                    decoration: InputDecoration(labelText: tr('total_paid')),
                    onChanged: (v) {
                      final t = double.tryParse(v) ?? 0;
                      setS(() {
                        if (!vatEdited) {
                          vatC.text =
                              t > 0 ? (t - t / 1.18).toStringAsFixed(2) : '';
                        }
                      });
                    },
                  ),
                  TextField(
                    controller: vatC,
                    keyboardType: decimal,
                    decoration: InputDecoration(labelText: tr('vat_included')),
                    onChanged: (_) => vatEdited = true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          raw == null ? '' : tr('qr_saved'),
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.primaryGreen),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(tr('scan_receipt')),
                        onPressed: () async {
                          final code = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BarcodeScannerScreen()),
                          );
                          if (code == null || !context.mounted) return;
                          setS(() => raw = code);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dc),
                  child: Text(tr('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final total = double.tryParse(totalC.text) ?? 0;
                  if (supplierC.text.trim().isEmpty || total <= 0) return;
                  await DBHelper().insertReceipt({
                    'supplier': supplierC.text.trim(),
                    'receipt_no':
                        noC.text.trim().isEmpty ? null : noC.text.trim(),
                    'total': total,
                    'vat': double.tryParse(vatC.text) ?? 0,
                    'raw': raw,
                    'date': DateTime.now().toIso8601String(),
                  });
                  if (!dc.mounted) return;
                  Navigator.pop(dc);
                  _load();
                },
                child: Text(tr('save')),
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
      appBar: MenyaAppBar(title: tr('receipts_title')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F1FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(tr('receipt_help'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF0C447C))),
          ),
          Expanded(
            child: _receipts.isEmpty
                ? Center(child: Text(tr('no_receipts')))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: _receipts.length,
                    itemBuilder: (context, index) {
                      final r = _receipts[index];
                      final no = r['receipt_no'] as String?;
                      final date = r['date'].toString().substring(0, 10);
                      return ListTile(
                        onLongPress: () => _confirmDelete(r),
                        title: Text(r['supplier'] as String),
                        subtitle: Text(no == null ? date : '$date · $no'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${formatMoney(r['total'] as num)} RWF',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              '${tr('vat_included')} ${formatMoney(r['vat'] as num)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}