import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'menyabiz.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _createTables,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createSettings(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createContacts(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT
      )
    ''');
  }

  Future<void> _createLedger(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS moves (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account TEXT NOT NULL,
        amount REAL NOT NULL,
        kind TEXT NOT NULL,
        ref_id INTEGER,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        total REAL NOT NULL,
        pay_method TEXT NOT NULL,
        supplier TEXT,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE sales ADD COLUMN cost REAL NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE debts ADD COLUMN paid INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
      await _createSettings(db);
      await db.execute('''
        CREATE TABLE IF NOT EXISTS receipts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier TEXT NOT NULL,
          total REAL NOT NULL,
          vat REAL NOT NULL DEFAULT 0,
          raw TEXT,
          date TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE debts ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE debts ADD COLUMN phone TEXT');
      await db.execute('UPDATE debts SET paid_amount = amount WHERE paid = 1');
      await db.execute('ALTER TABLE receipts ADD COLUMN receipt_no TEXT');
      await _createContacts(db);
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE sales ADD COLUMN sale_id INTEGER');
      await db.execute('ALTER TABLE sales ADD COLUMN payment TEXT');
      await db.execute('ALTER TABLE sales ADD COLUMN ebm_no TEXT');
      await db.execute('ALTER TABLE sales ADD COLUMN debt_id INTEGER');
      await db.execute(
          "ALTER TABLE expenses ADD COLUMN pay_method TEXT NOT NULL DEFAULT 'cash'");
      await _createLedger(db);
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        average_cost REAL NOT NULL DEFAULT 0,
        sell_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        barcode TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        sell_price REAL NOT NULL,
        cost REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        sale_id INTEGER,
        payment TEXT,
        ebm_no TEXT,
        debt_id INTEGER,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL DEFAULT 'expense',
        pay_method TEXT NOT NULL DEFAULT 'cash',
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        direction TEXT NOT NULL,
        person TEXT NOT NULL,
        amount REAL NOT NULL,
        due_date TEXT,
        paid INTEGER NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        phone TEXT,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier TEXT NOT NULL,
        receipt_no TEXT,
        total REAL NOT NULL,
        vat REAL NOT NULL DEFAULT 0,
        raw TEXT,
        date TEXT NOT NULL
      )
    ''');
    await _createSettings(db);
    await _createContacts(db);
    await _createLedger(db);
  }

  // ----- SETTINGS -----
  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows =
        await db.query('settings', where: 'setting_key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['setting_value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'setting_key': key, 'setting_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ----- MONEY MOVEMENTS (cash and mobile money ledger) -----
  Future<void> insertMove({
    required String account,
    required double amount,
    required String kind,
    int? refId,
  }) async {
    final db = await database;
    await db.insert('moves', {
      'account': account,
      'amount': amount,
      'kind': kind,
      'ref_id': refId,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, double>> getMoveTotals() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT account, SUM(amount) AS total FROM moves GROUP BY account');
    final result = <String, double>{'cash': 0, 'momo': 0};
    for (final r in rows) {
      result[r['account'] as String] = (r['total'] as num?)?.toDouble() ?? 0;
    }
    return result;
  }

  Future<void> transferMoney({
    required String from,
    required String to,
    required double amount,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      await txn.insert('moves', {
        'account': from,
        'amount': -amount,
        'kind': 'transfer',
        'ref_id': null,
        'date': now,
      });
      await txn.insert('moves', {
        'account': to,
        'amount': amount,
        'kind': 'transfer',
        'ref_id': null,
        'date': now,
      });
    });
  }

  // ----- PRODUCTS -----
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert('products', product);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await database;
    return await db
        .update('products', product, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> findProductByBarcode(String code) async {
    final db = await database;
    final rows = await db
        .query('products', where: 'barcode = ?', whereArgs: [code], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> setProductBarcode(int id, String code) async {
    final db = await database;
    await db.update('products', {'barcode': code},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restockProduct({
    required int id,
    required int addQty,
    required double buyPrice,
    required double sellPrice,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('products', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final oldQty = rows.first['quantity'] as int;
      final oldCost = (rows.first['average_cost'] as num).toDouble();
      final newQty = oldQty + addQty;
      final newCost = newQty <= 0
          ? buyPrice
          : ((oldQty * oldCost) + (addQty * buyPrice)) / newQty;
      await txn.update(
        'products',
        {'quantity': newQty, 'average_cost': newCost, 'sell_price': sellPrice},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // Records how a purchase (replenishment) was paid
  Future<void> recordPurchase({
    required int productId,
    required int quantity,
    required double unitCost,
    required String method, // cash, momo, credit
    String? supplier,
    String? phone,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final nowIso = DateTime.now().toIso8601String();
      final total = quantity * unitCost;
      final purchaseId = await txn.insert('purchases', {
        'product_id': productId,
        'quantity': quantity,
        'unit_cost': unitCost,
        'total': total,
        'pay_method': method,
        'supplier': supplier,
        'date': nowIso,
      });
      if (method == 'cash' || method == 'momo') {
        await txn.insert('moves', {
          'account': method,
          'amount': -total,
          'kind': 'purchase',
          'ref_id': purchaseId,
          'date': nowIso,
        });
      } else if (method == 'credit') {
        await txn.insert('debts', {
          'direction': 'you_owe',
          'person': supplier ?? '',
          'phone': phone,
          'amount': total,
          'paid_amount': 0,
          'paid': 0,
          'due_date': null,
          'date': nowIso,
        });
      }
    });
  }

  // ----- SALES (one row per item; rows of one basket share sale_id) -----
  Future<void> recordBasketSale({
    required List<Map<String, dynamic>> lines,
    required String payment, // cash, momo, credit
    String? ebmNo,
    String? customer,
    String? phone,
    DateTime? dueDate,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final saleId = now.millisecondsSinceEpoch;

      double total = 0;
      for (final l in lines) {
        total += (l['quantity'] as int) * (l['sell_price'] as num).toDouble();
      }

      int? debtId;
      if (payment == 'credit') {
        debtId = await txn.insert('debts', {
          'direction': 'owed_to_you',
          'person': customer ?? '',
          'phone': phone,
          'amount': total,
          'paid_amount': 0,
          'paid': 0,
          'due_date': dueDate?.toIso8601String(),
          'date': nowIso,
        });
      }

      for (final l in lines) {
        final productId = l['product_id'] as int;
        final qty = l['quantity'] as int;
        await txn.insert('sales', {
          'product_id': productId,
          'quantity': qty,
          'sell_price': (l['sell_price'] as num).toDouble(),
          'cost': (l['cost'] as num).toDouble(),
          'date': nowIso,
          'sale_id': saleId,
          'payment': payment,
          'ebm_no': ebmNo,
          'debt_id': debtId,
        });
        await txn.rawUpdate(
          'UPDATE products SET quantity = MAX(quantity - ?, 0) WHERE id = ?',
          [qty, productId],
        );
      }

      if (payment == 'cash' || payment == 'momo') {
        await txn.insert('moves', {
          'account': payment,
          'amount': total,
          'kind': 'sale',
          'ref_id': saleId,
          'date': nowIso,
        });
      }
    });
  }

  // Deletes a whole sale: returns the units to inventory and removes its money
  Future<void> deleteSaleGroup(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      int? saleId;
      int? debtId;
      for (final r in rows) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [r['quantity'], r['product_id']],
        );
        await txn.delete('sales', where: 'id = ?', whereArgs: [r['id']]);
        saleId ??= r['sale_id'] as int?;
        debtId ??= r['debt_id'] as int?;
      }
      if (saleId != null) {
        await txn.delete('moves',
            where: "kind = 'sale' AND ref_id = ?", whereArgs: [saleId]);
      }
      if (debtId != null) {
        await txn.delete('debts', where: 'id = ?', whereArgs: [debtId]);
        await txn.delete('moves',
            where: "kind IN ('debt_in','debt_out') AND ref_id = ?",
            whereArgs: [debtId]);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await database;
    return await db.query('sales', orderBy: 'date DESC');
  }

  // ----- EXPENSES (category: expense, asset, withdrawal) -----
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await txn.insert('expenses', expense);
      final method = (expense['pay_method'] ?? 'cash') as String;
      if (method == 'cash' || method == 'momo') {
        await txn.insert('moves', {
          'account': method,
          'amount': -((expense['amount'] as num).toDouble()),
          'kind': expense['category'] ?? 'expense',
          'ref_id': id,
          'date': expense['date'],
        });
      }
      return id;
    });
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
      await txn.delete('moves',
          where: "kind IN ('expense','withdrawal','asset') AND ref_id = ?",
          whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  // ----- DEBTS -----
  Future<int> insertDebt(Map<String, dynamic> debt) async {
    final db = await database;
    return await db.insert('debts', debt);
  }

  // Payment received (receivable) or paid out (payable), with the money moving
  Future<void> addDebtPayment(int id, double amount, String method) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('debts', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final total = (rows.first['amount'] as num).toDouble();
      final alreadyPaid = (rows.first['paid_amount'] as num).toDouble();
      final remaining = total - alreadyPaid;
      final pay = amount > remaining ? remaining : amount;
      if (pay <= 0) return;
      final newPaid = alreadyPaid + pay;
      await txn.update(
        'debts',
        {'paid_amount': newPaid, 'paid': newPaid >= total ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      final receivable = rows.first['direction'] == 'owed_to_you';
      await txn.insert('moves', {
        'account': method,
        'amount': receivable ? pay : -pay,
        'kind': receivable ? 'debt_in' : 'debt_out',
        'ref_id': id,
        'date': DateTime.now().toIso8601String(),
      });
    });
  }

  // Undo: back to unpaid, and remove the money recorded for its payments
  Future<void> reopenDebt(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('debts', {'paid_amount': 0, 'paid': 0},
          where: 'id = ?', whereArgs: [id]);
      await txn.delete('moves',
          where: "kind IN ('debt_in','debt_out') AND ref_id = ?",
          whereArgs: [id]);
    });
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDebts() async {
    final db = await database;
    return await db.query('debts', orderBy: 'date DESC');
  }

  // ----- CONTACTS (customers and suppliers) -----
  Future<int> insertContact(Map<String, dynamic> contact) async {
    final db = await database;
    return await db.insert('contacts', contact);
  }

  Future<int> deleteContact(int id) async {
    final db = await database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getContacts(String kind) async {
    final db = await database;
    return await db.query('contacts',
        where: 'kind = ?', whereArgs: [kind], orderBy: 'name ASC');
  }

  // ----- RECEIPTS (supplier EBM receipts, for VAT paid) -----
  Future<int> insertReceipt(Map<String, dynamic> receipt) async {
    final db = await database;
    return await db.insert('receipts', receipt);
  }

  Future<int> deleteReceipt(int id) async {
    final db = await database;
    return await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getReceipts() async {
    final db = await database;
    return await db.query('receipts', orderBy: 'date DESC');
  }
}