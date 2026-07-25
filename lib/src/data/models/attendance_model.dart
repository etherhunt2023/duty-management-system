import '../../core/utils/duty_calculator.dart';

class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final String date;
  final String shiftName;
  final String? checkIn;
  final String? checkOut;
  final int dutyMinutes;
  final int otMinutes;
  final int remainingOtMinutes;
  final int coGenerated;
  final String? remarks;
  final bool isSynced;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.shiftName,
    this.checkIn,
    this.checkOut,
    required this.dutyMinutes,
    required this.otMinutes,
    required this.remainingOtMinutes,
    required this.coGenerated,
    this.remarks,
    this.isSynced = true,
  });

  String get dutyHoursString => DutyCalculator.minutesToTimeString(dutyMinutes);
  String get otHoursString => DutyCalculator.minutesToTimeString(otMinutes);
  String get remainingOtHoursString => DutyCalculator.minutesToTimeString(remainingOtMinutes);

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      employeeName: json['profiles']?['name'] ?? json['employee_name'] ?? 'Staff',
      date: json['date'] ?? '',
      shiftName: json['shifts']?['name'] ?? json['shift_name'] ?? 'Shift A',
      checkIn: json['check_in'],
      checkOut: json['check_out'],
      dutyMinutes: json['duty_minutes'] ?? 0,
      otMinutes: json['ot_minutes'] ?? 0,
      remainingOtMinutes: json['remaining_ot_minutes'] ?? 0,
      coGenerated: json['co_generated'] ?? 0,
      remarks: json['remarks'],
      isSynced: json['is_synced'] == null || json['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'date': date,
    'shift_name': shiftName,
    'check_in': checkIn,
    'check_out': checkOut,
    'duty_minutes': dutyMinutes,
    'ot_minutes': otMinutes,
    'remaining_ot_minutes': remainingOtMinutes,
    'co_generated': coGenerated,
    'remarks': remarks,
    'is_synced': isSynced ? 1 : 0,
  };
}
