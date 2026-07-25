class Employee {
  final String id;
  final String employeeId;
  final String name;
  final String designation;
  final String departmentName;
  final String shiftName;
  final String? mobile;
  final String? email;
  final String role;
  final String status;

  Employee({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.designation,
    required this.departmentName,
    required this.shiftName,
    this.mobile,
    this.email,
    required this.role,
    required this.status,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      name: json['name'] ?? '',
      designation: json['designation'] ?? '',
      departmentName: json['departments']?['name'] ?? json['department_name'] ?? 'General',
      shiftName: json['shifts']?['name'] ?? json['shift_name'] ?? 'Shift A',
      mobile: json['mobile'],
      email: json['email'],
      role: json['role'] ?? 'employee',
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'name': name,
    'designation': designation,
    'department_name': departmentName,
    'shift_name': shiftName,
    'mobile': mobile,
    'email': email,
    'role': role,
    'status': status,
  };
}
