import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../core/theme/app_theme.dart';
import 'ocr_upload_view.dart';

class AttendanceListView extends ConsumerStatefulWidget {
  const AttendanceListView({super.key});

  @override
  ConsumerState<AttendanceListView> createState() => _AttendanceListViewState();
}

class _AttendanceListViewState extends ConsumerState<AttendanceListView> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      final dateStr = picked.toIso8601String().split('T').first;
      ref.read(attendanceViewModelProvider.notifier).loadAttendance(dateStr);
    }
  }

  // Dialog to manually create an attendance row
  void _openManualEntryDialog() {
    final formKey = GlobalKey<FormState>();
    String? selectedEmpId;
    String? selectedEmpName;
    String selectedShift = 'Shift A (Morning)';
    final checkInCtrl = TextEditingController(text: '08:40');
    final checkOutCtrl = TextEditingController(text: '17:00');
    final remarksCtrl = TextEditingController();

    final employeesVal = ref.read(employeeViewModelProvider);
    final empList = employeesVal.value ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Manual Attendance Entry'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Employee ID & Name'),
                    items: empList.map((e) {
                      return DropdownMenuItem(
                        value: e.employeeId,
                        child: Text('${e.employeeId} - ${e.name}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      selectedEmpId = val;
                      final emp = empList.firstWhere((e) => e.employeeId == val);
                      selectedEmpName = emp.name;
                    },
                    validator: (v) => v == null ? 'Please select employee' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedShift,
                    decoration: const InputDecoration(labelText: 'Shift'),
                    items: const [
                      DropdownMenuItem(value: 'Shift A (Morning)', child: Text('Shift A (Morning)')),
                      DropdownMenuItem(value: 'Shift B (Evening)', child: Text('Shift B (Evening)')),
                      DropdownMenuItem(value: 'Shift C (Night)', child: Text('Shift C (Night)')),
                      DropdownMenuItem(value: 'Custom Duty', child: Text('Custom Duty')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        selectedShift = v;
                        // Adjust default timings based on shift selected
                        if (v.contains('A')) {
                          checkInCtrl.text = '08:40';
                          checkOutCtrl.text = '17:00';
                        } else if (v.contains('B')) {
                          checkInCtrl.text = '16:40';
                          checkOutCtrl.text = '00:00';
                        } else if (v.contains('C')) {
                          checkInCtrl.text = '00:00';
                          checkOutCtrl.text = '09:00';
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: checkInCtrl,
                    decoration: const InputDecoration(labelText: 'Check-In Time (HH:MM)', hintText: '08:40'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: checkOutCtrl,
                    decoration: const InputDecoration(labelText: 'Check-Out Time (HH:MM)', hintText: '17:00'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedEmpId != null) {
                  final success = await ref.read(attendanceViewModelProvider.notifier).saveManualAttendance(
                        employeeId: selectedEmpId!,
                        employeeName: selectedEmpName ?? 'Staff',
                        date: _selectedDate.toIso8601String().split('T').first,
                        shiftName: selectedShift,
                        checkIn: checkInCtrl.text.trim(),
                        checkOut: checkOutCtrl.text.trim(),
                        remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                      );
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attendance log saved successfully.')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceVal = ref.watch(attendanceViewModelProvider);
    final dateStr = _selectedDate.toIso8601String().split('T').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        actions: [
          IconButton(
            tooltip: 'Select Date',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            tooltip: 'Scan Register Image/PDF',
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OcrUploadView()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter display card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Log Sheet: $dateStr',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: const Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: AppTheme.primaryBlue),
                          SizedBox(width: 4),
                          Text('Change Date', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Attendance Grid List
          Expanded(
            child: attendanceVal.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No attendance records logged for this day.'));
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final att = list[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  att.employeeName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: att.isSynced ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    att.isSynced ? 'SYNCED' : 'PENDING SYNC',
                                    style: TextStyle(
                                      color: att.isSynced ? Colors.green : Colors.amber.shade800,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildDetailItem('ID', att.employeeId),
                                _buildDetailItem('Shift', att.shiftName.split(' ').first),
                                _buildDetailItem('In/Out', '${att.checkIn ?? "--"} - ${att.checkOut ?? "--"}'),
                                _buildDetailItem('Duty Hours', att.dutyHoursString),
                                _buildDetailItem('OT Earning', att.otHoursString),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Remarks: ${att.remarks ?? "Normal"}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                if (att.coGenerated > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, color: AppTheme.primaryBlue, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Generated ${att.coGenerated} CO',
                                          style: const TextStyle(
                                            color: AppTheme.primaryBlue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading logs: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openManualEntryDialog,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
