import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/report_viewmodel.dart';
import '../../core/theme/app_theme.dart';

class ReportCenterView extends ConsumerStatefulWidget {
  const ReportCenterView({super.key});

  @override
  ConsumerState<ReportCenterView> createState() => _ReportCenterViewState();
}

class _ReportCenterViewState extends ConsumerState<ReportCenterView> {
  String _selectedMonth = '2026-07';
  final List<String> _months = ['2026-05', '2026-06', '2026-07', '2026-08'];

  @override
  Widget build(BuildContext context) {
    final reportStateVal = ref.watch(reportViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Register Center'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selector & Export Buttons Panel
            Card(
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMonth,
                        decoration: InputDecoration(
                          labelText: 'Reporting Period',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedMonth = v;
                            });
                            ref.read(reportViewModelProvider.notifier).generateSummaryReport(v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        minimumSize: const Size(130, 40),
                      ),
                      onPressed: () {
                        ref.read(reportViewModelProvider.notifier).exportPdfReport(_selectedMonth);
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.table_view),
                      label: const Text('Export Excel'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(130, 40),
                      ),
                      onPressed: () {
                        ref.read(reportViewModelProvider.notifier).exportExcelReport(_selectedMonth);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Summary Table header
            Text(
              'Summary Ledger - $_selectedMonth',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Responsive Data Table
            Expanded(
              child: reportStateVal.when(
                data: (state) {
                  final list = state.monthlySummary;
                  if (list.isEmpty) {
                    return const Center(child: Text('No attendance logs found for this period.'));
                  }

                  return Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Emp ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Present', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Absent', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Leaves', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('OT Hours', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('CO Earned', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('CO Bal', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Carry OT', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: list.map((row) {
                            return DataRow(cells: [
                              DataCell(Text(row['employee_id']?.toString() ?? '')),
                              DataCell(Text(row['name']?.toString() ?? '')),
                              DataCell(Text(row['present_days']?.toString() ?? '0')),
                              DataCell(Text(row['absent_days']?.toString() ?? '0')),
                              DataCell(Text(row['leave_taken']?.toString() ?? '0')),
                              DataCell(Text(row['ot_hours']?.toString() ?? '0h')),
                              DataCell(Text(row['co_earned']?.toString() ?? '0')),
                              DataCell(Text(row['co_balance']?.toString() ?? '0')),
                              DataCell(Text(row['remaining_ot']?.toString() ?? '0h')),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading report: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
