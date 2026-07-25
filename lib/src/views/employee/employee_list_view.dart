import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../data/models/employee_model.dart';
import '../../core/theme/app_theme.dart';

class EmployeeListView extends ConsumerStatefulWidget {
  const EmployeeListView({super.key});

  @override
  ConsumerState<EmployeeListView> createState() => _EmployeeListViewState();
}

class _EmployeeListViewState extends ConsumerState<EmployeeListView> {
  final _searchController = TextEditingController();
  String _selectedDept = 'All';
  final List<String> _departments = ['All', 'Administration', 'Human Resources', 'Operations', 'Engineering'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    ref.read(employeeViewModelProvider.notifier).searchEmployees(
          _searchController.text.trim(),
          _selectedDept,
        );
  }

  // Open Dialog to add a new employee manually
  void _openAddEmployeeDialog() {
    final formKey = GlobalKey<FormState>();
    final empIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final desigCtrl = TextEditingController();
    String deptVal = 'Engineering';
    String shiftVal = 'Shift A (Morning)';
    final emailCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Employee Profile'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: empIdCtrl,
                    decoration: const InputDecoration(labelText: 'Employee ID (e.g. EMP-005)'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: desigCtrl,
                    decoration: const InputDecoration(labelText: 'Designation'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: deptVal,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: _departments
                        .where((d) => d != 'All')
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) deptVal = v;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: shiftVal,
                    decoration: const InputDecoration(labelText: 'Default Shift'),
                    items: const [
                      DropdownMenuItem(value: 'Shift A (Morning)', child: Text('Shift A (Morning)')),
                      DropdownMenuItem(value: 'Shift B (Evening)', child: Text('Shift B (Evening)')),
                      DropdownMenuItem(value: 'Shift C (Night)', child: Text('Shift C (Night)')),
                      DropdownMenuItem(value: 'Custom Duty', child: Text('Custom Duty')),
                    ],
                    onChanged: (v) {
                      if (v != null) shiftVal = v;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: mobileCtrl,
                    decoration: const InputDecoration(labelText: 'Mobile Number'),
                    keyboardType: TextInputType.phone,
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
                if (formKey.currentState!.validate()) {
                  final newEmp = Employee(
                    id: DateTime.now().millisecondsSinceEpoch.toString(), // temp mock id
                    employeeId: empIdCtrl.text.trim().toUpperCase(),
                    name: nameCtrl.text.trim(),
                    designation: desigCtrl.text.trim(),
                    departmentName: deptVal,
                    shiftName: shiftVal,
                    email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    mobile: mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
                    role: 'employee',
                    status: 'active',
                  );

                  final success = await ref.read(employeeViewModelProvider.notifier).addEmployee(newEmp);
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Employee profile created successfully.')),
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

  // Open CSV Import Dialog
  void _openCsvImportDialog() {
    final csvCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Import Employees (CSV)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste CSV text below in this format:\n'
                'Employee ID, Name, Designation, Department, Shift, Email\n'
                'EMP-101, Anil Verma, Clerk, Administration, Shift A (Morning), anil@dms.com',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: csvCtrl,
                maxLines: 8,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Paste CSV here...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
              onPressed: () async {
                final content = csvCtrl.text.trim();
                if (content.isNotEmpty) {
                  final count = await ref.read(employeeViewModelProvider.notifier).importEmployeesFromCsv(content);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bulk Import Complete. Added $count profiles.')),
                    );
                  }
                }
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeesVal = ref.watch(employeeViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Master Directory'),
        actions: [
          IconButton(
            tooltip: 'Bulk Import CSV',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _openCsvImportDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Card(
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search Name or Employee ID...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (_) => _triggerSearch(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDept,
                        decoration: InputDecoration(
                          labelText: 'Department',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedDept = v;
                            });
                            _triggerSearch();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Employees List
          Expanded(
            child: employeesVal.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No employees found matching filters.'));
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final emp = list[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                          child: Text(
                            emp.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'ID: ${emp.employeeId} | ${emp.designation} (${emp.departmentName})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: emp.status == 'active'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            emp.status.toUpperCase(),
                            style: TextStyle(
                              color: emp.status == 'active' ? Colors.green : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading employees: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddEmployeeDialog,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
