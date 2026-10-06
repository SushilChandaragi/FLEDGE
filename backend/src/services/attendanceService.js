const Attendance = require('../models/Attendance');
const Participant = require('../models/Participant');
const { findBySrn } = require('./participantService');

const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** A registration created after the event started means the student walked in. */
function classifyRegistration(participant, event) {
  if (participant.registration.source === 'walk_in_google_form') return 'walk_in';
  return participant.registration.registeredAt >= event.startsAt() ? 'walk_in' : 'pre_registered';
}

function presentPayload(record) {
  return {
    srn: record.srn,
    name: record.name,
    branch: record.branch,
    registrationStatus: record.registrationStatus,
    attendanceTime: record.scannedAt,
    deviceId: record.deviceId,
  };
}

/**
 * Single entry point for marking attendance, used for barcode, manual entry and
 * offline replays alike. Duplicate protection is the unique (eventId, srn) index,
 * so two devices racing on the same student can never create two rows.
 */
async function markAttendance({ event, rawSrn, deviceId, operatorId, scannedAt }) {
  const { srn, participant } = await findBySrn(rawSrn);
  if (!participant) {
    return {
      httpStatus: 404,
      body: { success: false, status: 'not_registered', srn, registrationFormRequired: true },
    };
  }

  const existing = await Attendance.findOne({ eventId: event.eventId, srn }).lean();
  if (existing) {
    return { httpStatus: 409, body: { success: false, status: 'already_attended', ...presentPayload(existing) } };
  }

  const now = new Date();
  // Offline replays carry the device clock; never accept a time in the future.
  const hasClientTime = scannedAt instanceof Date && !Number.isNaN(scannedAt.getTime());
  const when = hasClientTime ? new Date(Math.min(scannedAt.getTime(), now.getTime())) : now;
  const offlineSync = hasClientTime && now.getTime() - scannedAt.getTime() > MAX_CLOCK_SKEW_MS;

  try {
    const record = await Attendance.create({
      eventId: event.eventId,
      srn,
      name: participant.name,
      branch: participant.branch,
      registrationStatus: classifyRegistration(participant, event),
      scannedAt: when,
      receivedAt: now,
      deviceId,
      operatorId,
      offlineSync,
    });
    return { httpStatus: 201, body: { success: true, status: 'attendance_marked', ...presentPayload(record) } };
  } catch (err) {
    if (err && err.code === 11000) {
      const winner = await Attendance.findOne({ eventId: event.eventId, srn }).lean();
      return { httpStatus: 409, body: { success: false, status: 'already_attended', ...presentPayload(winner) } };
    }
    throw err;
  }
}

async function listAttendance(eventId, { page, limit, search, filter }) {
  const query = { eventId };
  if (filter === 'pre_registered' || filter === 'walk_in') query.registrationStatus = filter;
  if (search) {
    const safe = escapeRegex(search.trim());
    query.$or = [{ srn: { $regex: `^${safe.toUpperCase()}` } }, { name: { $regex: safe, $options: 'i' } }];
  }
  const [rows, total] = await Promise.all([
    Attendance.find(query)
      .sort({ scannedAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .select('srn name branch registrationStatus scannedAt deviceId')
      .lean(),
    Attendance.countDocuments(query),
  ]);
  return {
    items: rows.map((r) => ({
      srn: r.srn,
      name: r.name,
      branch: r.branch,
      registrationStatus: r.registrationStatus,
      attendanceTime: r.scannedAt,
      deviceId: r.deviceId,
    })),
    page,
    limit,
    total,
    hasMore: page * limit < total,
  };
}

async function stats(eventId) {
  const [registered, present, walkIns] = await Promise.all([
    Participant.countDocuments({ 'registration.registered': true }),
    Attendance.countDocuments({ eventId }),
    Attendance.countDocuments({ eventId, registrationStatus: 'walk_in' }),
  ]);
  return { registered, present, walkIns, absent: Math.max(0, registered - present) };
}

module.exports = { markAttendance, listAttendance, stats };
