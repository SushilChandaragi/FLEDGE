import 'package:flutter_test/flutter_test.dart';
import 'package:fledge_attendance/utils/srn.dart';
import 'package:fledge_attendance/utils/format.dart';
import 'package:fledge_attendance/models/models.dart';

void main() {
  group('SRN Normalization & Validation', () {
    test('normalizes lowercase and whitespace correctly', () {
      expect(normalizeSrn(' 02fe23bcs136 '), '02FE23BCS136');
      expect(normalizeSrn('02FE 23BCS 136'), '02FE23BCS136');
      expect(normalizeSrn('02fe23bec045'), '02FE23BEC045');
    });

    test('validates standard SRN patterns', () {
      expect(isValidSrn('02FE23BCS136'), isTrue);
      expect(isValidSrn('02FE23BEC045'), isTrue);
      expect(isValidSrn('02FE23BME010'), isTrue);
      expect(isValidSrn('A123'), isTrue);
      expect(isValidSrn(''), isFalse);
      expect(isValidSrn('!@#'), isFalse);
    });
  });

  group('Formatters', () {
    test('registration label formatter', () {
      expect(registrationLabel('walk_in'), 'Walk-in');
      expect(registrationLabel('pre_registered'), 'Pre-registered');
      expect(registrationLabel('unknown'), '');
    });
  });

  group('Model Serialization', () {
    test('EventInfo JSON parsing', () {
      final json = {
        'eventId': 'FLEDGE26',
        'eventName': "FLEDGE '26",
        'date': '2026-10-08',
        'time': '09:30',
        'venue': 'KLE Tech Auditorium',
        'registrationFormUrl': 'https://forms.gle/test',
      };
      final event = EventInfo.fromJson(json);
      expect(event.eventId, 'FLEDGE26');
      expect(event.eventName, "FLEDGE '26");
      expect(event.venue, 'KLE Tech Auditorium');
    });

    test('AttendanceStats calculation', () {
      const stats = AttendanceStats(registered: 650, present: 431, walkIns: 23);
      expect(stats.registered, 650);
      expect(stats.present, 431);
      expect(stats.walkIns, 23);
      expect(stats.preRegisteredPresent, 408);
    });
  });
}
