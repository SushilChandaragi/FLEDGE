import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/attendance_service.dart';
import '../services/local_db.dart';
import '../services/session_store.dart';
import '../services/sync_service.dart';

/// Root app state: session, event info, stats, and wiring of the services.
class AppState extends ChangeNotifier {
  AppState._(this.store, this.db, this.api) {
    attendance = AttendanceService(api, db, store);
    sync = SyncService(api, db, store, onAuthExpired: handleAuthExpired);
    sync.addListener(notifyListeners);
    api.offline.addListener(notifyListeners);
    session = store.session;
    event = store.event;
    stats = store.stats ?? const AttendanceStats();
  }

  static Future<AppState> create() async {
    final store = await SessionStore.open();
    final db = await LocalDb.open();
    final state = AppState._(store, db, ApiClient(store));
    if (state.session != null) await state.sync.start();
    return state;
  }

  final navigatorKey = GlobalKey<NavigatorState>();
  final SessionStore store;
  final LocalDb db;
  final ApiClient api;
  late final AttendanceService attendance;
  late final SyncService sync;

  Session? session;
  EventInfo? event;
  AttendanceStats stats = const AttendanceStats();
  String? loginNotice;

  bool get isOffline => api.offline.value;
  String get deviceId => store.deviceId;
  String get serverUrl => store.serverUrl;

  Future<void> login({
    required String operatorId,
    required String password,
    required String deviceId,
  }) async {
    await store.setDeviceId(deviceId.trim().toUpperCase());
    api.setBaseUrl(AppConfig.defaultApiBaseUrl);
    final result = await api.login(operatorId, password);
    await store.saveSession(result.session);
    session = result.session;
    loginNotice = null;
    notifyListeners();
    await sync.start();
    await refreshHome();
  }

  Future<void> logout({String? notice}) async {
    sync.stop();
    await store.clearSession();
    session = null;
    loginNotice = notice;
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    notifyListeners();
  }

  /// Token expired or revoked. Pending scans stay queued and are sent after the next sign-in.
  void handleAuthExpired() {
    if (session == null) return;
    logout(notice: 'Your session has expired. Please sign in again.');
  }

  Future<void> refreshHome() async {
    try {
      final results = await Future.wait([api.fetchEvent(), api.fetchStats()]);
      event = results[0] as EventInfo;
      stats = results[1] as AttendanceStats;
      await store.saveEvent(event!);
      await store.saveStats(stats);
    } on AuthExpiredException {
      handleAuthExpired();
      return;
    } on ApiException {
      // Keep cached values while offline.
    }
    notifyListeners();
  }

  @override
  void dispose() {
    sync.removeListener(notifyListeners);
    api.offline.removeListener(notifyListeners);
    sync.dispose();
    super.dispose();
  }
}
