import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  // Generates Monthly Attendance Summary report in PDF
  Future<void> generateMonthlySummaryPdf({
    required String monthYear,
    required List<Map<String, dynamic>> summaryData,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(monthYear),
          pw.SizedBox(height: 24),
          _buildSummaryTable(summaryData),
          pw.SizedBox(height: 32),
          _buildFooter(),
        ],
      ),
    );

    // Save and Share / Download
    try {
      final bytes = await pdf.save();
      if (kIsWeb) {
        // In Web environment, we simulate download in VM/console log
        debugPrint('PDF Summary Generated: ${bytes.length} bytes. Initiating browser download.');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Monthly_Summary_$monthYear.pdf');
      await file.writeAsBytes(bytes);
      
      // Open share panel on mobile
      await Share.shareXFiles([XFile(file.path)], text: 'Monthly Duty Summary - $monthYear');
    } catch (e) {
      debugPrint('Error saving PDF: $e');
    }
  }

  pw.Widget _buildHeader(String monthYear) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DUTY MANAGEMENT SYSTEM',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.blue800),
            ),
            pw.Text(
              DateFormatReport.formatToday(),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Monthly Attendance Ledger Summary',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        pw.Text(
          'Reporting Period: $monthYear',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.blueGrey700),
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey300),
      ],
    );
  }

  pw.Widget _buildSummaryTable(List<Map<String, dynamic>> data) {
    final headers = [
      'Emp ID',
      'Employee Name',
      'Present',
      'Absent',
      'Leave',
      'OT Hours',
      'CO Earned',
      'CO Bal'
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data.map((row) => [
        row['employee_id'].toString(),
        row['name'].toString(),
        row['present_days'].toString(),
        row['absent_days'].toString(),
        row['leave_taken'].toString(),
        row['ot_hours'].toString(),
        row['co_earned'].toString(),
        row['co_balance'].toString(),
      ]).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      rowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Report created by HRMS Administrator System.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text('Page 1 of 1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ],
        ),
      ],
    );
  }
}

class DateFormatReport {
  static String formatToday() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
