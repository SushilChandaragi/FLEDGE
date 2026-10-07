// Usage: npm run export:present [output-file.csv]
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const { connectDb } = require('../src/config/db');
const Attendance = require('../src/models/Attendance');
const Participant = require('../src/models/Participant');
const config = require('../src/config/env');

function escapeCsv(str) {
  if (str == null) return '""';
  const val = String(str);
  if (val.includes(',') || val.includes('"') || val.includes('\n') || val.includes('\r')) {
    return `"${val.replace(/"/g, '""')}"`;
  }
  return `"${val}"`;
}

function formatIst(date) {
  if (!date) return '';
  return new Date(date).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', hour12: true });
}

async function main() {
  const outputFile = process.argv[2] || `fledge26_present_attendees_${new Date().toISOString().slice(0, 10)}.csv`;
  const outputPath = path.resolve(process.cwd(), outputFile);

  await connectDb();
  console.log(`Fetching attendance records for event "${config.eventId}" from database "${config.mongoDb}"...`);

  const attendanceRecords = await Attendance.find({ eventId: config.eventId.toUpperCase() })
    .sort({ attendanceTime: 1 })
    .lean();

  if (attendanceRecords.length === 0) {
    console.log('No attendance records found for this event.');
    await mongoose.disconnect();
    process.exit(0);
  }

  const srns = attendanceRecords.map((a) => a.srn);
  const participants = await Participant.find({ srn: { $in: srns } }).lean();
  const participantMap = new Map(participants.map((p) => [p.srn, p]));

  const headers = [
    'Sl No',
    'SRN',
    'Student Name',
    'Branch',
    'Email',
    'Attendance Time (IST)',
    'Registration Status',
    'Operator ID',
    'Device ID',
  ];

  const rows = [headers.join(',')];

  attendanceRecords.forEach((rec, idx) => {
    const part = participantMap.get(rec.srn);
    const name = rec.name || (part ? part.name : '');
    const branch = rec.branch || (part ? part.branch : '');
    const email = part ? part.email : '';
    const status = rec.registrationStatus === 'walk_in' ? 'Walk-in' : 'Pre-registered';
    const timestamp = rec.scannedAt || rec.receivedAt;

    const row = [
      idx + 1,
      escapeCsv(rec.srn),
      escapeCsv(name),
      escapeCsv(branch),
      escapeCsv(email),
      escapeCsv(formatIst(timestamp)),
      escapeCsv(status),
      escapeCsv(rec.operatorId || ''),
      escapeCsv(rec.deviceId || ''),
    ];
    rows.push(row.join(','));
  });

  fs.writeFileSync(outputPath, rows.join('\n'), 'utf8');
  console.log(`\nExport complete! ${attendanceRecords.length} records exported successfully.`);
  console.log(`File saved to: ${outputPath}\n`);

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('Export failed:', err);
  process.exit(1);
});
