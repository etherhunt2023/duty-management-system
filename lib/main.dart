import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/app.dart';
import 'src/core/services/supabase_service.dart';
import 'src/core/services/local_db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local SQLite Database for Offline support
  final localDb = LocalDbService();
  await localDb.initDatabase();
  
  bool isSupabaseInitialized = false;
  try {
    // Read from environment variables, or fallback to default environment variables if passed at build-time
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://ceajytunbnykspknwyir.supabase.co',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_Bl19ZqeFaKjrtuD8EwmbcQ_FnuyCnyd',
    );
    
    if (supabaseUrl != 'https://placeholder-url.supabase.co' && supabaseAnonKey != 'placeholder-anon-key') {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      isSupabaseInitialized = true;
    }
  } catch (e) {
    debugPrint('Supabase initialization error: $e. Falling back to offline-only simulation.');
  }

  runApp(
    ProviderScope(
      overrides: [
        supabaseInitializedProvider.overrideWithValue(isSupabaseInitialized),
      ],
      child: const DutyManagementApp(),
    ),
  );
}
