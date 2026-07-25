import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/leave_model.dart';
import '../core/services/supabase_service.dart';
import '../core/services/local_db_service.dart';
import 'auth_viewmodel.dart';
import 'package:uuid/uuid.dart';

class LeaveState {
  final List<LeaveBalance> balances;
  final List<LeaveApplication> myApplications;
  final List<LeaveApplication> approvalsQueue;

  LeaveState({
    required this.balances,
    required this.myApplications,
    required this.approvalsQueue,
  });
}

class LeaveViewModel extends StateNotifier<AsyncValue<LeaveState>> {
  final SupabaseService _supabaseService;
  final LocalDbService _localDb = LocalDbService();
  final String _currentEmployeeId;
  final String _currentRole;

  LeaveViewModel(this._supabaseService, this._currentEmployeeId, this._currentRole)
      : super(const AsyncValue.loading()) {
    loadLeaveData();
  }

  // Load balances and applications
  Future<void> loadLeaveData() async {
    state = const AsyncValue.loading();
    try {
      if (!_supabaseService.isOnline) {
        // Generate simulated local data
        await Future.delayed(const Duration(milliseconds: 500));
        state = AsyncValue.data(
          LeaveState(
            balances: _generateMockBalances(),
            myApplications: _generateMockMyApplications(),
            approvalsQueue: _currentRole == 'employee' ? [] : _generateMockQueue(),
          ),
        );
        return;
      }

      // 1. Fetch balances
      final balancesResp = await _supabaseService.select(
        table: 'leave_balances',
        columns: '*, leave_types(code, name)',
        match: {'employee_id': _currentEmployeeId},
      );
      final balances = balancesResp.map((b) => LeaveBalance.fromJson(b)).toList();

      // 2. Fetch my applications
      final myAppsResp = await _supabaseService.select(
        table: 'leave_applications',
        columns: '*, profiles(name), leave_types(code)',
        match: {'employee_id': _currentEmployeeId},
      );
      final myApps = myAppsResp.map((a) => LeaveApplication.fromJson(a)).toList();

      // 3. Fetch approvals queue if HR/Supervisor/Admin
      List<LeaveApplication> queue = [];
      if (_currentRole != 'employee') {
        final matchFilter = <String, dynamic>{};
        if (_currentRole == 'supervisor') {
          matchFilter['status'] = 'pending_supervisor';
        } else if (_currentRole == 'hr' || _currentRole == 'super_admin') {
          matchFilter['status'] = 'pending_admin';
        }

        final queueResp = await _supabaseService.select(
          table: 'leave_applications',
          columns: '*, profiles(name), leave_types(code)',
          match: matchFilter,
        );
        queue = queueResp.map((a) => LeaveApplication.fromJson(a)).toList();
      }

      state = AsyncValue.data(
        LeaveState(
          balances: balances,
          myApplications: myApps,
          approvalsQueue: queue,
        ),
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Submit a leave application
  Future<bool> applyLeave({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
    String? attachmentUrl,
    String? medicalCertificateUrl,
  }) async {
    try {
      final newApp = LeaveApplication(
        id: const Uuid().v4(),
        employeeId: _currentEmployeeId,
        employeeName: 'Self',
        leaveTypeCode: leaveTypeCode,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
        status: 'pending_supervisor',
        attachmentUrl: attachmentUrl,
        medicalCertificateUrl: medicalCertificateUrl,
      );

      if (!_supabaseService.isOnline) {
        // Save in local storage & queue sync
        final currentState = state.value;
        if (currentState != null) {
          currentState.myApplications.add(newApp);
          state = AsyncValue.data(currentState);
        }
        return true;
      }

      // Online Supabase insert
      final leaveTypes = await _supabaseService.select(table: 'leave_types', match: {'code': leaveTypeCode});
      if (leaveTypes.isNotEmpty) {
        final leaveTypeId = leaveTypes.first['id'];
        final payload = {
          'id': newApp.id,
          'employee_id': _currentEmployeeId,
          'leave_type_id': leaveTypeId,
          'from_date': fromDate,
          'to_date': toDate,
          'reason': reason,
          'attachment_url': attachmentUrl,
          'medical_certificate_url': medicalCertificateUrl,
          'status': 'pending_supervisor',
        };

        await _supabaseService.insert(table: 'leave_applications', values: payload);
        await loadLeaveData();
        return true;
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
    return false;
  }

  // Approve/Reject workflow actions
  Future<bool> processApproval({
    required String applicationId,
    required bool approve,
    String? remarks,
  }) async {
    try {
      if (!_supabaseService.isOnline) {
        final currentState = state.value;
        if (currentState != null) {
          currentState.approvalsQueue.removeWhere((a) => a.id == applicationId);
          state = AsyncValue.data(currentState);
        }
        return true;
      }

      String nextStatus;
      final updates = <String, dynamic>{};

      if (_currentRole == 'supervisor') {
        nextStatus = approve ? 'pending_admin' : 'rejected';
        updates['status'] = nextStatus;
        updates['supervisor_id'] = _currentEmployeeId;
        updates['supervisor_remarks'] = remarks;
        updates['supervisor_approved_at'] = DateTime.now().toIso8601String();
      } else {
        nextStatus = approve ? 'approved' : 'rejected';
        updates['status'] = nextStatus;
        updates['admin_id'] = _currentEmployeeId;
        updates['admin_remarks'] = remarks;
        updates['admin_approved_at'] = DateTime.now().toIso8601String();
      }

      await _supabaseService.update(
        table: 'leave_applications',
        values: updates,
        match: {'id': applicationId},
      );

      await loadLeaveData();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
    return false;
  }

  List<LeaveBalance> _generateMockBalances() {
    return [
      LeaveBalance(leaveTypeCode: 'CL', leaveTypeName: 'Casual Leave', openingBalance: 8, earned: 0, used: 2, remaining: 6),
      LeaveBalance(leaveTypeCode: 'EL', leaveTypeName: 'Earned Leave', openingBalance: 15, earned: 5, used: 0, remaining: 20),
      LeaveBalance(leaveTypeCode: 'CO', leaveTypeName: 'Compensatory Off', openingBalance: 0, earned: 3, used: 1, remaining: 2),
      LeaveBalance(leaveTypeCode: 'HPL', leaveTypeName: 'Half Pay Leave', openingBalance: 10, earned: 0, used: 0, remaining: 10),
    ];
  }

  List<LeaveApplication> _generateMockMyApplications() {
    return [
      LeaveApplication(
        id: 'la-1',
        employeeId: _currentEmployeeId,
        employeeName: 'Self',
        leaveTypeCode: 'CL',
        fromDate: '2026-07-10',
        toDate: '2026-07-11',
        reason: 'Personal urgent work',
        status: 'approved',
        supervisorRemarks: 'Approved',
        adminRemarks: 'Approved',
      ),
      LeaveApplication(
        id: 'la-2',
        employeeId: _currentEmployeeId,
        employeeName: 'Self',
        leaveTypeCode: 'CO',
        fromDate: '2026-07-28',
        toDate: '2026-07-28',
        reason: 'Availing CO against Shift C OT',
        status: 'pending_supervisor',
      ),
    ];
  }

  List<LeaveApplication> _generateMockQueue() {
    return [
      LeaveApplication(
        id: 'la-3',
        employeeId: 'EMP-004',
        employeeName: 'Sanjay Singh',
        leaveTypeCode: 'EL',
        fromDate: '2026-08-01',
        toDate: '2026-08-05',
        reason: 'Going to hometown',
        status: _currentRole == 'supervisor' ? 'pending_supervisor' : 'pending_admin',
      ),
    ];
  }
}

final leaveViewModelProvider = StateNotifierProvider<LeaveViewModel, AsyncValue<LeaveState>>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final session = ref.watch(authViewModelProvider).value;
  return LeaveViewModel(
    supabaseService,
    session?.employeeId ?? '',
    session?.role ?? 'employee',
  );
});
