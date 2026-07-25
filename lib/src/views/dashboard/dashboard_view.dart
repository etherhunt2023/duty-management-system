import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/sidebar_navigation.dart';

// Placeholder views for sub-sections
import '../attendance/attendance_list_view.dart';
import '../leave/leave_list_view.dart';
import '../employee/employee_list_view.dart';
import '../reports/report_center_view.dart';
import '../admin/admin_panel_view.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  int _selectedIndex = 0;

  // Render correct sub-page based on navigation selection and user role
  Widget _getBodyWidget(String role) {
    switch (_selectedIndex) {
      case 0:
        return const DashboardHomeView();
      case 1:
        return const AttendanceListView();
      case 2:
        return const LeaveListView();
      case 3:
        if (role == 'super_admin' || role == 'hr' || role == 'supervisor') {
          return const EmployeeListView();
        }
        return const ReportCenterView();
      case 4:
        if (role == 'super_admin' || role == 'hr' || role == 'supervisor') {
          return const ReportCenterView();
        }
        return const Scaffold(body: Center(child: Text('Not Found')));
      case 5:
        if (role == 'super_admin') {
          return const AdminPanelView();
        }
        return const Scaffold(body: Center(child: Text('Not Found')));
      default:
        return const DashboardHomeView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionVal = ref.watch(authViewModelProvider);
    final user = sessionVal.value;
    final role = user?.role ?? 'employee';

    return ResponsiveLayout(
      mobileBody: Scaffold(
        appBar: AppBar(
          title: const Text('Duty Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
            ),
          ],
        ),
        body: _getBodyWidget(role),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex > 2 ? 0 : _selectedIndex, // simplified index mapping for mobile
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Attendance'),
            BottomNavigationBarItem(icon: Icon(Icons.time_to_leave), label: 'Leaves'),
          ],
        ),
      ),
      tabletBody: Scaffold(
        body: Row(
          children: [
            SidebarNavigation(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _getBodyWidget(role)),
          ],
        ),
      ),
      desktopBody: Scaffold(
        body: Row(
          children: [
            SidebarNavigation(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _getBodyWidget(role)),
          ],
        ),
      ),
    );
  }
}

// Inner view containing the actual dashboard widgets
class DashboardHomeView extends ConsumerWidget {
  const DashboardHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsVal = ref.watch(dashboardViewModelProvider);

    return Scaffold(
      body: statsVal.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.read(dashboardViewModelProvider.notifier).loadStats(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header welcome
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HRMS Statistics',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                        ),
                        Text(
                          'Today: ${DateTime.now().toIso8601String().split('T').first}',
                          style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(110, 40),
                        backgroundColor: AppTheme.primaryBlue,
                      ),
                      onPressed: () => ref.read(dashboardViewModelProvider.notifier).loadStats(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // KPI grid cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 800 ? 4 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: [
                        _buildKpiCard(
                          context,
                          'Present Rate',
                          '${stats.presentToday}/${stats.totalEmployees}',
                          '${stats.monthlyAttendanceRate}% Attendance',
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                        _buildKpiCard(
                          context,
                          "Today's OT Hours",
                          stats.todayOtHours,
                          'Cumulative excess duty',
                          Icons.timer_outlined,
                          Colors.orange,
                        ),
                        _buildKpiCard(
                          context,
                          'CO Generated Today',
                          '${stats.todayCoEarned} CO',
                          'Converted from Overtime',
                          Icons.monetization_on_outlined,
                          Colors.blue,
                        ),
                        _buildKpiCard(
                          context,
                          'Pending Leaves',
                          '${stats.pendingLeaves} requests',
                          'Awaiting approval',
                          Icons.hourglass_empty,
                          Colors.purple,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Split sections for Attendance graph & upcoming holidays
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column - Weekly Attendance Graph
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weekly Attendance Trend (%)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 200,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: stats.monthlyChartData.map((d) {
                                    final rate = d['rate'] as double;
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10)),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: 32,
                                          height: (rate - 50) * 4, // scaled visual height
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(d['day'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right Column - Upcoming holidays
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Upcoming Holidays',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: stats.upcomingHolidays.length,
                                separatorBuilder: (context, idx) => const Divider(height: 12),
                                itemBuilder: (context, index) {
                                  final hol = stats.upcomingHolidays[index];
                                  final type = hol['type']?.toString().toUpperCase() ?? 'HOLIDAY';
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(hol['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(hol['date'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: type == 'NATIONAL'
                                              ? Colors.red.withOpacity(0.1)
                                              : Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            color: type == 'NATIONAL' ? Colors.red : Colors.blue,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading dashboard: $err')),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
