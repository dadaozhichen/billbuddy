import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/excel_row.dart';
import '../models/transaction.dart';

/// Pure I/O for reading and writing .xlsx files.
class ExcelService {
  ExcelService._();

  // ── Column layout ───────────────────────────────────────────────
  static const _colDate = '日期';
  static const _colType = '类型';
  static const _colAmount = '金额';
  static const _colCurrency = '币种';
  static const _colCategory = '分类';
  static const _colAccount = '账户';
  static const _colNote = '备注';

  static final _headers = [
    _colDate,
    _colType,
    _colAmount,
    _colCurrency,
    _colCategory,
    _colAccount,
    _colNote,
  ];

  // ── Export ──────────────────────────────────────────────────────

  /// Build an .xlsx [Uint8List] from [transactions].
  ///
  /// Throws [FormatException] if the Excel library fails to encode.
  static Uint8List export({
    required List<Transaction> transactions,
    required Map<int, String> categoryNames,
    required Map<int, String> accountNames,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['账单'];

    // Header row.
    sheet.appendRow(_headers.map((h) => TextCellValue(h)).toList());

    // Data rows.
    final dateFmt = DateFormat('yyyy-MM-dd');
    for (final t in transactions) {
      sheet.appendRow([
        TextCellValue(dateFmt.format(t.date)),
        TextCellValue(t.isExpense ? '支出' : '收入'),
        DoubleCellValue(t.amount),
        TextCellValue(t.currencyCode),
        TextCellValue(categoryNames[t.categoryId] ?? '未知'),
        TextCellValue(accountNames[t.accountId] ?? '未知'),
        TextCellValue(t.note ?? ''),
      ]);
    }

    // ── Summary rows ───────────────────────────────────────────────
    final totalIncome = transactions
        .where((t) => t.isIncome)
        .fold<double>(0, (sum, t) => sum + t.baseAmount);
    final totalExpense = transactions
        .where((t) => t.isExpense)
        .fold<double>(0, (sum, t) => sum + t.baseAmount);
    final balance = totalIncome - totalExpense;
    final baseCurrency = transactions.first.baseCurrencyCode;

    sheet.appendRow([TextCellValue('')]); // blank separator

    sheet.appendRow([
      TextCellValue('汇总'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    void addSummaryRow(String label, double value) {
      sheet.appendRow([
        TextCellValue(label),
        TextCellValue(''),
        DoubleCellValue(value),
        TextCellValue(baseCurrency),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);
    }

    addSummaryRow('总收入', totalIncome);
    addSummaryRow('总支出', totalExpense);
    addSummaryRow('结余', balance);

    // Auto-size columns.
    for (var i = 0; i < _headers.length; i++) {
      sheet.setColumnWidth(i, 14);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw FormatException('Excel 编码失败，请重试');
    }
    return Uint8List.fromList(encoded);
  }

  // ── Import ──────────────────────────────────────────────────────

  /// Parse [bytes] (.xlsx) into raw [ExcelRow]s and [ImportError]s.
  static ImportResult parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.firstOrNull;
    if (sheet == null) {
      return const ImportResult(rows: [], errors: []);
    }

    final rows = <ExcelRow>[];
    final errors = <ImportError>[];
    final dateFmt = DateFormat('yyyy-MM-dd');

    for (var i = 0; i < sheet.rows.length; i++) {
      final rowIndex = i + 1;
      final rowData = sheet.rows[i];

      // Skip header row.
      if (i == 0 && _isHeader(rowData)) continue;

      if (rowData.length < 6) {
        errors.add(ImportError(
          rowNumber: rowIndex,
          message: '列数不足（需要至少 6 列）',
        ));
        continue;
      }

      try {
        final date = _parseDate(rowData[0], dateFmt);
        if (date == null) {
          errors.add(ImportError(
              rowNumber: rowIndex, message: '日期格式无效（需要 yyyy-MM-dd）'));
          continue;
        }

        final typeStr = _cellStr(rowData[1]);
        if (typeStr != '支出' && typeStr != '收入') {
          errors.add(ImportError(
              rowNumber: rowIndex, message: '类型必须是"支出"或"收入"'));
          continue;
        }

        final amount = _cellNum(rowData[2]);
        if (amount == null || amount <= 0) {
          errors.add(ImportError(
              rowNumber: rowIndex, message: '金额必须是正数'));
          continue;
        }

        final currency = _cellStr(rowData[3]);
        if (currency.isEmpty) {
          errors.add(ImportError(
              rowNumber: rowIndex, message: '币种不能为空'));
          continue;
        }

        final category = _cellStr(rowData[4]);
        if (category.isEmpty) {
          errors.add(ImportError(
              rowNumber: rowIndex, message: '分类不能为空'));
          continue;
        }

        final account = _cellStr(rowData[5]);
        if (account.isEmpty) {
          errors.add(ImportError(
              rowNumber: rowIndex, message: '账户不能为空'));
          continue;
        }

        final note = rowData.length > 6 ? _cellStr(rowData[6]) : '';

        rows.add(ExcelRow(
          rowNumber: rowIndex,
          date: date,
          type: typeStr == '支出' ? 'expense' : 'income',
          amount: amount,
          currency: currency,
          category: category,
          account: account,
          note: note.isNotEmpty ? note : null,
        ));
      } catch (e) {
        errors.add(
            ImportError(rowNumber: rowIndex, message: '解析失败: $e'));
      }
    }

    return ImportResult(rows: rows, errors: errors);
  }

  // ── Helpers ─────────────────────────────────────────────────────

  static bool _isHeader(List<Data?> data) {
    if (data.isEmpty) return false;
    return _cellStr(data[0]) == _colDate;
  }

  static String _cellStr(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text ?? '';
    if (v is DoubleCellValue) return v.value.toString();
    if (v is IntCellValue) return v.value.toString();
    return v.toString();
  }

  static double? _cellNum(Data? cell) {
    final v = cell?.value;
    if (v == null) return null;
    if (v is DoubleCellValue) return v.value;
    if (v is IntCellValue) return v.value.toDouble();
    return double.tryParse(_cellStr(cell));
  }

  static DateTime? _parseDate(Data? cell, DateFormat fmt) {
    final v = cell?.value;
    if (v == null) return null;
    if (v is DateTimeCellValue) {
      return DateTime(v.year, v.month, v.day);
    }
    if (v is DateCellValue) {
      return DateTime(v.year, v.month, v.day);
    }
    final str = _cellStr(cell);
    if (str.isEmpty) return null;
    try {
      return fmt.parse(str);
    } catch (_) {
      try {
        return DateFormat('yyyy/M/d').parse(str);
      } catch (_) {
        return null;
      }
    }
  }
}
