import 'package:intl/intl.dart';

final _timeFmt = DateFormat('hh:mm a');
final _dateTimeFmt = DateFormat('d MMM, hh:mm a');

String formatTime(DateTime? t) => t == null ? '' : _timeFmt.format(t.toLocal());
String formatDateTime(DateTime? t) => t == null ? '' : _dateTimeFmt.format(t.toLocal());

String registrationLabel(String status) => switch (status) {
      'walk_in' => 'Walk-in',
      'pre_registered' => 'Pre-registered',
      _ => '',
    };
