import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/leave_viewmodel.dart';
import '../../data/models/leave_model.dart';
import '../../core/theme/app_theme.dart';
import 'leave_apply_view.dart';

class LeaveListView extends ConsumerWidget {
  const LeaveListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveStateVal = ref.watch(leaveViewModelProvider);
    final sessionVal = ref.watch(authViewModelProvider);
    final user = sessionVal.value;
    final role = user?.role ?? 'employee';

    return leaveStateVal.when(
      data: (state) {
        final showQueueTab = role != 'employee' && role != 'viewer';

        if (!showQueueTab) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Leave Management'),
            ),
            body: Column(
              children: [
                _buildBalancesHeader(context, state.balances),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildApplicationList(context, state.myApplications, false, ref),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LeaveApplyView()),
                );
              },
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          );
        }

        // Return tabbed layout for supervisors and admins
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Leave Portal'),
              bottom: TabBar(
                indicatorColor: AppTheme.primaryBlue,
                labelColor: AppTheme.primaryBlue,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  const Tab(text: 'My Applications'),
                  Tab(text: 'Pending Approvals (${state.approvalsQueue.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                Column(
                  children: [
                    _buildBalancesHeader(context, state.balances),
                    Expanded(
                      child: _buildApplicationList(context, state.myApplications, false, ref),
                    ),
                  ],
                ),
                _buildApplicationList(context, state.approvalsQueue, true, ref),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LeaveApplyView()),
                );
              },
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  // Balance chips row
  Widget _buildBalancesHeader(BuildContext context, List<LeaveBalance> balances) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: balances.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, idx) {
          final bal = balances[idx];
          return Card(
            margin: const EdgeInsets.only(right: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bal.leaveTypeName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        bal.remaining.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Text('days left', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // List builder for applications and approvals
  Widget _buildApplicationList(
    BuildContext context,
    List<LeaveApplication> list,
    bool isQueue,
    WidgetRef ref,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isQueue ? 'No pending approval requests.' : 'No leave history found.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemBuilder: (context, idx) {
        final app = list[idx];
        final dur = app.durationDays;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    Text(
                      '${app.leaveTypeCode} Request - $dur ${dur == 1 ? "Day" : "Days"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    _buildStatusChip(app.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Employee: ${app.employeeName} (${app.employeeId})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Duration: ${app.fromDate} to ${app.toDate}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reason: ${app.reason}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (app.attachmentUrl != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_file, size: 14, color: AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        app.attachmentUrl!.split('/').last,
                        style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue, decoration: TextDecoration.underline),
                      ),
                    ],
                  ),
                ],

                // Approver controls
                if (isQueue) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          minimumSize: const Size(90, 36),
                        ),
                        onPressed: () => _showRemarksDialog(context, app.id, false, ref),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(90, 36),
                        ),
                        onPressed: () => _showRemarksDialog(context, app.id, true, ref),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'APPROVED';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'REJECTED';
        break;
      case 'pending_admin':
        color = Colors.blue;
        label = 'PENDING HR';
        break;
      default:
        color = Colors.orange;
        label = 'PENDING SUP';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Confirm approval/rejections with remarks
  void _showRemarksDialog(BuildContext context, String appId, bool approve, WidgetRef ref) {
    final remarksCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(approve ? 'Approve Leave Request' : 'Reject Leave Request'),
          content: TextField(
            controller: remarksCtrl,
            decoration: const InputDecoration(labelText: 'Remarks / Comments'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: approve ? Colors.green : Colors.redAccent,
              ),
              onPressed: () async {
                final success = await ref.read(leaveViewModelProvider.notifier).processApproval(
                      applicationId: appId,
                      approve: approve,
                      remarks: remarksCtrl.text.trim(),
                    );
                if (success && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}
