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

  const Report({
    required this.sales,
    required this.goodsCost,
    required this.expenses,
    required this.salesCount,
  });

  double get grossProfit => sales - goodsCost;
  double get netProfit => grossProfit - expenses;
}

class ReportService {
  // start is included, end is excluded. null means "no limit".
  static Future<Report> forRange(DateTime? start, DateTime? end) async {
    final sales = await DBHelper().getSales();
    final expenses = await DBHelper().getExpenses();

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

    return Report(
      sales: salesTotal,
      goodsCost: costTotal,
      expenses: expenseTotal,
      salesCount: count,
    );
  }
}