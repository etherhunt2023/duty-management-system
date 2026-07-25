import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../viewmodels/leave_viewmodel.dart';
import '../../core/theme/app_theme.dart';

class LeaveApplyView extends ConsumerStatefulWidget {
  const LeaveApplyView({super.key});

  @override
  ConsumerState<LeaveApplyView> createState() => _LeaveApplyViewState();
}

class _LeaveApplyViewState extends ConsumerState<LeaveApplyView> {
  final _formKey = GlobalKey<FormState>();
  String _selectedLeaveType = 'CL';
  DateTime _fromDate = DateTime.now().add(const Duration(days: 1));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));
  final _reasonController = TextEditingController();
  String? _attachmentName;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );
    if (result != null) {
      setState(() {
        _attachmentName = result.files.single.name;
      });
    }
  }

  Future<void> _submitApplication() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final success = await ref.read(leaveViewModelProvider.notifier).applyLeave(
            leaveTypeCode: _selectedLeaveType,
            fromDate: _fromDate.toIso8601String().split('T').first,
            toDate: _toDate.toIso8601String().split('T').first,
            reason: _reasonController.text.trim(),
            attachmentUrl: _attachmentName != null ? 'uploads/$_attachmentName' : null,
          );

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave application submitted successfully.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveStateVal = ref.watch(leaveViewModelProvider);
    final balances = leaveStateVal.value?.balances ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Leave'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading details
                    const Text(
                      'Request New Leave',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 18),

                    // Leave Type Selection
                    DropdownButtonFormField<String>(
                      value: _selectedLeaveType,
                      decoration: InputDecoration(
                        labelText: 'Leave Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: balances.map((b) {
                        return DropdownMenuItem(
                          value: b.leaveTypeCode,
                          child: Text('${b.leaveTypeName} (${b.remaining.toStringAsFixed(1)} days remaining)'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedLeaveType = v;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 18),

                    // Date Select Trigger
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.date_range, color: AppTheme.primaryBlue),
                        title: const Text('Select Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd').format(_fromDate)} to ${DateFormat('yyyy-MM-dd').format(_toDate)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectDateRange(context),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Reason Text input
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Reason for Leave',
                        hintText: 'Please detail your request reason...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reason';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Attachments panel
                    Card(
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                        leading: const Icon(Icons.attach_file, color: Colors.grey),
                        title: Text(
                          _attachmentName ?? 'Attach Document (PDF, Image)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _attachmentName != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: const Text('Required for Medical Leave (ML) applications', style: TextStyle(fontSize: 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _pickAttachment,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Action
                    ElevatedButton(
                      onPressed: _submitApplication,
                      child: const Text('Submit Application'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
