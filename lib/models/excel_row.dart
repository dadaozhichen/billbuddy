/// A single row parsed from an imported Excel file.
///
/// All fields are raw strings/numbers from the spreadsheet;
/// validation and DB-lookup happen in the calling layer.
class ExcelRow {
  final int rowNumber;
  final DateTime date;
  final String type;
  final double amount;
  final String currency;
  final String category;
  final String account;
  final String? note;

  const ExcelRow({
    required this.rowNumber,
    required this.date,
    required this.type,
    required this.amount,
    required this.currency,
    required this.category,
    required this.account,
    this.note,
  });
}

/// Validation or parsing error for a specific row.
class ImportError {
  final int rowNumber;
  final String message;

  const ImportError({required this.rowNumber, required this.message});
}

/// The result of parsing an entire Excel file.
class ImportResult {
  final List<ExcelRow> rows;
  final List<ImportError> errors;

  const ImportResult({required this.rows, required this.errors});

  int get validCount => rows.length;
  int get errorCount => errors.length;
}
