class LeaveApplication {
  final String id;
  final String employeeId;
  final String employeeName;
  final String leaveTypeCode;
  final String fromDate;
  final String toDate;
  final String reason;
  final String? attachmentUrl;
  final String? medicalCertificateUrl;
  final String status; // 'pending_supervisor', 'pending_admin', 'approved', 'rejected'
  final String? supervisorRemarks;
  final String? adminRemarks;

  LeaveApplication({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveTypeCode,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.attachmentUrl,
    this.medicalCertificateUrl,
    required this.status,
    this.supervisorRemarks,
    this.adminRemarks,
  });

  int get durationDays {
    final from = DateTime.parse(fromDate);
    final to = DateTime.parse(toDate);
    return to.difference(from).inDays + 1;
  }

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      employeeName: json['profiles']?['name'] ?? json['employee_name'] ?? 'Staff',
      leaveTypeCode: json['leave_types']?['code'] ?? json['leave_type_code'] ?? 'CL',
      fromDate: json['from_date'] ?? '',
      toDate: json['to_date'] ?? '',
      reason: json['reason'] ?? '',
      attachmentUrl: json['attachment_url'],
      medicalCertificateUrl: json['medical_certificate_url'],
      status: json['status'] ?? 'pending_supervisor',
      supervisorRemarks: json['supervisor_remarks'],
      adminRemarks: json['admin_remarks'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'leave_type_code': leaveTypeCode,
    'from_date': fromDate,
    'to_date': toDate,
    'reason': reason,
    'attachment_url': attachmentUrl,
    'medical_certificate_url': medicalCertificateUrl,
    'status': status,
    'supervisor_remarks': supervisorRemarks,
    'admin_remarks': adminRemarks,
  };
}

class LeaveBalance {
  final String leaveTypeCode;
  final String leaveTypeName;
  final double openingBalance;
  final double earned;
  final double used;
  final double remaining;

  LeaveBalance({
    required this.leaveTypeCode,
    required this.leaveTypeName,
    required this.openingBalance,
    required this.earned,
    required this.used,
    required this.remaining,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      leaveTypeCode: json['leave_types']?['code'] ?? json['leave_type_code'] ?? 'CL',
      leaveTypeName: json['leave_types']?['name'] ?? json['leave_type_name'] ?? 'Casual Leave',
      openingBalance: (json['opening_balance'] as num? ?? 0.0).toDouble(),
      earned: (json['earned'] as num? ?? 0.0).toDouble(),
      used: (json['used'] as num? ?? 0.0).toDouble(),
      remaining: (json['remaining'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'leave_type_code': leaveTypeCode,
    'leave_type_name': leaveTypeName,
    'opening_balance': openingBalance,
    'earned': earned,
    'used': used,
    'remaining': remaining,
  };
}
