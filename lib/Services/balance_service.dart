import '../database/db_helper.dart';
import 'settings_service.dart';

class Balances {
  final double cash;
  final double momo;
  const Balances(this.cash, this.momo);
}

class BalanceService {
  // Starting balance (typed by the seller) plus every recorded money movement
  static Future<Balances> current() async {
    final t = await DBHelper().getMoveTotals();
    final s = AppSettings.instance;
    return Balances(
      s.cashBalance + (t['cash'] ?? 0),
      s.momoBalance + (t['momo'] ?? 0),
    );
  }

  // Sets the balances to the typed values by recording the difference
  static Future<void> adjustTo({
    required double cash,
    required double momo,
  }) async {
    final c = await current();
    final dc = cash - c.cash;
    final dm = momo - c.momo;
    if (dc != 0) {
      await DBHelper().insertMove(account: 'cash', amount: dc, kind: 'adjust');
    }
    if (dm != 0) {
      await DBHelper().insertMove(account: 'momo', amount: dm, kind: 'adjust');
    }
  }
}