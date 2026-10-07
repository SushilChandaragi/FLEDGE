const { z } = require('zod');
const authService = require('../services/authService');
const participantService = require('../services/participantService');
const eventService = require('../services/eventService');
const attendanceService = require('../services/attendanceService');

const schemas = {
  login: z.object({
    operatorId: z.string().trim().min(1, 'Operator ID is required.').max(64),
    password: z.string().min(1, 'Password is required.').max(256),
  }),
  mark: z.object({
    srn: z.string().min(1, 'SRN is required.').max(64),
    deviceId: z
      .string()
      .trim()
      .min(1, 'Device ID is required.')
      .max(32)
      .regex(/^[A-Za-z0-9_-]+$/, 'Device ID may only contain letters, numbers, - and _.')
      .transform((s) => s.toUpperCase()),
    scannedAt: z.coerce.date().optional(),
  }),
  list: z.object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(30),
    search: z.string().trim().max(64).optional(),
    filter: z.enum(['all', 'pre_registered', 'walk_in']).default('all'),
  }),
  snapshot: z.object({
    updatedSince: z.coerce.date().optional(),
    afterId: z.string().regex(/^[a-f0-9]{24}$/i).optional(),
    limit: z.coerce.number().int().min(1).max(2000).default(1000),
  }),
  registration: z.object({
    srn: z.string().min(1, 'SRN is required.').max(64),
    name: z.string().trim().min(1, 'Name is required.').max(120),
    email: z.string().trim().max(160).optional(),
    branch: z.string().trim().max(40).optional(),
    source: z.enum(['google_form', 'walk_in_google_form', 'admin_import']).optional(),
    submittedAt: z.coerce.date().optional(),
  }),
  registrationBatch: z.object({
    registrations: z.array(z.any()).min(1).max(500),
  }),
};

const wrap = (fn) => (req, res, next) => fn(req, res, next).catch(next);

const login = wrap(async (req, res) => {
  const result = await authService.login(req.body.operatorId, req.body.password);
  res.json({ success: true, ...result });
});

const getEvent = wrap(async (req, res) => {
  const event = await eventService.getActiveEvent(req.params.eventId);
  res.json({ success: true, event: eventService.toPublic(event) });
});

const getParticipant = wrap(async (req, res) => {
  const { srn, participant } = await participantService.findBySrn(req.params.srn);
  if (!participant) {
    return res.status(404).json({ success: false, status: 'not_registered', srn, registrationFormRequired: true });
  }
  return res.json({ success: true, status: 'registered', participant: participantService.toPublic(participant) });
});

const listParticipants = wrap(async (req, res) => {
  const { page, limit, search } = req.query;
  res.json({ success: true, ...(await participantService.listParticipants({ page: Number(page) || 1, limit: Number(limit) || 50, search })) });
});

const getSnapshot = wrap(async (req, res) => {
  const { updatedSince, afterId, limit } = req.query;
  res.json({ success: true, ...(await participantService.snapshot({ updatedSince, afterId, limit })) });
});

const resetAttendance = wrap(async (req, res) => {
  const Attendance = require('../models/Attendance');
  const result = await Attendance.deleteMany({ eventId: req.params.eventId.toUpperCase() });
  res.json({ success: true, message: `Cleared ${result.deletedCount} attendance record(s).` });
});

const exportAttendanceCsv = wrap(async (req, res) => {
  const Attendance = require('../models/Attendance');
  const Participant = require('../models/Participant');
  const records = await Attendance.find({ eventId: req.params.eventId.toUpperCase() }).sort({ scannedAt: 1 }).lean();
  const srns = records.map((r) => r.srn);
  const participants = await Participant.find({ srn: { $in: srns } }).lean();
  const partMap = new Map(participants.map((p) => [p.srn, p]));

  const escapeCsv = (str) => {
    if (str == null) return '""';
    const s = String(str);
    return s.includes(',') || s.includes('"') || s.includes('\n') ? `"${s.replace(/"/g, '""')}"` : `"${s}"`;
  };

  const lines = ['Sl No,SRN,Name,Branch,Email,Attendance Time,Registration Status,Operator ID,Device ID'];
  records.forEach((r, i) => {
    const p = partMap.get(r.srn);
    const ts = r.scannedAt || r.receivedAt;
    lines.push([
      i + 1,
      escapeCsv(r.srn),
      escapeCsv(r.name || (p ? p.name : '')),
      escapeCsv(r.branch || (p ? p.branch : '')),
      escapeCsv(p ? p.email : ''),
      escapeCsv(ts ? new Date(ts).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', hour12: true }) : ''),
      escapeCsv(r.registrationStatus === 'walk_in' ? 'Walk-in' : 'Pre-registered'),
      escapeCsv(r.operatorId || ''),
      escapeCsv(r.deviceId || ''),
    ].join(','));
  });

  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${req.params.eventId}_attendance.csv"`);
  res.send(lines.join('\n'));
});

const markAttendance = wrap(async (req, res) => {
  const event = await eventService.getActiveEvent(req.params.eventId);
  const { httpStatus, body } = await attendanceService.markAttendance({
    event,
    rawSrn: req.body.srn,
    deviceId: req.body.deviceId,
    operatorId: req.operator.operatorId,
    scannedAt: req.body.scannedAt,
  });
  res.status(httpStatus).json(body);
});

const listAttendance = wrap(async (req, res) => {
  const event = await eventService.getActiveEvent(req.params.eventId);
  const { page, limit, search, filter } = req.query;
  res.json({ success: true, ...(await attendanceService.listAttendance(event.eventId, { page, limit, search, filter })) });
});

const attendanceStats = wrap(async (req, res) => {
  const event = await eventService.getActiveEvent(req.params.eventId);
  res.json({ success: true, ...(await attendanceService.stats(event.eventId)) });
});

// Google Apps Script posts one registration per form submission.
// A batch form ({ registrations: [...] }) is also accepted for backfills.
const syncRegistration = wrap(async (req, res) => {
  const items = Array.isArray(req.body.registrations) ? req.body.registrations : [req.body];
  const results = [];
  for (const item of items) {
    const parsed = schemas.registration.safeParse(item);
    if (!parsed.success) {
      results.push({ srn: item && item.srn, status: 'rejected', message: parsed.error.issues[0].message });
      continue;
    }
    try {
      const { created } = await participantService.upsertRegistration({
        ...parsed.data,
        source: parsed.data.source || 'google_form',
        registeredAt: parsed.data.submittedAt,
      });
      results.push({ srn: parsed.data.srn.replace(/\s+/g, '').toUpperCase(), status: created ? 'created' : 'updated' });
    } catch (err) {
      results.push({ srn: item.srn, status: 'rejected', message: err.message });
    }
  }
  const rejected = results.filter((r) => r.status === 'rejected').length;
  res.status(rejected === results.length ? 400 : 200).json({ success: rejected < results.length, results });
});

module.exports = {
  schemas,
  login,
  getEvent,
  getParticipant,
  listParticipants,
  getSnapshot,
  markAttendance,
  listAttendance,
  attendanceStats,
  resetAttendance,
  exportAttendanceCsv,
  syncRegistration,
};
