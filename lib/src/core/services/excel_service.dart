import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelService {
  static final ExcelService _instance = ExcelService._internal();
  factory ExcelService() => _instance;
  ExcelService._internal();

  // Export summary matrix to Excel Workbook
  Future<void> exportMonthlySummaryExcel({
    required String monthYear,
    required List<Map<String, dynamic>> summaryData,
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Monthly Summary'];

    // Header cells styling
    final CellStyle headerStyle = CellStyle(
      bold: true,
      fontColorHex: '#FFFFFF',
      backgroundColorHex: '#0F52BA',
      fontFamily: getFontFamily(FontFamily.Calibri),
    );

    // Append Column Headers
    final List<String> headers = [
      'Employee ID',
      'Employee Name',
      'Present Days',
      'Absent Days',
      'Leave Taken',
      'OT Hours',
      'CO Earned',
      'CO Balance',
      'Remaining OT'
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = headers[col];
      cell.cellStyle = headerStyle;
    }

    // Append Data Rows
    for (int row = 0; row < summaryData.length; row++) {
      final item = summaryData[row];
      final values = [
        item['employee_id'].toString(),
        item['name'].toString(),
        item['present_days'].toString(),
        item['absent_days'].toString(),
        item['leave_taken'].toString(),
        item['ot_hours'].toString(),
        item['co_earned'].toString(),
        item['co_balance'].toString(),
        item['remaining_ot'].toString()
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
        cell.value = values[col];
      }
    }

    // Save File
    try {
      final bytes = excel.encode();
      if (bytes == null) return;

      if (kIsWeb) {
        debugPrint('Excel exported successfully: ${bytes.length} bytes. Downloading in browser.');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Summary_$monthYear.xlsx');
      await file.writeAsBytes(bytes);

      // Trigger mobile share
      await Share.shareXFiles([XFile(file.path)], text: 'Monthly Duty Register Excel - $monthYear');
    } catch (e) {
      debugPrint('Excel export failed: $e');
    }
  }
}
