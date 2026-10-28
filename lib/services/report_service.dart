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

  // Net profit for each of the last [days] days, oldest first
  static Future<List<double>> dailyNet(int days) async {
    final sales = await DBHelper().getSales();
    final expenses = await DBHelper().getExpenses();
    final now = DateTime.now();
    final result = <double>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      bool same(String s) {
        final x = DateTime.parse(s);
        return x.year == day.year && x.month == day.month && x.day == day.day;
      }

      double net = 0;
      for (final s in sales) {
        if (same(s['date'] as String)) {
          final q = (s['quantity'] as num).toDouble();
          net += ((s['sell_price'] as num).toDouble() -
                  (s['cost'] as num).toDouble()) *
              q;
        }
      }
      for (final e in expenses) {
        if (e['category'] == 'expense' && same(e['date'] as String)) {
          net -= (e['amount'] as num).toDouble();
        }
      }
      result.add(net);
    }
    return result;
  }
}