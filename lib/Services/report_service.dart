import '../database/db_helper.dart';

String formatMoney(num v) {
  final s = v.round().toString();
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

class Report {
  final double sales;
  final double goodsCost;
  final double expenses;
  final int salesCount;
  final double vatCollected;
  final double vatPaid;

  const Report({
    required this.sales,
    required this.goodsCost,
    required this.expenses,
    required this.salesCount,
    required this.vatCollected,
    required this.vatPaid,
  });

  double get grossProfit => sales - goodsCost;
  double get netProfit => grossProfit - expenses;
  double get vatDue => vatCollected - vatPaid;
}

class ReportService {
  // start is included, end is excluded. null means "no limit".
  static Future<Report> forRange(DateTime? start, DateTime? end) async {
    final sales = await DBHelper().getSales();
    final expenses = await DBHelper().getExpenses();
    final receipts = await DBHelper().getReceipts();

    bool inRange(String dateStr) {
      final d = DateTime.parse(dateStr);
      if (start != null && d.isBefore(start)) return false;
      if (end != null && !d.isBefore(end)) return false;
      return true;
    }

    double salesTotal = 0;
    double costTotal = 0;
    int count = 0;
    for (final s in sales) {
      if (inRange(s['date'] as String)) {
        final qty = (s['quantity'] as num).toDouble();
        salesTotal += (s['sell_price'] as num).toDouble() * qty;
        costTotal += (s['cost'] as num).toDouble() * qty;
        count++;
      }
    }

    // Only real expenses count, not one-time asset purchases
    double expenseTotal = 0;
    for (final e in expenses) {
      if (e['category'] == 'expense' && inRange(e['date'] as String)) {
        expenseTotal += (e['amount'] as num).toDouble();
      }
    }

    double vatPaid = 0;
    for (final r in receipts) {
      if (inRange(r['date'] as String)) {
        vatPaid += (r['vat'] as num).toDouble();
      }
    }

    // Prices include 18% VAT: VAT = price - price / 1.18
    final vatCollected = salesTotal - salesTotal / 1.18;

    return Report(
      sales: salesTotal,
      goodsCost: costTotal,
      expenses: expenseTotal,
      salesCount: count,
      vatCollected: vatCollected,
      vatPaid: vatPaid,
    );
  }
}