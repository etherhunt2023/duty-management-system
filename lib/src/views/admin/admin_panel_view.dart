import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/employee_viewmodel.dart';

class AdminPanelView extends ConsumerStatefulWidget {
  const AdminPanelView({super.key});

  @override
  ConsumerState<AdminPanelView> createState() => _AdminPanelViewState();
}

class _AdminPanelViewState extends ConsumerState<AdminPanelView> {
  bool _carryForwardEl = true;
  bool _carryForwardOt = true;
  bool _resetCl = true;
  int _coExpiryMonths = 6;
  bool _isLoading = false;

  // Run Year End Rollover Calculations
  Future<void> _runYearEndRollover() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate year-end balance roll-over calculations
    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Year End Rollover Complete'),
            content: const Text(
              'All employee balances have been calculated and rolled over:\n'
              '- Casual Leave (CL) reset to 8.0 days\n'
              '- Earned Leave (EL) carried forward (capped at 30 days)\n'
              '- Overtime (OT) carry-forward preserved\n'
              '- Expired Compensatory Offs (CO) cleaned up.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    }
  }

  // Simulate Backup/Restore
  Future<void> _backupDatabase() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Database backup archive created (backup_dms_latest.sql)')),
    );
  }

  Future<void> _restoreDatabase() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Database restore from backup successful.')),
    );
  }

  // Open dialog to add custom leave type
  void _openAddLeaveTypeDialog() {
    final leaveNameCtrl = TextEditingController();
    final leaveCodeCtrl = TextEditingController();
    bool carryFwd = false;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Leave Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: leaveNameCtrl,
                decoration: const InputDecoration(labelText: 'Category Name (e.g., Maternity Leave)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: leaveCodeCtrl,
                decoration: const InputDecoration(labelText: 'Short Code (e.g., ML)'),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: carryFwd,
                title: const Text('Allow Carry Forward'),
                onChanged: (v) {
                  if (v != null) carryFwd = v;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = leaveNameCtrl.text.trim();
                final code = leaveCodeCtrl.text.trim().toUpperCase();
                if (name.isNotEmpty && code.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Leave category "$name ($code)" added successfully.')),
                  );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Control Panel'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Executing Year-End Rollover. Restructuring balances...', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Year-end rollover options
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                              SizedBox(width: 12),
                              Text('Year End Rollover Processing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Carry Forward Earned Leave (EL)'),
                            subtitle: const Text('Preserves unused EL up to a configurable cap of 30 days.'),
                            value: _carryForwardEl,
                            onChanged: (v) => setState(() => _carryForwardEl = v),
                          ),
                          SwitchListTile(
                            title: const Text('Carry Forward Remaining Overtime (OT)'),
                            subtitle: const Text('Preserves running accumulated minutes toward the next CO conversion.'),
                            value: _carryForwardOt,
                            onChanged: (v) => setState(() => _carryForwardOt = v),
                          ),
                          SwitchListTile(
                            title: const Text('Reset Casual Leave (CL)'),
                            subtitle: const Text('Clears remaining CL and resets opening balance to 8.0 days.'),
                            value: _resetCl,
                            onChanged: (v) => setState(() => _resetCl = v),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.rocket_launch),
                            label: const Text('Run Annual Rollover'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _runYearEndRollover,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Backup and maintenance
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.storage, color: AppTheme.primaryBlue),
                              SizedBox(width: 12),
                              Text('Database Maintenance & Backups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Text('Backup DB'),
                                onPressed: _backupDatabase,
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: const Text('Restore DB'),
                                onPressed: _restoreDatabase,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 3: Leave Configs
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.settings_outlined, color: AppTheme.primaryBlue),
                              SizedBox(width: 12),
                              Text('Leave Category Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Define dynamic leave rules for the organization.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Leave Category'),
                            onPressed: _openAddLeaveTypeDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
