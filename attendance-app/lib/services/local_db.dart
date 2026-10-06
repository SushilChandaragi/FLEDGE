import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class PendingScan {
  PendingScan({required this.id, required this.srn, required this.scannedAt, required this.deviceId});
  final int id;
  final String srn;
  final DateTime scannedAt;
  final String deviceId;
}

class AttendedEntry {
  AttendedEntry({
    required this.srn,
    required this.name,
    required this.time,
    required this.registrationStatus,
    required this.synced,
  });
  final String srn;
  final String name;
  final DateTime time;
  final String registrationStatus;

  /// false = recorded on this phone only, waiting for the server.
  final bool synced;
}

/// Local SQLite: read-only participant snapshot, the pending scan queue, and a
/// cache of students this device already knows are marked present.
class LocalDb {
  LocalDb._(this._db);
  final Database _db;

  static Future<LocalDb> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'fledge_attendance.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE participants (srn TEXT PRIMARY KEY, name TEXT NOT NULL, branch TEXT)');
        await db.execute('''CREATE TABLE pending_scans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          srn TEXT NOT NULL UNIQUE,
          scanned_at TEXT NOT NULL,
          device_id TEXT NOT NULL)''');
        await db.execute('''CREATE TABLE attended (
          srn TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          time TEXT NOT NULL,
          registration_status TEXT NOT NULL DEFAULT '',
          synced INTEGER NOT NULL)''');
      },
    );
    return LocalDb._(db);
  }

  // --- participant snapshot ---------------------------------------------------

  Future<void> upsertParticipants(List<Map<String, dynamic>> rows) async {
    final batch = _db.batch();
    for (final r in rows) {
      batch.insert(
        'participants',
        {'srn': r['srn'], 'name': r['name'], 'branch': r['branch'] ?? ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<String?> participantName(String srn) async {
    final rows = await _db.query('participants', columns: ['name'], where: 'srn = ?', whereArgs: [srn], limit: 1);
    return rows.isEmpty ? null : rows.first['name'] as String;
  }

  Future<int> participantCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM participants')) ?? 0;

  // --- pending queue --------------------------------------------------------------

  Future<void> enqueueScan({required String srn, required DateTime scannedAt, required String deviceId}) =>
      _db.insert(
        'pending_scans',
        {'srn': srn, 'scanned_at': scannedAt.toUtc().toIso8601String(), 'device_id': deviceId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  Future<List<PendingScan>> pendingScans() async {
    final rows = await _db.query('pending_scans', orderBy: 'id ASC');
    return rows
        .map((r) => PendingScan(
              id: r['id'] as int,
              srn: r['srn'] as String,
              scannedAt: DateTime.parse(r['scanned_at'] as String),
              deviceId: r['device_id'] as String,
            ))
        .toList();
  }

  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM pending_scans')) ?? 0;

  Future<void> removePending(int id) => _db.delete('pending_scans', where: 'id = ?', whereArgs: [id]);

  // --- attended cache -------------------------------------------------------------

  Future<void> upsertAttended(AttendedEntry e) => _db.insert(
        'attended',
        {
          'srn': e.srn,
          'name': e.name,
          'time': e.time.toUtc().toIso8601String(),
          'registration_status': e.registrationStatus,
          'synced': e.synced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<AttendedEntry?> attended(String srn) async {
    final rows = await _db.query('attended', where: 'srn = ?', whereArgs: [srn], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return AttendedEntry(
      srn: r['srn'] as String,
      name: r['name'] as String,
      time: DateTime.parse(r['time'] as String),
      registrationStatus: r['registration_status'] as String,
      synced: (r['synced'] as int) == 1,
    );
  }

  Future<void> removeAttended(String srn) => _db.delete('attended', where: 'srn = ?', whereArgs: [srn]);
}
