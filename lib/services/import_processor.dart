import '../models/category.dart';
import '../models/excel_row.dart';
import '../models/transaction.dart';

/// Matches parsed [ExcelRow]s against known categories and accounts,
/// turning valid rows into [Transaction]s that can be inserted.
///
/// Rows whose category or account can't be matched are reported as errors.
class ImportProcessor {
  /// Try to build transactions from [rows].
  ///
  /// [categories] and [accounts] are the full lists from the database;
  /// [defaultCurrencyCode] is used when a row doesn't specify one.
  /// [ledgerId] is the target ledger for every imported transaction.
  static ProcessedImport process({
    required List<ExcelRow> rows,
    required List<Category> categories,
    required Map<int, String> accounts, // id → name
    required String defaultCurrencyCode,
    required int ledgerId,
  }) {
    final transactions = <Transaction>[];
    final errors = <ImportError>[];

    // Build name-lookup maps.
    final catByName = <String, int>{};
    for (final c in categories) {
      catByName[c.name] = c.id!;
    }
    final accByName = <String, int>{};
    for (final entry in accounts.entries) {
      accByName[entry.value] = entry.key;
    }

    for (final row in rows) {
      final catId = catByName[row.category];
      if (catId == null) {
        errors.add(ImportError(
          rowNumber: row.rowNumber,
          message: '找不到分类"${row.category}"',
        ));
        continue;
      }

      final accId = accByName[row.account];
      if (accId == null) {
        errors.add(ImportError(
          rowNumber: row.rowNumber,
          message: '找不到账户"${row.account}"',
        ));
        continue;
      }

      final type = row.type == 'income'
          ? TransactionType.income
          : TransactionType.expense;

      // Normalise currency.
      final currency = row.currency.toUpperCase();
      final isBase = currency == defaultCurrencyCode;

      transactions.add(Transaction(
        amountInCents: (row.amount * 100).round(),
        currencyCode: currency,
        baseCurrencyCode: defaultCurrencyCode,
        exchangeRate: isBase ? null : null, // no rate info in basic import
        type: type,
        categoryId: catId,
        accountId: accId,
        ledgerId: ledgerId,
        date: row.date,
        note: row.note,
      ));
    }

    return ProcessedImport(transactions: transactions, errors: errors);
  }
}

class ProcessedImport {
  final List<Transaction> transactions;
  final List<ImportError> errors;

  const ProcessedImport({
    required this.transactions,
    required this.errors,
  });

  int get validCount => transactions.length;
  int get errorCount => errors.length;
}
