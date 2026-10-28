import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  String language = 'en';
  bool vatEnabled = false;
  bool proPreview = false;
  double cashBalance = 0;
  double momoBalance = 0;

  Future<void> load() async {
    final db = DBHelper();
    language = await db.getSetting('language') ?? 'en';
    vatEnabled = (await db.getSetting('vat_enabled')) == '1';
    proPreview = (await db.getSetting('pro_preview')) == '1';
    cashBalance =
        double.tryParse(await db.getSetting('cash_balance') ?? '') ?? 0;
    momoBalance =
        double.tryParse(await db.getSetting('momo_balance') ?? '') ?? 0;
  }

  Future<void> setLanguage(String value) async {
    language = value;
    notifyListeners();
    await DBHelper().setSetting('language', value);
  }

  Future<void> setVatEnabled(bool value) async {
    vatEnabled = value;
    notifyListeners();
    await DBHelper().setSetting('vat_enabled', value ? '1' : '0');
  }

  Future<void> setProPreview(bool value) async {
    proPreview = value;
    notifyListeners();
    await DBHelper().setSetting('pro_preview', value ? '1' : '0');
  }

  Future<void> setBalances(double cash, double momo) async {
    cashBalance = cash;
    momoBalance = momo;
    notifyListeners();
    await DBHelper().setSetting('cash_balance', cash.toString());
    await DBHelper().setSetting('momo_balance', momo.toString());
  }
}