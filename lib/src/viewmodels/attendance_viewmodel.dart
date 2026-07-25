import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/attendance_model.dart';
import '../core/services/supabase_service.dart';
import '../core/services/local_db_service.dart';
import '../core/utils/duty_calculator.dart';
import 'package:uuid/uuid.dart';

class AttendanceViewModel extends StateNotifier<AsyncValue<List<Attendance>>> {
  final SupabaseService _supabaseService;
  final LocalDbService _localDb = LocalDbService();
  List<Attendance> _allAttendance = [];
  String _currentDateFilter = '';

  AttendanceViewModel(this._supabaseService) : super(const AsyncValue.loading()) {
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    loadAttendance(todayStr);
  }

  // Load attendance records for a specific date
  Future<void> loadAttendance(String dateStr) async {
    _currentDateFilter = dateStr;
    state = const AsyncValue.loading();
    try {
      if (!_supabaseService.isOnline) {
        // Query offline local SQLite cache
        final localData = await _localDb.query(
          'attendance',
          where: 'date = ?',
          whereArgs: [dateStr],
        );
        
        _allAttendance = localData.map((e) => Attendance.fromJson(e)).toList();
        
        // Seed mock attendance if cache is empty
        if (_allAttendance.isEmpty) {
          _allAttendance = _generateMockAttendance(dateStr);
          for (final att in _allAttendance) {
            await _localDb.insert('attendance', att.toJson());
          }
        }
        state = AsyncValue.data(_allAttendance);
        return;
      }

      // Query Supabase
      final response = await _supabaseService.select(
        table: 'attendance',
        columns: '*, profiles(name)',
        match: {'date': dateStr},
      );
      _allAttendance = response.map((e) => Attendance.fromJson(e)).toList();
      state = AsyncValue.data(_allAttendance);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Add or update an attendance record manually (with calculations)
  Future<bool> saveManualAttendance({
    required String employeeId,
    required String employeeName,
    required String date,
    required String shiftName,
    required String checkIn,
    required String checkOut,
    String? remarks,
  }) async {
    // 1. Calculate duty minutes and daily OT
    final dutyMinutes = DutyCalculator.calculateDutyMinutes(checkIn, checkOut);
    // Shift A normal cap is 440m. To make it general:
    final int normalDuty = shiftName.contains('Custom') ? 440 : 440; 
    final otMinutes = DutyCalculator.calculateDailyOvertime(dutyMinutes, normalDuty);

    // 2. Query previous remaining OT for calculations
    int previousAccumulatedOt = 0;
    try {
      if (_supabaseService.isOnline) {
        final profile = await _supabaseService.select(table: 'profiles', match: {'employee_id': employeeId});
        if (profile.isNotEmpty) {
          previousAccumulatedOt = profile.first['accumulated_ot_minutes'] ?? 0;
        }
      } else {
        final localProfile = await _localDb.query('employees', where: 'employee_id = ?', whereArgs: [employeeId]);
        if (localProfile.isNotEmpty) {
          previousAccumulatedOt = localProfile.first['accumulated_ot_minutes'] ?? 0;
        }
      }
    } catch (_) {}

    // Calculate CO and new remaining carry-forward balance
    final balanceResult = DutyCalculator.processAccumulatedOt(previousAccumulatedOt, otMinutes);
    final coGenerated = balanceResult['coGenerated'] ?? 0;
    final remainingOt = balanceResult['remainingOtMinutes'] ?? 0;

    final newRecord = Attendance(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      shiftName: shiftName,
      checkIn: checkIn,
      checkOut: checkOut,
      dutyMinutes: dutyMinutes,
      otMinutes: otMinutes,
      remainingOtMinutes: remainingOt,
      coGenerated: coGenerated,
      remarks: remarks ?? 'Manual Entry',
      isSynced: _supabaseService.isOnline,
    );

    try {
      if (!_supabaseService.isOnline) {
        // Save in local DB cache & queue for online syncing
        await _localDb.insert('attendance', newRecord.toJson());
        await _localDb.queueSync('INSERT', 'attendance', newRecord.toJson());
        
        // Update local profile accumulated balance
        await _localDb.insert('employees', {
          'employee_id': employeeId,
          'accumulated_ot_minutes': remainingOt,
        });

        _allAttendance.removeWhere((item) => item.employeeId == employeeId);
        _allAttendance.add(newRecord);
        state = AsyncValue.data(List.from(_allAttendance));
        return true;
      }

      // Online Supabase insert
      // Convert to Supabase schema layout: needs shift_id and employee UUID from profiles.
      // For demonstration, we directly write or use function endpoints.
      final employees = await _supabaseService.select(table: 'profiles', match: {'employee_id': employeeId});
      final shifts = await _supabaseService.select(table: 'shifts', match: {'name': shiftName});
      
      if (employees.isNotEmpty && shifts.isNotEmpty) {
        final profileId = employees.first['id'];
        final shiftId = shifts.first['id'];

        final supabasePayload = {
          'id': newRecord.id,
          'employee_id': profileId,
          'date': date,
          'shift_id': shiftId,
          // Format timestamps to full ISO8601 with date context
          'check_in': DateTime.parse('${date}T${checkIn}:00').toIso8601String(),
          'check_out': DateTime.parse('${date}T${checkOut}:00').toIso8601String(),
          'remarks': remarks,
        };

        await _supabaseService.insert(table: 'attendance', values: supabasePayload);
        // Reload list to get values after database trigger computes balances
        await loadAttendance(_currentDateFilter);
        return true;
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
    return false;
  }

  // Batch insert results from OCR scans
  Future<void> saveOcrScannedRecords(List<Attendance> records) async {
    for (final rec in records) {
      await saveManualAttendance(
        employeeId: rec.employeeId,
        employeeName: rec.employeeName,
        date: rec.date,
        shiftName: rec.shiftName,
        checkIn: rec.checkIn ?? '08:40',
        checkOut: rec.checkOut ?? '17:00',
        remarks: rec.remarks ?? 'Imported via OCR Scan',
      );
    }
  }

  List<Attendance> _generateMockAttendance(String dateStr) {
    return [
      Attendance(
        id: 'att-1',
        employeeId: 'EMP-001',
        employeeName: 'Mohit Kumar (Admin)',
        date: dateStr,
        shiftName: 'Shift A (Morning)',
        checkIn: '08:40',
        checkOut: '17:00',
        dutyMinutes: 500,
        otMinutes: 60,
        remainingOtMinutes: 60,
        coGenerated: 0,
        remarks: 'Ontime check-in',
      ),
      Attendance(
        id: 'att-2',
        employeeId: 'EMP-002',
        employeeName: 'Preeti Sen (HR)',
        date: dateStr,
        shiftName: 'Shift A (Morning)',
        checkIn: '08:40',
        checkOut: '16:00',
        dutyMinutes: 440,
        otMinutes: 0,
        remainingOtMinutes: 0,
        coGenerated: 0,
        remarks: 'Normal duty',
      ),
      Attendance(
        id: 'att-3',
        employeeId: 'EMP-003',
        employeeName: 'Rajesh Sharma',
        date: dateStr,
        shiftName: 'Shift B (Evening)',
        checkIn: '16:40',
        checkOut: '00:00',
        dutyMinutes: 440,
        otMinutes: 0,
        remainingOtMinutes: 0,
        coGenerated: 0,
        remarks: 'Normal Shift B',
      ),
    ];
  }
}

final attendanceViewModelProvider = StateNotifierProvider<AttendanceViewModel, AsyncValue<List<Attendance>>>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AttendanceViewModel(supabaseService);
});
