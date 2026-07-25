import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/supabase_service.dart';

// View state for authentication
class UserSession {
  final String email;
  final String name;
  final String role; // 'super_admin', 'hr', 'supervisor', 'employee', 'viewer'
  final String employeeId;

  UserSession({
    required this.email,
    required this.name,
    required this.role,
    required this.employeeId,
  });
}

class AuthViewModel extends StateNotifier<AsyncValue<UserSession?>> {
  final SupabaseService _supabaseService;

  AuthViewModel(this._supabaseService) : super(const AsyncValue.data(null)) {
    _initSession();
  }

  void _initSession() {
    if (_supabaseService.isOnline) {
      // Listen to Supabase Auth State changes
      final client = Supabase.instance.client;
      client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null) {
          try {
            state = const AsyncValue.loading();
            final profile = await _fetchProfile(session.user.id);
            if (profile != null) {
              state = AsyncValue.data(
                UserSession(
                  email: session.user.email ?? '',
                  name: profile['name'] ?? 'Employee',
                  role: profile['role'] ?? 'employee',
                  employeeId: profile['employee_id'] ?? '',
                ),
              );
            }
          } catch (e) {
            state = AsyncValue.error(e, StackTrace.current);
          }
        } else {
          state = const AsyncValue.data(null);
        }
      });
    }
  }

  // Fetch HRMS profile details from Supabase using auth user ID
  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    try {
      final records = await _supabaseService.select(
        table: 'profiles',
        match: {'id': userId},
      );
      if (records.isNotEmpty) {
        return records.first;
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    return null;
  }

  // Sign In implementation
  Future<bool> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      if (!_supabaseService.isOnline) {
        // Mock session login for offline demo
        if ((email == 'admin@dms.com' || email == 'hr@dms.com' || email == 'supervisor@dms.com' || email == 'employee@dms.com') && password == 'password') {
          String role = 'employee';
          String name = 'Staff Member';
          String empId = 'EMP-004';
          
          if (email == 'admin@dms.com') {
            role = 'super_admin';
            name = 'Mohit Kumar (Admin)';
            empId = 'EMP-001';
          } else if (email == 'hr@dms.com') {
            role = 'hr';
            name = 'Preeti Sen (HR)';
            empId = 'EMP-002';
          } else if (email == 'supervisor@dms.com') {
            role = 'supervisor';
            name = 'Rajesh Sharma (Sup)';
            empId = 'EMP-003';
          }

          state = AsyncValue.data(
            UserSession(
              email: email,
              name: name,
              role: role,
              employeeId: empId,
            ),
          );
          return true;
        } else {
          throw Exception('Incorrect credentials for local offline mode. Use admin@dms.com / password.');
        }
      }

      final response = await _supabaseService.signIn(email, password);
      return response != null;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  // Sign Out implementation
  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _supabaseService.signOut();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Provider for Auth View Model
final authViewModelProvider = StateNotifierProvider<AuthViewModel, AsyncValue<UserSession?>>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthViewModel(supabaseService);
});
