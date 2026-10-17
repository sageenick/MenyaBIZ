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
      version: 3,
      onCreate: _createTables,
      onUpgrade: _upgradeDB,
    );
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
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        average_cost REAL NOT NULL DEFAULT 0,
        sell_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0
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
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL DEFAULT 'expense',
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
        date TEXT NOT NULL
      )
    ''');
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

  // Restock: adds quantity and recalculates the average cost
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

  // ----- SALES -----
  // Saves the sale AND reduces stock in one safe step
  Future<void> recordSale({
    required int productId,
    required int quantity,
    required double sellPrice,
    required double cost,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sales', {
        'product_id': productId,
        'quantity': quantity,
        'sell_price': sellPrice,
        'cost': cost,
        'date': DateTime.now().toIso8601String(),
      });
      final rows = await txn.query('products',
          columns: ['quantity'], where: 'id = ?', whereArgs: [productId]);
      final current = rows.isNotEmpty ? rows.first['quantity'] as int : 0;
      final newQty = current - quantity < 0 ? 0 : current - quantity;
      await txn.update('products', {'quantity': newQty},
          where: 'id = ?', whereArgs: [productId]);
    });
  }

  // Deletes a sale AND returns the items to stock
  Future<void> deleteSale(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('sales', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final productId = rows.first['product_id'] as int;
      final qty = rows.first['quantity'] as int;
      await txn.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ?',
        [qty, productId],
      );
      await txn.delete('sales', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await database;
    return await db.query('sales', orderBy: 'date DESC');
  }

  // ----- EXPENSES (also used for assets, via the category column) -----
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.insert('expenses', expense);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
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

  Future<int> setDebtPaid(int id, bool paid) async {
    final db = await database;
    return await db.update('debts', {'paid': paid ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDebts() async {
    final db = await database;
    return await db.query('debts', orderBy: 'date DESC');
  }
}