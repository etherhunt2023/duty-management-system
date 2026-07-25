import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

// Provider to check if Supabase is initialized
final supabaseInitializedProvider = Provider<bool>((ref) => false);

// Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final isInitialized = ref.watch(supabaseInitializedProvider);
  if (isInitialized) {
    return Supabase.instance.client;
  }
  return null;
});

class SupabaseService {
  final SupabaseClient? _client;
  final bool _isInitialized;

  SupabaseService(this._client, this._isInitialized);

  bool get isOnline => _isInitialized && _client != null;

  // Authentication: Sign in with email and password
  Future<AuthResponse?> signIn(String email, String password) async {
    if (!isOnline) {
      // Mock Authentication for local development/simulation
      if (email == 'admin@dms.com' && password == 'password') {
        debugPrint('Signed in with Mock Admin account.');
        return null; // Return null but handled in viewmodel as mocked session
      }
      throw Exception('Database offline and invalid mock credentials.');
    }
    return await _client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Authentication: Sign Out
  Future<void> signOut() async {
    if (isOnline) {
      await _client!.auth.signOut();
    }
  }

  // Database: Fetch records
  Future<List<Map<String, dynamic>>> select({
    required String table,
    String columns = '*',
    Map<String, dynamic>? match,
    String? orderCol,
    bool ascending = true,
  }) async {
    if (!isOnline) {
      return []; // In offline simulation, local_db_service handles database queries
    }
    
    var selectQuery = _client!.from(table).select(columns);
    if (match != null) {
      selectQuery = selectQuery.match(Map<String, Object>.from(match));
    }
    if (orderCol != null) {
      final response = await selectQuery.order(orderCol, ascending: ascending);
      return List<Map<String, dynamic>>.from(response);
    }
    
    final response = await selectQuery;
    return List<Map<String, dynamic>>.from(response);
  }

  // Database: Insert record
  Future<Map<String, dynamic>?> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    if (!isOnline) {
      return null;
    }
    final response = await _client!.from(table).insert(values).select().single();
    return response;
  }

  // Database: Update record
  Future<List<Map<String, dynamic>>> update({
    required String table,
    required Map<String, dynamic> values,
    required Map<String, dynamic> match,
  }) async {
    if (!isOnline) {
      return [];
    }
    final response = await _client!.from(table).update(values).match(Map<String, Object>.from(match)).select();
    return List<Map<String, dynamic>>.from(response);
  }

  // Database: Delete record
  Future<void> delete({
    required String table,
    required Map<String, dynamic> match,
  }) async {
    if (isOnline) {
      await _client!.from(table).delete().match(Map<String, Object>.from(match));
    }
  }
}

// Supabase Service Provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final isInitialized = ref.watch(supabaseInitializedProvider);
  return SupabaseService(client, isInitialized);
});
