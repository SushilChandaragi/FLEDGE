// Integration tests against a dedicated test database (never the live one).
// Run: npm test
const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

process.env.MONGODB_DB = 'cnest_fledge_test';

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const config = require('../src/config/env');
const app = require('../src/app');
const { connectDb } = require('../src/config/db');
const Event = require('../src/models/Event');
const Participant = require('../src/models/Participant');
const Attendance = require('../src/models/Attendance');
const Operator = require('../src/models/Operator');

let server;
let base;
let token;

async function api(method, path, { body, auth = token, headers = {} } = {}) {
  const res = await fetch(`${base}/api${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(auth ? { authorization: `Bearer ${auth}` } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, json: await res.json() };
}

const sync = (body) => api('POST', '/registration/sync', { body, auth: null, headers: { 'x-sync-secret': config.syncSecret } });

test.before(async () => {
  assert.equal(config.mongoDb, 'cnest_fledge_test');
  await connectDb();
  await Promise.all([Event.deleteMany({}), Participant.deleteMany({}), Attendance.deleteMany({}), Operator.deleteMany({})]);
  await Event.create({
    eventId: 'FLEDGE26', eventName: "FLEDGE '26", date: '2026-10-08', time: '09:30',
    venue: 'KLE Tech', registrationFormUrl: 'https://forms.gle/x', active: true,
  });
  await Operator.create({ operatorId: 'gate1', passwordHash: await bcrypt.hash('password123', 4), role: 'attendance_operator' });
  server = http.createServer(app).listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
});

test.after(async () => {
  server.close();
  await mongoose.connection.dropDatabase();
  await mongoose.disconnect();
});

test('auth: rejects bad credentials and unauthenticated access', async () => {
  assert.equal((await api('POST', '/auth/login', { body: { operatorId: 'gate1', password: 'nope' }, auth: null })).status, 401);
  assert.equal((await api('GET', '/events/FLEDGE26/attendance', { auth: null })).status, 401);
  assert.equal((await api('GET', '/events/FLEDGE26/attendance', { auth: 'garbage' })).json.status, 'auth_invalid');
  const ok = await api('POST', '/auth/login', { body: { operatorId: 'GATE1', password: 'password123' }, auth: null });
  assert.equal(ok.status, 200);
  token = ok.json.token;
});

test('registration sync: secret required, upsert by SRN, no duplicates', async () => {
  const denied = await api('POST', '/registration/sync', { body: {}, auth: null, headers: { 'x-sync-secret': 'bad' } });
  assert.equal(denied.status, 401);

  const first = await sync({ srn: ' 02fe23bcs136 ', name: 'Asha Rao', email: 'A@x.com', branch: 'cse', submittedAt: '2026-10-05T10:00:00Z' });
  assert.equal(first.json.results[0].status, 'created');
  const again = await sync({ srn: '02FE23BCS136', name: 'Asha R', email: 'a@x.com', branch: 'CSE', submittedAt: '2026-10-07T10:00:00Z' });
  assert.equal(again.json.results[0].status, 'updated');
  assert.equal(await Participant.countDocuments({ srn: '02FE23BCS136' }), 1);
  const p = await Participant.findOne({ srn: '02FE23BCS136' });
  assert.equal(p.name, 'Asha R');
  assert.equal(p.registration.registeredAt.toISOString(), '2026-10-05T10:00:00.000Z', 'first registeredAt preserved');

  await sync({ srn: '02FE23BEC045', name: 'Ravi K', email: 'r@x.com', branch: 'ECE', submittedAt: '2026-10-05T10:00:00Z' });
  const bad = await sync({ srn: '', name: 'X' });
  assert.equal(bad.status, 400);
});

test('participant lookup and not-registered', async () => {
  const hit = await api('GET', '/participants/02fe23bcs136');
  assert.equal(hit.status, 200);
  assert.equal(hit.json.participant.name, 'Asha R');
  const miss = await api('GET', '/participants/02FE23BCS999');
  assert.equal(miss.status, 404);
  assert.equal(miss.json.status, 'not_registered');
});

test('attendance: mark, lowercase/space SRN, other branch, duplicate, unknown', async () => {
  const a = await api('POST', '/events/FLEDGE26/attendance', { body: { srn: ' 02fe23bcs136 ', deviceId: 'gate-a-01' } });
  assert.equal(a.status, 201);
  assert.equal(a.json.status, 'attendance_marked');
  assert.equal(a.json.registrationStatus, 'pre_registered');
  assert.equal(a.json.deviceId, 'GATE-A-01');

  const b = await api('POST', '/events/FLEDGE26/attendance', { body: { srn: '02FE23BEC045', deviceId: 'GATE-A-01' } });
  assert.equal(b.status, 201);

  const dup = await api('POST', '/events/FLEDGE26/attendance', { body: { srn: '02FE23BCS136', deviceId: 'GATE-B-01' } });
  assert.equal(dup.status, 409);
  assert.equal(dup.json.status, 'already_attended');
  assert.equal(dup.json.attendanceTime, a.json.attendanceTime, 'original timestamp unchanged');
  assert.equal(dup.json.deviceId, 'GATE-A-01');

  const unknown = await api('POST', '/events/FLEDGE26/attendance', { body: { srn: '02FE23BCS200', deviceId: 'GATE-A-01' } });
  assert.equal(unknown.status, 404);
  assert.equal(unknown.json.status, 'not_registered');
  assert.equal(await Attendance.countDocuments(), 2);

  assert.equal((await api('POST', '/events/FLEDGE26/attendance', { body: { srn: '!!', deviceId: 'G1' } })).json.status, 'invalid_srn');
  assert.equal((await api('POST', '/events/NOPE/attendance', { body: { srn: '02FE23BCS136', deviceId: 'G1' } })).status, 404);
});

test('attendance: concurrent scans from many devices create exactly one record', async () => {
  await sync({ srn: '02FE23BME010', name: 'Race Student', email: 'z@x.com', branch: 'ME', submittedAt: '2026-10-05T10:00:00Z' });
  const results = await Promise.all(
    Array.from({ length: 12 }, (_, i) =>
      api('POST', '/events/FLEDGE26/attendance', { body: { srn: '02FE23BME010', deviceId: `GATE-${i}` } })
    )
  );
  assert.equal(results.filter((r) => r.status === 201).length, 1);
  assert.equal(results.filter((r) => r.status === 409).length, 11);
  assert.equal(await Attendance.countDocuments({ srn: '02FE23BME010' }), 1);
});

test('walk-in: registers after not_registered, then marked as walk_in', async () => {
  const before = await api('POST', '/events/FLEDGE26/attendance', { body: { srn: '02FE23BCS555', deviceId: 'GATE-A-01' } });
  assert.equal(before.json.status, 'not_registered');
  await sync({ srn: '02FE23BCS555', name: 'Walk In', email: 'w@x.com', branch: 'CSE', source: 'walk_in_google_form' });
  const after = await api('POST', '/events/FLEDGE26/attendance', { body: { srn: '02FE23BCS555', deviceId: 'GATE-A-01' } });
  assert.equal(after.status, 201);
  assert.equal(after.json.registrationStatus, 'walk_in');
});

test('offline replay keeps the device scan time but never a future time', async () => {
  await sync({ srn: '02FE23BCS300', name: 'Offline One', branch: 'CSE', submittedAt: '2026-10-05T10:00:00Z' });
  const t = new Date(Date.now() - 20 * 60 * 1000).toISOString();
  const r = await api('POST', '/events/FLEDGE26/attendance', { body: { srn: '02FE23BCS300', deviceId: 'GATE-A-02', scannedAt: t } });
  assert.equal(r.status, 201);
  assert.equal(r.json.attendanceTime, t);
  const rec = await Attendance.findOne({ srn: '02FE23BCS300' });
  assert.equal(rec.offlineSync, true);

  await sync({ srn: '02FE23BCS301', name: 'Future', branch: 'CSE', submittedAt: '2026-10-05T10:00:00Z' });
  const f = await api('POST', '/events/FLEDGE26/attendance', {
    body: { srn: '02FE23BCS301', deviceId: 'GATE-A-02', scannedAt: new Date(Date.now() + 3600e3).toISOString() },
  });
  assert.ok(new Date(f.json.attendanceTime) <= new Date());
});

test('records: stats, pagination, search, filters', async () => {
  const stats = await api('GET', '/events/FLEDGE26/attendance/stats');
  assert.equal(stats.json.present, 6);
  assert.equal(stats.json.walkIns, 1);
  assert.equal(stats.json.registered, 6);
  assert.equal(stats.json.absent, 0);

  const page = await api('GET', '/events/FLEDGE26/attendance?limit=2&page=1');
  assert.equal(page.json.items.length, 2);
  assert.equal(page.json.total, 6);
  assert.equal(page.json.hasMore, true);

  assert.equal((await api('GET', '/events/FLEDGE26/attendance?search=asha')).json.total, 1);
  assert.equal((await api('GET', '/events/FLEDGE26/attendance?search=02fe23bec')).json.total, 1);
  assert.equal((await api('GET', '/events/FLEDGE26/attendance?filter=walk_in')).json.total, 1);
  assert.equal((await api('GET', '/events/FLEDGE26/attendance?search=.*')).json.total, 0, 'regex is escaped');
});

test('snapshot is paginated and supports deltas; attendance is immutable over HTTP', async () => {
  const p1 = await api('GET', '/participants/snapshot?limit=3');
  assert.equal(p1.json.participants.length, 3);
  assert.equal(p1.json.hasMore, true);
  const { updatedSince, afterId } = p1.json.next;
  const p2 = await api('GET', `/participants/snapshot?limit=100&updatedSince=${encodeURIComponent(updatedSince)}&afterId=${afterId}`);
  assert.equal(p2.json.participants.length, 3);
  assert.equal(p2.json.hasMore, false);

  for (const m of ['PUT', 'PATCH', 'DELETE']) {
    assert.equal((await api(m, '/events/FLEDGE26/attendance/02FE23BCS136')).status, 404);
  }
});
