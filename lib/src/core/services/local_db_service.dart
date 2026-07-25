import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:path/path.dart' as path_helper;

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  sqlite.Database? _sqliteDb;
  // In-memory cache for Web platform fallback
  final Map<String, List<Map<String, dynamic>>> _webDb = {};

  Future<void> initDatabase() async {
    if (kIsWeb) {
      debugPrint('Running on Web. SQLite initialized in simulation mode.');
      _webDb['employees'] = [];
      _webDb['attendance'] = [];
      _webDb['sync_queue'] = [];
      return;
    }

    try {
      final databasesPath = await sqlite.getDatabasesPath();
      final dbPath = path_helper.join(databasesPath, 'duty_management.db');

      _sqliteDb = await sqlite.openDatabase(
        dbPath,
        version: 1,
        onCreate: (sqlite.Database db, int version) async {
          // Create local employees cache
          await db.execute('''
            CREATE TABLE employees (
              id TEXT PRIMARY KEY,
              employee_id TEXT NOT NULL,
              name TEXT NOT NULL,
              designation TEXT NOT NULL,
              department_name TEXT NOT NULL,
              shift_name TEXT NOT NULL,
              mobile TEXT,
              email TEXT,
              role TEXT NOT NULL,
              status TEXT NOT NULL
            )
          ''');

          // Create local attendance cache
          await db.execute('''
            CREATE TABLE attendance (
              id TEXT PRIMARY KEY,
              employee_id TEXT NOT NULL,
              date TEXT NOT NULL,
              shift_name TEXT NOT NULL,
              check_in TEXT,
              check_out TEXT,
              duty_minutes INTEGER NOT NULL,
              ot_minutes INTEGER NOT NULL,
              remaining_ot_minutes INTEGER NOT NULL,
              co_generated INTEGER NOT NULL,
              remarks TEXT,
              is_synced INTEGER DEFAULT 1
            )
          ''');

          // Create offline sync queue
          await db.execute('''
            CREATE TABLE sync_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              action TEXT NOT NULL,
              table_name TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          
          debugPrint('Local SQLite tables created successfully.');
        },
      );
    } catch (e) {
      debugPrint('Error initializing SQLite: $e. Falling back to Web simulation mode.');
      _sqliteDb = null;
    }
  }

  // General Insert
  Future<void> insert(String table, Map<String, dynamic> values) async {
    if (kIsWeb || _sqliteDb == null) {
      _webDb[table] ??= [];
      // Remove duplicates on primary key for updates during inserts
      _webDb[table]!.removeWhere((item) => item['id'] == values['id']);
      _webDb[table]!.add(values);
      return;
    }
    await _sqliteDb!.insert(
      table,
      values,
      conflictAlgorithm: sqlite.ConflictAlgorithm.replace,
    );
  }

  // General Query
  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    if (kIsWeb || _sqliteDb == null) {
      final list = _webDb[table] ?? [];
      if (where == null) return list;
      
      // Simple mock filtering for demo/offline logic
      return list;
    }
    return await _sqliteDb!.query(table, where: where, whereArgs: whereArgs);
  }

  // Delete
  Future<void> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    if (kIsWeb || _sqliteDb == null) {
      _webDb[table]?.removeWhere((item) {
        if (where == 'id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
          return item['id'] == whereArgs[0];
        }
        return false;
      });
      return;
    }
    await _sqliteDb!.delete(table, where: where, whereArgs: whereArgs);
  }

  // Queue an action to sync back to Supabase
  Future<void> queueSync(String action, String tableName, Map<String, dynamic> payload) async {
    final payloadString = jsonEncode(payload);
    final row = {
      'action': action,
      'table_name': tableName,
      'payload': payloadString,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (kIsWeb || _sqliteDb == null) {
      _webDb['sync_queue'] ??= [];
      final id = _webDb['sync_queue']!.length + 1;
      _webDb['sync_queue']!.add({'id': id, ...row});
      debugPrint('Sync queued (Web): $action on $tableName');
      return;
    }

    await _sqliteDb!.insert('sync_queue', row);
    debugPrint('Sync queued (SQLite): $action on $tableName');
  }

  // Fetch pending sync items
  Future<List<Map<String, dynamic>>> getPendingSyncs() async {
    if (kIsWeb || _sqliteDb == null) {
      return _webDb['sync_queue'] ?? [];
    }
    return await _sqliteDb!.query('sync_queue', orderBy: 'id ASC');
  }

  // Delete a synced item from queue
  Future<void> removeSyncItem(int queueId) async {
    if (kIsWeb || _sqliteDb == null) {
      _webDb['sync_queue']?.removeWhere((item) => item['id'] == queueId);
      return;
    }
    await _sqliteDb!.delete('sync_queue', where: 'id = ?', whereArgs: [queueId]);
  }
}
