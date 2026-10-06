class EventInfo {
  EventInfo({
    required this.eventId,
    required this.eventName,
    required this.date,
    required this.time,
    required this.venue,
    required this.registrationFormUrl,
  });

  final String eventId;
  final String eventName;
  final String date;
  final String time;
  final String venue;
  final String registrationFormUrl;

  factory EventInfo.fromJson(Map<String, dynamic> j) => EventInfo(
        eventId: j['eventId'] as String,
        eventName: j['eventName'] as String,
        date: j['date'] as String? ?? '',
        time: j['time'] as String? ?? '',
        venue: j['venue'] as String? ?? '',
        registrationFormUrl: j['registrationFormUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'eventName': eventName,
        'date': date,
        'time': time,
        'venue': venue,
        'registrationFormUrl': registrationFormUrl,
      };
}

class AttendanceStats {
  const AttendanceStats({this.registered = 0, this.present = 0, this.walkIns = 0});

  final int registered;
  final int present;
  final int walkIns;

  int get preRegisteredPresent => present - walkIns;

  factory AttendanceStats.fromJson(Map<String, dynamic> j) => AttendanceStats(
        registered: (j['registered'] as num?)?.toInt() ?? 0,
        present: (j['present'] as num?)?.toInt() ?? 0,
        walkIns: (j['walkIns'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'registered': registered, 'present': present, 'walkIns': walkIns};
}

class AttendanceRecord {
  AttendanceRecord({
    required this.srn,
    required this.name,
    required this.registrationStatus,
    required this.time,
    required this.deviceId,
  });

  final String srn;
  final String name;
  final String registrationStatus;
  final DateTime time;
  final String deviceId;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        srn: j['srn'] as String,
        name: j['name'] as String,
        registrationStatus: j['registrationStatus'] as String,
        time: DateTime.parse(j['attendanceTime'] as String),
        deviceId: j['deviceId'] as String? ?? '',
      );
}

class AttendancePage {
  AttendancePage({required this.items, required this.hasMore, required this.total});
  final List<AttendanceRecord> items;
  final bool hasMore;
  final int total;
}

enum ScanKind {
  /// Server confirmed the attendance.
  marked,

  /// Saved on this phone only; will be sent when the network returns.
  markedPending,
  alreadyAttended,
  notRegistered,

  /// Offline and the SRN is not in the local snapshot, so we cannot tell.
  offlineUnverified,
  invalidSrn,
  error,
}

class ScanOutcome {
  ScanOutcome({
    required this.kind,
    this.srn = '',
    this.name = '',
    this.registrationStatus = '',
    this.time,
    this.message = '',
    this.pendingSync = false,
  });

  final ScanKind kind;
  final String srn;
  final String name;
  final String registrationStatus;
  final DateTime? time;
  final String message;

  /// For [ScanKind.alreadyAttended]: the original scan is only stored locally so far.
  final bool pendingSync;

  bool get isSuccess => kind == ScanKind.marked || kind == ScanKind.markedPending;
}
