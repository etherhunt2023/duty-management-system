import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/auth/login_view.dart';
import 'views/dashboard/dashboard_view.dart';

class DutyManagementApp extends ConsumerWidget {
  const DutyManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to authentication state to handle routing
    final authState = ref.watch(authViewModelProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Duty Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: authState.when(
        data: (session) {
          if (session != null) {
            return const DashboardView();
          } else {
            return const LoginView();
          }
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Text('An error occurred: $err'),
          ),
        ),
      ),
    );
  }
}

// Simple state provider for theme mode switching
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
