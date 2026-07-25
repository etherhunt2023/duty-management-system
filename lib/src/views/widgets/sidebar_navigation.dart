import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../core/theme/app_theme.dart';

class SidebarNavigation extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionVal = ref.watch(authViewModelProvider);
    final user = sessionVal.value;
    final role = user?.role ?? 'employee';

    // Build navigation items based on role
    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Dashboard', 'icon': Icons.dashboard_outlined, 'selectedIcon': Icons.dashboard},
      {'title': 'Attendance', 'icon': Icons.calendar_today_outlined, 'selectedIcon': Icons.calendar_today},
      {'title': 'Leaves', 'icon': Icons.time_to_leave_outlined, 'selectedIcon': Icons.time_to_leave},
    ];

    if (role == 'super_admin' || role == 'hr' || role == 'supervisor') {
      menuItems.add({'title': 'Employees', 'icon': Icons.people_outline, 'selectedIcon': Icons.people});
    }

    menuItems.add({'title': 'Reports', 'icon': Icons.analytics_outlined, 'selectedIcon': Icons.analytics});

    if (role == 'super_admin') {
      menuItems.add({'title': 'Admin Control', 'icon': Icons.admin_panel_settings_outlined, 'selectedIcon': Icons.admin_panel_settings});
    }

    return Container(
      width: 260,
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          // Logo Section
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(Icons.alarm_on, color: AppTheme.primaryBlue, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Duty Management',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          color: AppTheme.primaryBlue,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // User Profile Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'E',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Employee Name',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          role.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation Menu List
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor: AppTheme.primaryBlue.withOpacity(0.08),
                    selectedColor: AppTheme.primaryBlue,
                    leading: Icon(isSelected ? item['selectedIcon'] : item['icon']),
                    title: Text(
                      item['title'],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () => onDestinationSelected(index),
                  ),
                );
              },
            ),
          ),

          // Sign Out Action
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Log Out',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () {
                ref.read(authViewModelProvider.notifier).logout();
              },
            ),
          ),
        ],
      ),
    );
  }
}
