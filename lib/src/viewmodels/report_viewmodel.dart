import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/supabase_service.dart';
import '../core/services/pdf_service.dart';
import '../core/services/excel_service.dart';

class ReportState {
  final List<Map<String, dynamic>> monthlySummary;
  final bool isExporting;

  ReportState({
    required this.monthlySummary,
    this.isExporting = false,
  });
}

class ReportViewModel extends StateNotifier<AsyncValue<ReportState>> {
  final SupabaseService _supabaseService;
  final _pdfService = PdfService();
  final _excelService = ExcelService();

  ReportViewModel(this._supabaseService) : super(const AsyncValue.loading()) {
    generateSummaryReport('2026-07');
  }

  // Generates summary numbers for all employees
  Future<void> generateSummaryReport(String monthYear) async {
    state = const AsyncValue.loading();
    try {
      if (!_supabaseService.isOnline) {
        // Fallback to simulated offline summaries
        await Future.delayed(const Duration(milliseconds: 400));
        state = AsyncValue.data(ReportState(monthlySummary: _generateMockSummary()));
        return;
      }

      // Fetch all profiles
      final profiles = await _supabaseService.select(table: 'profiles');
      final List<Map<String, dynamic>> summaryList = [];

      for (final prof in profiles) {
        final profileId = prof['id'];
        final empId = prof['employee_id'];
        final name = prof['name'];
        final accumOt = prof['accumulated_ot_minutes'] ?? 0;

        // Fetch this employee's attendance logs for the month
        // We match on date prefixes (e.g. '2026-07%')
        // In Supabase we can do simple filters or a direct select
        final attendance = await _supabaseService.select(
          table: 'attendance',
          match: {'employee_id': profileId},
        );

        // Filter for monthYear
        final monthlyAtt = attendance.where((a) => (a['date'] as String).startsWith(monthYear)).toList();

        final present = monthlyAtt.length;
        final absent = 30 - present; // mock total month days
        
        int otMinutes = 0;
        int coEarned = 0;
        for (final att in monthlyAtt) {
          otMinutes += (att['ot_minutes'] as num? ?? 0).toInt();
          coEarned += (att['co_generated'] as num? ?? 0).toInt();
        }

        summaryList.add({
          'employee_id': empId,
          'name': name,
          'present_days': present,
          'absent_days': absent,
          'leave_taken': 0, // placeholder
          'ot_hours': '${otMinutes ~/ 60}h ${otMinutes % 60}m',
          'co_earned': coEarned,
          'co_balance': coEarned, // simplified for reporting
          'remaining_ot': '${accumOt ~/ 60}h ${accumOt % 60}m',
        });
      }

      state = AsyncValue.data(ReportState(monthlySummary: summaryList));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Trigger PDF Report export
  Future<void> exportPdfReport(String monthYear) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(ReportState(monthlySummary: current.monthlySummary, isExporting: true));

    await _pdfService.generateMonthlySummaryPdf(
      monthYear: monthYear,
      summaryData: current.monthlySummary,
    );

    state = AsyncValue.data(ReportState(monthlySummary: current.monthlySummary, isExporting: false));
  }

  // Trigger Excel Report export
  Future<void> exportExcelReport(String monthYear) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(ReportState(monthlySummary: current.monthlySummary, isExporting: true));

    await _excelService.exportMonthlySummaryExcel(
      monthYear: monthYear,
      summaryData: current.monthlySummary,
    );

    state = AsyncValue.data(ReportState(monthlySummary: current.monthlySummary, isExporting: false));
  }

  List<Map<String, dynamic>> _generateMockSummary() {
    return [
      {
        'employee_id': 'EMP-001',
        'name': 'Mohit Kumar (Admin)',
        'present_days': 22,
        'absent_days': 0,
        'leave_taken': 2,
        'ot_hours': '18h 40m',
        'co_earned': 2,
        'co_balance': 3,
        'remaining_ot': '03h 20m',
      },
      {
        'employee_id': 'EMP-002',
        'name': 'Preeti Sen (HR)',
        'present_days': 24,
        'absent_days': 0,
        'leave_taken': 0,
        'ot_hours': '00h 00m',
        'co_earned': 0,
        'co_balance': 0,
        'remaining_ot': '00h 00m',
      },
      {
        'employee_id': 'EMP-003',
        'name': 'Rajesh Sharma',
        'present_days': 20,
        'absent_days': 2,
        'leave_taken': 2,
        'ot_hours': '08h 00m',
        'co_earned': 1,
        'co_balance': 1,
        'remaining_ot': '00h 40m',
      },
      {
        'employee_id': 'EMP-004',
        'name': 'Sanjay Singh',
        'present_days': 18,
        'absent_days': 6,
        'leave_taken': 0,
        'ot_hours': '28h 00m',
        'co_earned': 3,
        'co_balance': 2,
        'remaining_ot': '06h 00m',
      },
    ];
  }
}

final reportViewModelProvider = StateNotifierProvider<ReportViewModel, AsyncValue<ReportState>>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ReportViewModel(supabaseService);
});
