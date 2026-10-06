import '../models/models.dart';
import '../utils/srn.dart';
import 'api_client.dart';
import 'local_db.dart';
import 'session_store.dart';

/// The single path every scan goes through: barcode, manual entry, and
/// "check again" all call [process]. No business logic lives in the UI.
class AttendanceService {
  AttendanceService(this._api, this._db, this._store);

  final ApiClient _api;
  final LocalDb _db;
  final SessionStore _store;

  /// May throw [AuthExpiredException]; every other failure is turned into a [ScanOutcome].
  Future<ScanOutcome> process(String raw) async {
    final srn = normalizeSrn(raw);
    if (!isValidSrn(srn)) {
      return ScanOutcome(
        kind: ScanKind.invalidSrn,
        srn: srn,
        message: srn.isEmpty ? 'Enter an SRN.' : 'That does not look like a valid SRN.',
      );
    }

    final deviceId = _store.deviceId;
    if (deviceId.isEmpty) {
      return ScanOutcome(kind: ScanKind.error, srn: srn, message: 'This phone has no device ID. Sign out and set one.');
    }

    // Saved on this phone but not synced yet: no need to ask the server.
    final local = await _db.attended(srn);
    if (local != null && !local.synced) return _alreadyFromLocal(local);

    try {
      final res = await _api.markAttendance(srn: srn, deviceId: deviceId);
      return await _fromServer(srn, res);
    } on ApiException catch (e) {
      if (e.network) return _offline(srn, deviceId, local);
      return ScanOutcome(kind: ScanKind.error, srn: srn, message: e.message);
    }
  }

  Future<ScanOutcome> _fromServer(String srn, ApiResponse res) async {
    switch (res.status) {
      case 'attendance_marked':
      case 'already_attended':
        final time = DateTime.tryParse(res.json['attendanceTime'] as String? ?? '') ?? DateTime.now();
        final name = res.json['name'] as String? ?? '';
        final type = res.json['registrationStatus'] as String? ?? '';
        await _db.upsertAttended(AttendedEntry(srn: srn, name: name, time: time, registrationStatus: type, synced: true));
        return ScanOutcome(
          kind: res.status == 'attendance_marked' ? ScanKind.marked : ScanKind.alreadyAttended,
          srn: srn,
          name: name,
          registrationStatus: type,
          time: time,
        );
      case 'not_registered':
        return ScanOutcome(kind: ScanKind.notRegistered, srn: srn);
      case 'invalid_srn':
      case 'validation_error':
        return ScanOutcome(kind: ScanKind.invalidSrn, srn: srn, message: 'That does not look like a valid SRN.');
      case 'event_not_found':
        return ScanOutcome(kind: ScanKind.error, srn: srn, message: 'This event is not active on the server.');
      default:
        return ScanOutcome(kind: ScanKind.error, srn: srn, message: 'Unexpected response from the server.');
    }
  }

  ScanOutcome _alreadyFromLocal(AttendedEntry e) => ScanOutcome(
        kind: ScanKind.alreadyAttended,
        srn: e.srn,
        name: e.name,
        registrationStatus: e.registrationStatus,
        time: e.time,
        pendingSync: !e.synced,
      );

  /// Server unreachable. We can only vouch for students in the downloaded snapshot,
  /// and the result is labelled as not yet confirmed by the server.
  Future<ScanOutcome> _offline(String srn, String deviceId, AttendedEntry? local) async {
    if (local != null) return _alreadyFromLocal(local);

    final name = await _db.participantName(srn);
    if (name == null) {
      return ScanOutcome(
        kind: ScanKind.offlineUnverified,
        srn: srn,
        message: 'No connection. This SRN is not in the offline list, so registration cannot be checked yet.',
      );
    }
    final now = DateTime.now();
    await _db.enqueueScan(srn: srn, scannedAt: now, deviceId: deviceId);
    await _db.upsertAttended(
        AttendedEntry(srn: srn, name: name, time: now, registrationStatus: '', synced: false));
    return ScanOutcome(kind: ScanKind.markedPending, srn: srn, name: name, time: now);
  }
}
