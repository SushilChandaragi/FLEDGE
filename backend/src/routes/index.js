const express = require('express');
const rateLimit = require('express-rate-limit');
const c = require('../controllers');
const { authenticate, requireRole } = require('../middleware/auth');
const { requireSyncSecret } = require('../middleware/syncAuth');
const { validate } = require('../middleware/http');

const router = express.Router();
const operatorAccess = [authenticate, requireRole('attendance_operator', 'admin')];

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, status: 'rate_limited', message: 'Too many attempts. Try again in a few minutes.' },
});

router.get('/health', (_req, res) => res.json({ success: true, status: 'ok' }));

router.post('/auth/login', loginLimiter, validate(c.schemas.login), c.login);

// Participants (read-only)
router.get('/participants/snapshot', ...operatorAccess, validate(c.schemas.snapshot, 'query'), c.getSnapshot);
router.get('/participants/:srn', ...operatorAccess, c.getParticipant);

// Events + attendance. Attendance has create + read only: no PUT/PATCH/DELETE exist.
router.get('/events/:eventId', ...operatorAccess, c.getEvent);
router.post('/events/:eventId/attendance', ...operatorAccess, validate(c.schemas.mark), c.markAttendance);
router.get('/events/:eventId/attendance', ...operatorAccess, validate(c.schemas.list, 'query'), c.listAttendance);
router.get('/events/:eventId/attendance/stats', ...operatorAccess, c.attendanceStats);

// Google Apps Script -> MongoDB
router.post('/registration/sync', requireSyncSecret, c.syncRegistration);

module.exports = router;
