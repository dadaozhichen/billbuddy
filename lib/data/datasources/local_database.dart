import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Singleton SQLite database manager.
class LocalDatabase {
  LocalDatabase._();

  static Database? _instance;

  static Future<Database> get database async {
    _instance ??= await _initDatabase();
    return _instance!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'billbuddy.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ledgers (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT    NOT NULL,
        icon_name         TEXT    NOT NULL DEFAULT 'book',
        color_value       INTEGER NOT NULL DEFAULT 1342177842,
        default_currency  TEXT,
        sort_order        INTEGER NOT NULL DEFAULT 0,
        created_at        TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT    NOT NULL,
        icon_name       TEXT    NOT NULL,
        color_value     INTEGER NOT NULL,
        type            TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id         INTEGER NOT NULL DEFAULT 1,
        amount_in_cents   INTEGER NOT NULL,
        currency_code     TEXT    NOT NULL DEFAULT 'CNY',
        exchange_rate     REAL,
        base_currency_code TEXT   NOT NULL DEFAULT 'CNY',
        type              TEXT    NOT NULL,
        category_id       INTEGER NOT NULL,
        account_id        INTEGER NOT NULL,
        date              TEXT    NOT NULL,
        note              TEXT,
        created_at        TEXT    NOT NULL,
        FOREIGN KEY (ledger_id)   REFERENCES ledgers (id),
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (account_id)  REFERENCES accounts  (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE currencies (
        code           TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        symbol         TEXT NOT NULL,
        decimal_places INTEGER NOT NULL DEFAULT 2
      )
    ''');

    await db.execute('''
      CREATE TABLE exchange_rates (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        from_code TEXT NOT NULL,
        to_code   TEXT NOT NULL,
        rate      REAL NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(from_code, to_code)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _insertSeedData(db);
  }

  /// Upgrade path for schema changes between builds.
  static Future<void> _upgradeTables(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN exchange_rate REAL');
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN base_currency_code TEXT NOT NULL DEFAULT 'CNY'");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS currencies (
          code TEXT PRIMARY KEY, name TEXT NOT NULL,
          symbol TEXT NOT NULL, decimal_places INTEGER NOT NULL DEFAULT 2)
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exchange_rates (
          id INTEGER PRIMARY KEY AUTOINCREMENT, from_code TEXT NOT NULL,
          to_code TEXT NOT NULL, rate REAL NOT NULL,
          updated_at TEXT NOT NULL, UNIQUE(from_code, to_code))
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)
      ''');
      await _insertCurrencySeedData(db);
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ledgers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon_name TEXT NOT NULL DEFAULT 'book',
          color_value INTEGER NOT NULL DEFAULT 1342177842,
          default_currency TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL)
      ''');
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN ledger_id INTEGER NOT NULL DEFAULT 1");
      // Create a default ledger for existing records.
      await db.insert('ledgers', {
        'name': '个人账本',
        'icon_name': 'book',
        'color_value': 1342177842, // 0xFF2E7D32
        'sort_order': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (oldVersion < 4) {
      // Add business categories for existing users.
      const newCategories = <Map<String, dynamic>>[
        // Income - personal
        {'name': '红包', 'icon_name': 'card_giftcard', 'color_value': 0xFFE91E63, 'type': 'income'},
        {'name': '报销', 'icon_name': 'receipt_long', 'color_value': 0xFF795548, 'type': 'income'},
        {'name': '租金收入', 'icon_name': 'real_estate_agent', 'color_value': 0xFF009688, 'type': 'income'},
        // Income - business
        {'name': '营业收入', 'icon_name': 'store', 'color_value': 0xFF2196F3, 'type': 'income'},
        {'name': '项目收入', 'icon_name': 'assignment', 'color_value': 0xFF3F51B5, 'type': 'income'},
        {'name': '客户付款', 'icon_name': 'payments', 'color_value': 0xFF4CAF50, 'type': 'income'},
        {'name': '咨询服务', 'icon_name': 'support_agent', 'color_value': 0xFF9C27B0, 'type': 'income'},
        {'name': '销售佣金', 'icon_name': 'trending_up', 'color_value': 0xFFFF9800, 'type': 'income'},
        // Expense - business
        {'name': '办公用品', 'icon_name': 'business', 'color_value': 0xFF795548, 'type': 'expense'},
        {'name': '差旅', 'icon_name': 'flight', 'color_value': 0xFF2196F3, 'type': 'expense'},
        {'name': '税费', 'icon_name': 'request_quote', 'color_value': 0xFFF44336, 'type': 'expense'},
        {'name': '保险', 'icon_name': 'verified_user', 'color_value': 0xFF4CAF50, 'type': 'expense'},
        {'name': '工资支出', 'icon_name': 'people', 'color_value': 0xFF9C27B0, 'type': 'expense'},
        {'name': '市场推广', 'icon_name': 'campaign', 'color_value': 0xFFFF5722, 'type': 'expense'},
        {'name': '设备采购', 'icon_name': 'computer', 'color_value': 0xFF607D8B, 'type': 'expense'},
        {'name': '房租', 'icon_name': 'business_center', 'color_value': 0xFF009688, 'type': 'expense'},
        {'name': '水电', 'icon_name': 'water_drop', 'color_value': 0xFF2196F3, 'type': 'expense'},
      ];
      for (final cat in newCategories) {
        await db.insert('categories', cat);
      }
    }
  }

  /// Pre-populate default data.
  static Future<void> _insertSeedData(Database db) async {
    // ── default ledger ──────────────────────────────────────────────
    await db.insert('ledgers', {
      'name': '个人账本',
      'icon_name': 'book',
      'color_value': 1342177842,
      'sort_order': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // ── expense categories (personal + business) ────────────────────
    const expenseCategories = [
      // Personal
      ('餐饮', 'restaurant', 0xFFFF9800),
      ('交通', 'directions_car', 0xFF2196F3),
      ('购物', 'shopping_cart', 0xFFE91E63),
      ('住房', 'home', 0xFF009688),
      ('娱乐', 'videogame_asset', 0xFF9C27B0),
      ('医疗', 'local_hospital', 0xFFF44336),
      ('通讯', 'phone', 0xFF607D8B),
      ('教育', 'school', 0xFF3F51B5),
      // Business
      ('办公用品', 'business', 0xFF795548),
      ('差旅', 'flight', 0xFF2196F3),
      ('税费', 'request_quote', 0xFFF44336),
      ('保险', 'verified_user', 0xFF4CAF50),
      ('工资支出', 'people', 0xFF9C27B0),
      ('市场推广', 'campaign', 0xFFFF5722),
      ('设备采购', 'computer', 0xFF607D8B),
      ('房租', 'business_center', 0xFF009688),
      ('水电', 'water_drop', 0xFF2196F3),
    ];

    for (final (name, icon, color) in expenseCategories) {
      await db.insert('categories', {
        'name': name,
        'icon_name': icon,
        'color_value': color,
        'type': 'expense',
      });
    }

    // ── income categories (personal + business) ─────────────────────
    const incomeCategories = [
      // Personal
      ('工资', 'work', 0xFF4CAF50),
      ('兼职', 'laptop', 0xFF673AB7),
      ('投资', 'trending_up', 0xFFFF5722),
      ('红包', 'card_giftcard', 0xFFE91E63),
      ('报销', 'receipt_long', 0xFF795548),
      ('租金收入', 'real_estate_agent', 0xFF009688),
      // Business
      ('营业收入', 'store', 0xFF2196F3),
      ('项目收入', 'assignment', 0xFF3F51B5),
      ('客户付款', 'payments', 0xFF4CAF50),
      ('咨询服务', 'support_agent', 0xFF9C27B0),
      ('销售佣金', 'trending_up', 0xFFFF9800),
    ];

    for (final (name, icon, color) in incomeCategories) {
      await db.insert('categories', {
        'name': name,
        'icon_name': icon,
        'color_value': color,
        'type': 'income',
      });
    }

    // ── default accounts ───────────────────────────────────────────
    const accounts = ['微信', '支付宝', '现金', '银行卡'];
    for (var i = 0; i < accounts.length; i++) {
      await db.insert('accounts', {
        'name': accounts[i],
        'sort_order': i,
      });
    }

    // ── currencies & default setting ──────────────────────────────
    await _insertCurrencySeedData(db);
  }

  static Future<void> _insertCurrencySeedData(Database db) async {
    const currencies = [
      ('CNY', '人民币', '¥', 2),
      ('USD', '美元', '\$', 2),
      ('EUR', '欧元', '€', 2),
      ('JPY', '日元', '¥', 0),
      ('GBP', '英镑', '£', 2),
      ('HKD', '港币', 'HK\$', 2),
      ('KRW', '韩元', '₩', 0),
      ('THB', '泰铢', '฿', 2),
    ];

    for (final (code, name, symbol, dp) in currencies) {
      await db.insert('currencies', {
        'code': code,
        'name': name,
        'symbol': symbol,
        'decimal_places': dp,
      });
    }

    await db.insert('settings', {'key': 'default_currency', 'value': 'CNY'});
  }
}
