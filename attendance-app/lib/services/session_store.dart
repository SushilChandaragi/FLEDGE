import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/models.dart';

class Session {
  const Session({required this.token, required this.operatorId, required this.displayName});
  final String token;
  final String operatorId;
  final String displayName;
}

/// Small key/value store for the signed-in session and device settings.
class SessionStore {
  SessionStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<SessionStore> open() async => SessionStore(await SharedPreferences.getInstance());

  Session? get session {
    final token = _prefs.getString('token');
    final op = _prefs.getString('operatorId');
    if (token == null || op == null) return null;
    return Session(token: token, operatorId: op, displayName: _prefs.getString('displayName') ?? '');
  }

  Future<void> saveSession(Session s) async {
    await _prefs.setString('token', s.token);
    await _prefs.setString('operatorId', s.operatorId);
    await _prefs.setString('displayName', s.displayName);
  }

  Future<void> clearSession() async {
    await _prefs.remove('token');
    await _prefs.remove('displayName');
  }

  String get deviceId => _prefs.getString('deviceId') ?? '';
  Future<void> setDeviceId(String v) => _prefs.setString('deviceId', v);

  String get lastOperatorId => _prefs.getString('operatorId') ?? '';

  String get serverUrl {
    final saved = _prefs.getString('serverUrl');
    if (saved == null || saved.contains('10.0.2.2') || saved.contains('localhost') || saved.contains('loca.lt')) {
      return AppConfig.defaultApiBaseUrl;
    }
    return saved;
  }
  Future<void> setServerUrl(String v) => _prefs.setString('serverUrl', v);

  EventInfo? get event {
    final raw = _prefs.getString('event');
    if (raw == null) return null;
    try {
      return EventInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveEvent(EventInfo e) => _prefs.setString('event', jsonEncode(e.toJson()));

  AttendanceStats? get stats {
    final raw = _prefs.getString('stats');
    if (raw == null) return null;
    try {
      return AttendanceStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveStats(AttendanceStats s) => _prefs.setString('stats', jsonEncode(s.toJson()));

  // Participant snapshot cursor (updatedSince + afterId) and last refresh time.
  String? get snapshotUpdatedSince => _prefs.getString('snapUpdatedSince');
  String? get snapshotAfterId => _prefs.getString('snapAfterId');
  DateTime? get lastSnapshotAt {
    final v = _prefs.getString('snapAt');
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<void> saveSnapshotCursor({String? updatedSince, String? afterId}) async {
    if (updatedSince != null) await _prefs.setString('snapUpdatedSince', updatedSince);
    if (afterId != null) await _prefs.setString('snapAfterId', afterId);
    await _prefs.setString('snapAt', DateTime.now().toIso8601String());
  }
}
