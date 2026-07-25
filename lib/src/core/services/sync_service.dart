import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_service.dart';
import 'local_db_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SyncService(supabaseService, LocalDbService());
});

class SyncService {
  final SupabaseService _supabaseService;
  final LocalDbService _localDb;
  bool _isSyncing = false;
  Timer? _timer;

  SyncService(this._supabaseService, this._localDb);

  // Start periodic synchronization checks (every 30 seconds)
  void startAutoSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      syncQueue();
    });
    // Run an initial sync immediately
    syncQueue();
  }

  // Stop periodic synchronization checks
  void stopAutoSync() {
    _timer?.cancel();
  }

  // Process the offline sync queue
  Future<void> syncQueue() async {
    if (_isSyncing) return;
    if (!_supabaseService.isOnline) {
      debugPrint('Sync bypassed: Supabase is offline.');
      return;
    }

    _isSyncing = true;
    try {
      final pendingItems = await _localDb.getPendingSyncs();
      if (pendingItems.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('Sync Service: Processing ${pendingItems.length} queued items.');

      for (final item in pendingItems) {
        final int id = item['id'];
        final String action = item['action'];
        final String table = item['table_name'];
        final Map<String, dynamic> payload = jsonDecode(item['payload']);

        try {
          if (action == 'INSERT') {
            await _supabaseService.insert(table: table, values: payload);
          } else if (action == 'UPDATE') {
            // Assumes payload has an 'id' and we match on it
            final matchId = payload['id'];
            if (matchId != null) {
              await _supabaseService.update(
                table: table,
                values: payload,
                match: {'id': matchId},
              );
            }
          }
          
          // Successfully synced, remove from queue
          await _localDb.removeSyncItem(id);
          debugPrint('Sync Service: Synced item $id successfully.');
        } catch (e) {
          // If we encounter a database error or network drop, stop the loop and retry later
          debugPrint('Sync Service: Failed to sync item $id: $e. Will retry later.');
          break;
        }
      }
    } catch (e) {
      debugPrint('Sync Service error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
