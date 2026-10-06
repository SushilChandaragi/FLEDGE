import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'local_db.dart';
import 'session_store.dart';

/// Keeps the phone and the server in step:
///  - replays scans that were saved while offline (duplicate-safe on the server)
///  - downloads the read-only participant snapshot used for offline lookups
class SyncService extends ChangeNotifier {
  SyncService(this._api, this._db, this._store, {required this.onAuthExpired});

  final ApiClient _api;
  final LocalDb _db;
  final SessionStore _store;
  final void Function() onAuthExpired;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _flushing = false;
  bool _refreshingSnapshot = false;
  bool _active = false;

  int pendingCount = 0;
  int snapshotCount = 0;
  DateTime? lastSnapshotAt;
  int rejectedCount = 0;
  bool get isSyncing => _flushing || _refreshingSnapshot;

  Future<void> start() async {
    if (_active) return;
    _active = true;
    await _reloadCounts();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) syncNow();
    });
    _timer = Timer.periodic(AppConfig.syncInterval, (_) => _tick());
    unawaited(syncNow());
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _connSub?.cancel();
    _timer = null;
    _connSub = null;
  }

  Future<void> _tick() async {
    await flushPending();
    final last = lastSnapshotAt;
    if (last == null || DateTime.now().difference(last) > AppConfig.snapshotRefreshInterval) {
      await refreshSnapshot();
    }
  }

  Future<void> syncNow() async {
    await flushPending();
    await refreshSnapshot();
  }

  Future<void> refreshCounts() => _reloadCounts();

  Future<void> _reloadCounts() async {
    pendingCount = await _db.pendingCount();
    snapshotCount = await _db.participantCount();
    lastSnapshotAt = _store.lastSnapshotAt;
    notifyListeners();
  }

  Future<void> flushPending() async {
    if (_flushing) return;
    _flushing = true;
    notifyListeners();
    try {
      final items = await _db.pendingScans();
      for (final item in items) {
        try {
          final res = await _api.markAttendance(srn: item.srn, deviceId: item.deviceId, scannedAt: item.scannedAt);
          switch (res.status) {
            case 'attendance_marked':
            case 'already_attended':
              // Either way the server now holds exactly one record for this SRN.
              final existing = await _db.attended(item.srn);
              if (existing != null) {
                await _db.upsertAttended(AttendedEntry(
                  srn: existing.srn,
                  name: existing.name,
                  time: DateTime.tryParse(res.json['attendanceTime'] as String? ?? '') ?? existing.time,
                  registrationStatus: res.json['registrationStatus'] as String? ?? existing.registrationStatus,
                  synced: true,
                ));
              }
              await _db.removePending(item.id);
            case 'not_registered':
            case 'invalid_srn':
            case 'validation_error':
              // The server does not accept this one; keep it from blocking the queue.
              rejectedCount++;
              await _db.removeAttended(item.srn);
              await _db.removePending(item.id);
            default:
              // event_not_found or unknown: leave it queued and try again later.
              break;
          }
        } on ApiException {
          break; // offline or server trouble: keep the rest queued
        }
      }
    } on AuthExpiredException {
      onAuthExpired();
    } finally {
      _flushing = false;
      await _reloadCounts();
    }
  }

  Future<void> refreshSnapshot() async {
    if (_refreshingSnapshot) return;
    _refreshingSnapshot = true;
    notifyListeners();
    try {
      var updatedSince = _store.snapshotUpdatedSince;
      var afterId = _store.snapshotAfterId;
      while (true) {
        final page = await _api.fetchSnapshotPage(updatedSince: updatedSince, afterId: afterId);
        final rows = (page['participants'] as List).cast<Map<String, dynamic>>();
        if (rows.isNotEmpty) await _db.upsertParticipants(rows);
        final next = page['next'] as Map<String, dynamic>?;
        if (next != null) {
          updatedSince = next['updatedSince'] as String;
          afterId = next['afterId'] as String;
          await _store.saveSnapshotCursor(updatedSince: updatedSince, afterId: afterId);
        } else {
          await _store.saveSnapshotCursor();
        }
        if (page['hasMore'] != true) break;
      }
    } on AuthExpiredException {
      onAuthExpired();
    } on ApiException {
      // Offline: the existing snapshot stays usable.
    } finally {
      _refreshingSnapshot = false;
      await _reloadCounts();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
