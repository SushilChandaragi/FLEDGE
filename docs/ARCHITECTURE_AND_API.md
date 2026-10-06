# CNEST FLEDGE '26 — Attendance System Documentation

## 1. System Architecture Overview

```
                      +-----------------------------+
                      |   Google Form Registration  |
                      |   (Pre-event & Walk-ins)    |
                      +--------------+--------------+
                                     |
                                     v
                      +-----------------------------+
                      |        Google Sheets        |
                      +--------------+--------------+
                                     | (onFormSubmit Trigger)
                                     v
                      +-----------------------------+
                      |     Google Apps Script      |
                      | (POST /api/registration/sync)
                      +--------------+--------------+
                                     | HTTPS (x-sync-secret)
                                     v
+------------------+         +-------------------------------+
| Flutter Mobile   +-------->+ Node.js / Express REST API    |
| Attendance App   |<--------+ (JWT Operator Auth, Validation)
+------------------+         +---------------+---------------+
 (Barcode Camera /                           |
  Manual Fallback /                          v
  Offline SQLite Cache)      +-------------------------------+
                             |    MongoDB Atlas Database     |
                             |   (Events, Participants,      |
                             |    Attendance unique indices) |
                             +-------------------------------+
```

---

## 2. API Endpoints Reference

Base URL: `http://<host>:4000/api` (or your production HTTPS domain)

### Authentication
#### `POST /api/auth/login`
- **Rate Limit:** 30 requests / 15 minutes.
- **Request Body:**
  ```json
  {
    "operatorId": "gate1",
    "password": "fledge2026"
  }
  ```
- **Success Response (200 OK):**
  ```json
  {
    "success": true,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "operator": {
      "operatorId": "gate1",
      "displayName": "Gate 1 Operator",
      "role": "attendance_operator"
    }
  }
  ```

### Participants
#### `GET /api/participants/:srn`
- **Headers:** `Authorization: Bearer <jwt_token>`
- **Success Response (200 OK):**
  ```json
  {
    "success": true,
    "status": "registered",
    "participant": {
      "srn": "02FE23BCS136",
      "name": "Sushil Shashidhar Chandaragi",
      "email": "sushil@kletech.ac.in",
      "branch": "CSE",
      "registered": true,
      "registrationSource": "google_form",
      "registeredAt": "2026-10-06T15:42:19.000Z"
    }
  }
  ```
- **Not Registered (404 Not Found):**
  ```json
  {
    "success": false,
    "status": "not_registered",
    "srn": "02FE23BCS999",
    "registrationFormRequired": true
  }
  ```

#### `GET /api/participants/snapshot`
- **Headers:** `Authorization: Bearer <jwt_token>`
- **Query Parameters:** `limit` (max 2000), `updatedSince` (ISO date), `afterId` (ObjectId string)
- **Used by:** Mobile app to download offline snapshot cache and incremental deltas.

### Attendance
#### `POST /api/events/:eventId/attendance`
- **Headers:** `Authorization: Bearer <jwt_token>`
- **Request Body:**
  ```json
  {
    "srn": "02FE23BCS136",
    "deviceId": "GATE-A-01",
    "scannedAt": "2026-10-08T09:42:15.000Z"
  }
  ```
- **Success (201 Created):**
  ```json
  {
    "success": true,
    "status": "attendance_marked",
    "srn": "02FE23BCS136",
    "name": "Sushil Shashidhar Chandaragi",
    "branch": "CSE",
    "registrationStatus": "pre_registered",
    "attendanceTime": "2026-10-08T09:42:15.000Z",
    "deviceId": "GATE-A-01"
  }
  ```
- **Duplicate / Already Attended (409 Conflict):**
  ```json
  {
    "success": false,
    "status": "already_attended",
    "srn": "02FE23BCS136",
    "name": "Sushil Shashidhar Chandaragi",
    "branch": "CSE",
    "registrationStatus": "pre_registered",
    "attendanceTime": "2026-10-08T09:42:15.000Z",
    "deviceId": "GATE-A-01"
  }
  ```
- **Not Registered (404 Not Found):**
  ```json
  {
    "success": false,
    "status": "not_registered",
    "srn": "02FE23BCS200",
    "registrationFormRequired": true
  }
  ```

#### `GET /api/events/:eventId/attendance`
- **Headers:** `Authorization: Bearer <jwt_token>`
- **Query Parameters:** `page` (default: 1), `limit` (default: 30), `search` (SRN/Name), `filter` (`all` | `pre_registered` | `walk_in`)
- **Returns:** Paginated, read-only list of attendance records.

#### `GET /api/events/:eventId/attendance/stats`
- **Headers:** `Authorization: Bearer <jwt_token>`
- **Response (200 OK):**
  ```json
  {
    "success": true,
    "registered": 650,
    "present": 431,
    "walkIns": 23,
    "absent": 219
  }
  ```

### Real-Time Registration Sync
#### `POST /api/registration/sync`
- **Headers:** `x-sync-secret: <REGISTRATION_SYNC_SECRET>`
- **Single submission:**
  ```json
  {
    "srn": "02FE23BCS555",
    "name": "Ananya Joshi",
    "email": "ananya@kletech.ac.in",
    "branch": "ECE",
    "submittedAt": "2026-10-08T10:02:10.000Z"
  }
  ```
- **Batch submission (Backfill):**
  ```json
  {
    "registrations": [
      { "srn": "02FE23BCS001", "name": "Student 1", "branch": "CSE" },
      { "srn": "02FE23BCS002", "name": "Student 2", "branch": "ECE" }
    ]
  }
  ```

---

## 3. Database Schema & Indexes

1. **`Event` (`events` collection):**
   - Unique index on `eventId`.
2. **`Participant` (`participants` collection):**
   - Unique index on `srn` (uppercase, normalized).
   - Compound index on `{ updatedAt: 1, _id: 1 }` for delta offline downloads.
3. **`Attendance` (`attendances` collection):**
   - **Compound Unique Index:** `{ eventId: 1, srn: 1 }` (guarantees atomic duplicate protection across multiple concurrent devices).
   - Compound index: `{ eventId: 1, scannedAt: -1 }`.
   - Compound index: `{ eventId: 1, registrationStatus: 1 }`.
4. **`Operator` (`operators` collection):**
   - Unique index on `operatorId` (lowercase).
