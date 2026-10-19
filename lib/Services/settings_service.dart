import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  String language = 'en'; // 'en' or 'rw'

  Future<void> load() async {
    language = await DBHelper().getSetting('language') ?? 'en';
  }

  Future<void> setLanguage(String value) async {
    language = value;
    notifyListeners();
    await DBHelper().setSetting('language', value);
  }
}