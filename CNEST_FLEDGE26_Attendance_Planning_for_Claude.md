# CNEST FLEDGE '26 — Attendance & Certificate System Plan
## Claude Implementation Planning Document

> **Current scope:** Phase 1 — Attendance Management  
> **Future scope:** Phase 2 — Certificate Verification & Generation, Phase 3 — Automation/Reporting  
> **Event:** FLEDGE '26 — CNEST TBI 2.0 Orientation  
> **Date:** 8 October 2026  
> **Time:** 9:30 AM  
> **Venue:** KLE Tech Auditorium, KLE Technological University, Belagavi

---

# 1. Project Goal

Build a simple, low-cost CNEST event management system that uses the **existing barcode on KLE student ID cards** to manage attendance.

The college ID-card barcode already contains the student's full SRN.

Example:

```text
02FE23BCS136
```

Therefore:

```text
College ID Barcode
        ↓
Full SRN
        ↓
Student record in database
        ↓
Registration verification
        ↓
Attendance
```

There is **no need to decode or calculate the branch from the barcode**.

The SRN itself should be treated as the primary student identifier.

---

# 2. Important Constraints

## College ID cards

- Only the existing **1D barcode** on the college ID card should be used for attendance.
- Do NOT depend on QR codes on the college ID card.
- The barcode value is the complete SRN.
- Example:
  - `02FE23BCS136`
  - `02FE23BMExxx`
  - `02FE23BECxxx`
- Branch codes differ, but the app does not need branch-specific parsing.

## Google Form

A QR code **may be used to open the CNEST registration Google Form** for walk-in participants.

This is separate from the college ID-card barcode requirement.

## Cost

Prefer free/open-source or existing institutional services.

Avoid paid event-management platforms.

## Attendance app permissions

The Flutter attendance app should be able to:

- Scan a barcode.
- Manually enter an SRN if barcode scanning fails.
- Verify whether the student is registered.
- Mark attendance.
- Identify registered vs walk-in/not-yet-registered.
- View attendance/scanned records.
- View counts/statistics.
- Work with weak/unreliable internet as much as reasonably possible.

The app should be **read + create attendance only**.

The app should NOT allow attendance records to be edited or deleted.

---

# 3. Proposed Architecture

```text
                         ┌──────────────────────┐
                         │   Google Form        │
                         │ Event Registration   │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Google Sheets        │
                         │ Form Responses       │
                         └──────────┬───────────┘
                                    │
                               Sync / Import
                                    │
                                    ▼
┌───────────────────┐      ┌──────────────────────┐
│ Flutter App       │─────▶│ Node.js / Express    │
│ Attendance App    │ API  │ Backend              │
│                   │◀─────│                      │
│ Barcode Scanner   │      └──────────┬───────────┘
│ Manual SRN        │                 │
│ Read-only Records │                 ▼
└───────────────────┘       ┌──────────────────────┐
                            │ MongoDB Atlas         │
                            │                      │
                            │ Participants         │
                            │ Events               │
                            │ Attendance           │
                            └──────────────────────┘
```

Future:

```text
MongoDB
   ↓
CNEST Website
   ↓
Certificate Verification
   ↓
OTP / Email Verification
   ↓
Certificate Generation
   ↓
PDF + Certificate ID
```

---

# 4. Recommended Tech Stack

## Mobile App

**Flutter / Dart**

Packages:

- `mobile_scanner` — barcode scanning
- `dio` or `http` — API calls
- `isar` or `hive` — local offline cache / scan queue
- `connectivity_plus` — network status
- `shared_preferences` — simple local settings/session
- `qr_flutter` — display the Google Form QR in the app if required

The scanner must support common 1D barcode formats. Test against actual KLE ID cards before finalizing the scanner configuration.

## Backend

**Node.js + Express**

Recommended:

- Express
- Mongoose
- JWT-based operator authentication
- `dotenv`
- validation library such as Zod/Joi
- rate limiting
- CORS

## Database

**MongoDB Atlas**

Use a unique index on:

```text
participants.srn
```

and a compound unique index on:

```text
attendance.eventId + attendance.srn
```

This prevents duplicate attendance for the same event.

## Registration Source

**Google Form → Google Sheets**

The Google Form is the registration source for:

- pre-registered students
- walk-in students who register on the spot

The backend should synchronize or import Google Form responses into MongoDB.

---

# 5. Database Design

## Collection: `events`

Example:

```json
{
  "eventId": "FLEDGE26",
  "eventName": "FLEDGE '26",
  "description": "CNEST TBI 2.0 Orientation",
  "date": "2026-10-08",
  "time": "09:30",
  "venue": "KLE Tech Auditorium, Belagavi",
  "registrationFormUrl": "GOOGLE_FORM_URL",
  "active": true
}
```

---

## Collection: `participants`

Recommended structure:

```json
{
  "srn": "02FE23BCS136",
  "name": "Sushil Shashidhar Chandaragi",
  "email": "student@example.com",
  "branch": "CSE",

  "registration": {
    "registered": true,
    "source": "google_form",
    "registeredAt": "2026-10-07T12:10:00Z"
  },

  "createdAt": "2026-10-07T12:10:00Z",
  "updatedAt": "2026-10-07T12:10:00Z"
}
```

Possible registration sources:

```text
google_form
walk_in_google_form
admin_import
```

Important:

- `srn` is the unique identifier.
- Name comes from the registration database.
- Do not ask the participant to manually type their name for certificate generation.
- The app should not allow changing participant information.

---

## Collection: `attendance`

Example:

```json
{
  "eventId": "FLEDGE26",
  "srn": "02FE23BCS136",
  "attendanceStatus": "present",
  "registrationStatus": "pre_registered",
  "scannedAt": "2026-10-08T09:42:15Z",
  "deviceId": "GATE-A-01"
}
```

For a walk-in:

```json
{
  "eventId": "FLEDGE26",
  "srn": "02FE23BCS555",
  "attendanceStatus": "present",
  "registrationStatus": "walk_in",
  "scannedAt": "2026-10-08T10:02:10Z",
  "deviceId": "GATE-A-01"
}
```

---

# 6. PHASE 1 — ATTENDANCE SYSTEM

## Phase 1 Goal

The event-day system must reliably do one thing:

> Scan/read an SRN → verify registration → mark attendance → allow tech team to view the record.

No certificate generation in this phase.

---

# 7. Phase 1 App Screens

The Flutter app should have approximately 4 main screens.

## Screen 1 — Login / Operator Access

```text
CNEST FLEDGE '26
Attendance System

Operator ID
[________________]

Password
[________________]

[ LOGIN ]
```

Only authorized CNEST volunteers/team members can use attendance marking.

After successful login:

```text
        CNEST ATTENDANCE
           FLEDGE '26

Registered: 650
Present:    431
Walk-ins:    23

[ START SCANNING ]

[ VIEW ATTENDANCE ]
```

---

# 8. Screen 2 — Scan Attendance

Primary event-day screen.

```text
┌──────────────────────────────────┐
│           SCAN BARCODE            │
│                                  │
│                                  │
│        CAMERA PREVIEW             │
│                                  │
│        [ barcode area ]           │
│                                  │
└──────────────────────────────────┘

[ Enter SRN Manually ]

Recent scan:
02FE23BCS136
```

The app should automatically start scanning.

Do NOT require the operator to press a button for every student.

---

# 9. Manual SRN Entry

Below the scanner there must be a clear fallback:

```text
Barcode not working?

[ Enter SRN Manually ]
```

When tapped:

```text
Enter SRN

[ 02FE23BCS136 ]

[ CHECK ]
```

Normalize input:

- trim spaces
- convert to uppercase
- reject obviously invalid/empty input
- do not modify valid SRNs beyond normalization

Examples:

```text
02fe23bcs136
```

becomes:

```text
02FE23BCS136
```

---

# 10. Scan Processing Flow

Every scan follows this process:

```text
Scan barcode
    ↓
Read SRN
    ↓
Normalize SRN
    ↓
Check participant database
    ↓
Does participant exist?
```

### Case A — Registered participant exists

```text
✅ REGISTERED

Name:
Sushil Shashidhar Chandaragi

SRN:
02FE23BCS136

Registration:
Google Form
```

Prefer automatic marking if the participant is already verified and registered.

Suggested event-day UX:

```text
Scan
 ↓
Backend lookup
 ↓
Registered?
 ↓
YES
 ↓
Mark attendance
 ↓
Green confirmation
```

Avoid an extra button if not needed.

---

# 11. Case B — SRN exists but no event registration

Example:

```text
⚠️ NOT REGISTERED FOR FLEDGE '26

SRN: 02FE23BCS200
Name: Rahul Patil

This student does not have a
FLEDGE '26 registration.

[ SHOW REGISTRATION QR ]
[ ENTER SRN AGAIN ]
```

The operator asks the student to register through the Google Form.

The app should display the Google Form QR code full-screen.

Also provide:

```text
Google Form:
<FORM URL>
```

Optional: copy/open form link.

---

# 12. Walk-in registration flow

The intended flow is:

```text
Student arrives
      ↓
Scan college ID
      ↓
SRN lookup
      ↓
No registration found
      ↓
Show Google Form QR
      ↓
Student scans QR with their own phone
      ↓
Student fills:
    - SRN
    - Name
    - Email
    - Branch
      ↓
Google Form submission
      ↓
Google Sheet response
      ↓
Sync into MongoDB
      ↓
Return to attendance screen
      ↓
Check SRN again
      ↓
Registration now exists
      ↓
Mark attendance
```

The app should make it easy to **retry the same SRN** after registration.

Example:

```text
Registration completed?

[ CHECK REGISTRATION AGAIN ]
```

---

# 13. Important event-day UX for walk-ins

Do not make the volunteer type the name.

The participant enters their details into the Google Form.

The backend imports the form response.

Then the attendance system obtains:

```text
SRN
Name
Email
Branch
```

from the database.

This reduces spelling mistakes and makes the future certificate generation reliable.

---

# 14. Registration Sync Strategy

The Google Form should write into Google Sheets.

Need one of these implementations:

### Preferred simple solution

```text
Google Form
    ↓
Google Sheets
    ↓
Google Apps Script
    ↓
POST to Node.js backend
    ↓
MongoDB
```

Use a Google Apps Script `onFormSubmit` trigger to send new responses to a protected backend endpoint.

Alternative:

```text
Node.js backend periodically fetches
Google Sheet data and upserts participants.
```

The first approach is preferable for near-real-time event-day updates.

Must handle duplicate SRNs safely:

```text
upsert by srn
```

Do not blindly insert a second participant record.

---

# 15. Registration status

Use explicit status values:

```text
pre_registered
walk_in
not_registered
```

Meaning:

### `pre_registered`

Student existed in Google Form responses before the event.

### `walk_in`

Student registered using the Google Form after arriving.

### `not_registered`

SRN currently has no registration record.

This status should appear in the attendance records.

---

# 16. Duplicate Scans

If an already-attended student is scanned again:

```text
⚠️ ALREADY MARKED PRESENT

Sushil Shashidhar Chandaragi
02FE23BCS136

First scanned:
09:42 AM
```

Do NOT create another attendance record.

Do NOT change the original timestamp.

Do NOT provide an edit button.

This should be enforced by the backend as well, not only by Flutter.

---

# 17. Unknown / Invalid Barcode

If the barcode contains an unexpected value:

```text
❌ SRN NOT FOUND

Scanned value:
02FE23BCS999

Possible reason:
Student is not in the current event database.

[ ENTER SRN MANUALLY ]
[ SHOW REGISTRATION QR ]
```

Manual entry should be available immediately.

---

# 18. Attendance Records Screen

The app must have a **view-only** attendance screen.

Example:

```text
ATTENDANCE

Present: 431
Registered: 650
Walk-ins: 23

--------------------------------

02FE23BCS136
Sushil Shashidhar Chandaragi
09:42 AM
Pre-registered

--------------------------------

02FE23BCS137
Rahul Patil
09:43 AM
Pre-registered

--------------------------------

02FE23BCS555
Ananya Joshi
10:02 AM
Walk-in
```

Useful controls:

```text
[ Search SRN / Name ]

Filter:
[ All ] [ Pre-registered ] [ Walk-in ]
```

The records screen should be read-only.

No:

```text
Edit
Delete
Change attendance time
Change name
Change SRN
```

buttons.

---

# 19. App permissions / roles

Recommended minimum roles:

## Attendance Operator

Can:

- login
- scan
- manually enter SRN
- view participant information needed for attendance
- mark attendance
- view attendance records
- view counts
- show registration QR

Cannot:

- edit participants
- delete attendance
- edit attendance
- modify certificates
- modify event configuration

## Admin

Admin access should be outside the event-day app, or through a separate protected web dashboard.

Admin can eventually:

- manage event
- import participants
- review attendance
- correct data
- finalize eligibility
- manage certificates
- export CSV

---

# 20. Offline / Weak Network Design

The app should not fail completely if internet connectivity becomes poor.

Recommended model:

```text
                 Scan
                  ↓
            Local validation
                  ↓
            Add scan to queue
                  ↓
        Try backend synchronization
              ↙         ↘
          Online       Offline
             ↓            ↓
         Sync now     Keep queued
```

Use local storage:

- Isar
- Hive
- or SQLite

Store pending scans locally.

When connectivity returns:

```text
Pending local scans
        ↓
Backend
        ↓
MongoDB
```

Important consideration:

If the app cannot reach MongoDB during a walk-in scenario, it cannot reliably determine whether a student registered seconds ago. Therefore:

- registered students can be supported through locally cached registration data
- new walk-in registrations require connectivity to sync before final confirmation

The app should clearly show:

```text
OFFLINE
Some registration checks may be delayed.
```

---

# 21. Local Cache

Before the event, download/copy a read-only registration snapshot to each attendance device.

For example:

```text
SRN
Name
Email
Branch
Registration status
```

This gives the app fast lookup even if internet is temporarily poor.

However, attendance writes still need to sync to the backend.

The local registration snapshot must not be editable by operators.

---

# 22. Multiple Phones / Multiple Gates

The system should support multiple attendance phones.

Example:

```text
Gate A → Phone 1 → GATE-A-01
Gate A → Phone 2 → GATE-A-02

Gate B → Phone 3 → GATE-B-01
```

Every attendance record stores:

```text
deviceId
```

This is useful for debugging.

Example:

```text
02FE23BCS136
Gate A
09:42:15
```

All devices write to the same MongoDB.

The duplicate rule is global:

```text
eventId + SRN = unique
```

So scanning on Phone 1 and then Phone 2 will still show:

```text
ALREADY ATTENDED
```

---

# 23. API Plan for Phase 1

## Authentication

```http
POST /api/auth/login
```

Returns an auth token.

## Participant lookup

```http
GET /api/participants/:srn
```

Returns minimal data needed by the app.

## Mark attendance

```http
POST /api/events/:eventId/attendance
```

Body:

```json
{
  "srn": "02FE23BCS136",
  "deviceId": "GATE-A-01"
}
```

## Attendance list

```http
GET /api/events/:eventId/attendance
```

Supports:

```text
page
limit
search
filter
```

## Attendance stats

```http
GET /api/events/:eventId/attendance/stats
```

Returns:

```json
{
  "registered": 650,
  "present": 431,
  "walkIns": 23,
  "absent": 219
}
```

## Registration QR / form URL

The event config should provide the Google Form URL to the app.

---

# 24. API Response Design

Do not make the Flutter app guess what happened.

The backend should return explicit statuses.

Example:

```json
{
  "success": true,
  "status": "attendance_marked",
  "srn": "02FE23BCS136",
  "name": "Sushil Shashidhar Chandaragi",
  "registrationStatus": "pre_registered",
  "attendanceTime": "2026-10-08T09:42:15Z"
}
```

Already present:

```json
{
  "success": false,
  "status": "already_attended",
  "srn": "02FE23BCS136",
  "name": "Sushil Shashidhar Chandaragi",
  "attendanceTime": "2026-10-08T09:42:15Z"
}
```

Not registered:

```json
{
  "success": false,
  "status": "not_registered",
  "srn": "02FE23BCS200",
  "registrationFormRequired": true
}
```

The Flutter UI can then display the correct screen automatically.

---

# 25. Phase 1 Security Requirements

Must follow:

1. Never expose MongoDB credentials in Flutter.
2. Flutter communicates only with the backend API.
3. Use HTTPS.
4. Use authentication for attendance operators.
5. Store secrets in environment variables.
6. Do server-side validation of SRNs.
7. Prevent duplicate attendance at the database level.
8. Do not trust the client for `eventId`, user role, or attendance ownership.
9. Log scan time and device ID.
10. Keep the app read-only for existing attendance records.

---

# 26. Phase 1 Folder Structure

Recommended repository:

```text
cnest-event-system/
│
├── attendance-app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── scanner_screen.dart
│   │   │   ├── manual_srn_screen.dart
│   │   │   └── attendance_records_screen.dart
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   ├── scanner_service.dart
│   │   │   ├── local_storage_service.dart
│   │   │   └── sync_service.dart
│   │   ├── widgets/
│   │   └── utils/
│   └── pubspec.yaml
│
├── backend/
│   ├── src/
│   │   ├── models/
│   │   │   ├── Event.js
│   │   │   ├── Participant.js
│   │   │   └── Attendance.js
│   │   ├── routes/
│   │   │   ├── auth.routes.js
│   │   │   ├── participant.routes.js
│   │   │   └── attendance.routes.js
│   │   ├── controllers/
│   │   ├── middleware/
│   │   ├── services/
│   │   ├── config/
│   │   └── server.js
│   ├── .env.example
│   └── package.json
│
├── google-apps-script/
│   └── sync-google-form.js
│
└── docs/
    └── phase-1-plan.md
```

---

# 27. Phase 1 Development Tasks

## Step 1 — Prepare registration data

Create Google Form with fields:

```text
SRN
Full Name
Email
Branch
```

Connect it to Google Sheets.

Export/import a test set.

---

## Step 2 — Set up MongoDB

Create MongoDB Atlas database.

Create:

```text
events
participants
attendance
```

collections.

Add unique indexes.

---

## Step 3 — Build backend

Implement:

- authentication
- participant lookup
- attendance endpoint
- duplicate protection
- statistics
- attendance records endpoint
- registration sync endpoint

Test everything with Postman/Insomnia before connecting Flutter.

---

## Step 4 — Build Flutter scanner

Implement:

- login
- camera scanner
- 1D barcode detection
- SRN normalization
- backend lookup
- attendance confirmation
- manual SRN entry

---

## Step 5 — Add view-only records

Implement:

- total present
- registered count
- walk-in count
- recent scans
- search
- filters

Do NOT implement edit/delete.

---

## Step 6 — Add Google Form walk-in flow

Implement:

```text
Not registered
      ↓
Show Google Form QR
      ↓
Student submits form
      ↓
Google Apps Script / sync
      ↓
MongoDB
      ↓
Check again
      ↓
Mark attendance
```

---

## Step 7 — Add offline queue

After the basic online version works:

- local scan queue
- connectivity detection
- automatic sync
- duplicate-safe sync

Do not start with offline support before the normal flow works.

---

# 28. Phase 1 Testing Checklist

Test with REAL college ID cards.

## Barcode

- [ ] CSE barcode
- [ ] ECE barcode
- [ ] EEE barcode
- [ ] Other branches
- [ ] Different lighting
- [ ] Slightly damaged ID card
- [ ] Fast consecutive scans

## SRN

- [ ] Valid SRN
- [ ] Lowercase SRN
- [ ] SRN with accidental spaces
- [ ] Invalid SRN
- [ ] Unknown SRN
- [ ] Manual entry

## Registration

- [ ] Pre-registered student
- [ ] Walk-in student
- [ ] Not registered
- [ ] Duplicate Google Form submission

## Attendance

- [ ] First scan
- [ ] Duplicate scan
- [ ] Two devices scanning same student
- [ ] Offline scan
- [ ] Sync after reconnecting

## App

- [ ] Login
- [ ] Logout
- [ ] Scanner
- [ ] Manual SRN
- [ ] Attendance records
- [ ] Search
- [ ] Statistics
- [ ] No edit/delete controls

---

# 29. Phase 2 — Certificate System

Do this only after attendance is stable.

## Certificate eligibility

After event:

```text
Attendance finalized
        ↓
attended = true
        ↓
certificateEligible = true
```

Student visits:

```text
CNEST website
    ↓
Certificate Portal
```

Enters SRN.

Backend checks:

```text
SRN exists?
Registered?
Attended?
Certificate eligible?
```

Then send OTP to registered email.

```text
SRN
 ↓
Registered Email
 ↓
OTP
 ↓
Verification
```

The participant does NOT enter their name manually.

---

# 30. Certificate Template System

Create a fixed master certificate design.

The visual design can be made in Canva/Figma and exported as a background image.

Use placeholders for dynamic data:

```text
{{PARTICIPANT_NAME}}
{{SRN}}
{{EVENT_NAME}}
{{EVENT_DATE}}
{{VENUE}}
{{CERTIFICATE_ID}}
```

Backend obtains the real values from MongoDB.

Example:

```text
{{PARTICIPANT_NAME}}
        ↓
Sushil Shashidhar Chandaragi
```

Do not let the participant supply the certificate name.

The database is the authority.

---

# 31. Certificate PDF generation

Recommended backend approach:

```text
HTML/CSS certificate template
           ↓
Inject MongoDB data
           ↓
Render HTML
           ↓
Puppeteer
           ↓
PDF
```

The system can dynamically adjust the name font size for long names.

---

# 32. Certificate verification

Generate a unique ID:

```text
F26-000721
```

Store:

```text
certificateId
eventId
srn
generatedAt
pdfLocation
```

Verification page:

```text
cnest.kletech.ac.in/verify/F26-000721
```

Displays:

```text
✅ VALID CERTIFICATE

Participant:
Sushil Shashidhar Chandaragi

Event:
FLEDGE '26

Date:
8 October 2026
```

---

# 33. Phase 3 — Automation & Admin

Possible additions:

- Admin dashboard
- CSV export
- attendance analytics
- registration vs attendance statistics
- certificate generation history
- certificate email automation
- resend email
- certificate verification page
- multiple events using same system
- multiple CNEST teams/operators
- audit logs

---

# 34. Event-Day Operating Plan

## Before students arrive

1. Ensure MongoDB is reachable.
2. Sync Google Form registrations.
3. Download/cache registration data to attendance phones.
4. Login each phone.
5. Assign device IDs:
   - GATE-A-01
   - GATE-A-02
   - GATE-B-01
6. Test 5–10 real college ID cards.
7. Verify Google Form QR opens correctly.

## During registration/entry

```text
Student shows ID
       ↓
Scan barcode
       ↓
Registered?
   ↙       ↘
 YES       NO
  ↓         ↓
Attend    Show Form QR
           ↓
      Student registers
           ↓
       Sync/check
           ↓
        Attend
```

## After event

1. Stop attendance scanning.
2. Ensure all offline scans are synced.
3. Compare counts.
4. Export attendance.
5. Finalize certificate eligibility.
6. Begin Phase 2 certificate processing.

---

# 35. Critical Design Decisions

### Decision 1

**SRN is the unique identity.**

Do not create another student ID for the app.

### Decision 2

**Barcode is the fastest attendance input.**

Manual SRN is a fallback.

### Decision 3

**Google Form is the registration source.**

Google Sheets stores responses.

MongoDB stores the application-side participant records.

### Decision 4

**Names are always fetched from the database.**

Never ask participants to enter their certificate name.

### Decision 5

**The Flutter app can create attendance but cannot edit it.**

Corrections must be performed by authorized admin tooling later.

### Decision 6

**Certificate generation is separate from event-day attendance.**

Do not overload the event-day attendance app with certificate functionality.

---

# 36. Phase 1 Definition of Done

Phase 1 is considered complete only when:

```text
✅ College ID barcode can be scanned
✅ Full SRN is correctly extracted
✅ Manual SRN fallback works
✅ Registered student is identified
✅ Unregistered student is identified
✅ Google Form QR can be shown
✅ Walk-in registration can enter the system
✅ Attendance can be marked
✅ Duplicate attendance is prevented
✅ Multiple devices work
✅ Attendance records can be viewed
✅ Records are read-only in the app
✅ Counts are visible
✅ Offline queue works or has been explicitly tested
✅ Operator authentication works
✅ No MongoDB credentials are present in the mobile app
```

---

# 37. What Claude Should Build First

When implementing this project, do NOT build all three phases at once.

Start with **Phase 1 only**.

Recommended implementation sequence:

```text
1. MongoDB models
       ↓
2. Node/Express backend
       ↓
3. Test API independently
       ↓
4. Flutter login
       ↓
5. Barcode scanner
       ↓
6. Participant lookup
       ↓
7. Attendance marking
       ↓
8. Manual SRN fallback
       ↓
9. Read-only attendance records
       ↓
10. Google Form walk-in flow
       ↓
11. Registration sync
       ↓
12. Offline queue
       ↓
13. Real-device testing
```

Do not start Phase 2 until Phase 1 passes real-device testing with actual KLE ID cards.

---

# 38. Final Recommended User Flow

```text
                 STUDENT ARRIVES
                        │
                        ▼
               Show KLE ID Card
                        │
                        ▼
                  Scan Barcode
                        │
                        ▼
                   Full SRN
                        │
                        ▼
             Check MongoDB / Cache
                  │           │
                FOUND      NOT FOUND
                  │           │
                  ▼           ▼
             Registered?   Show Google
                  │         Form QR
             YES  │           │
                  ▼           ▼
              Mark        Student fills
             Present      Google Form
                  │           │
                  │         Sync
                  │           │
                  └──────┬────┘
                         ▼
                   Mark Present
                         │
                         ▼
                 View-only records
                         │
                         ▼
                    EVENT ENDS
                         │
                         ▼
                Phase 2 Certificate
```

---

# 39. Guiding Principle

Keep the event-day experience extremely fast:

> **Show ID → Scan → Confirm → Move on.**

Everything else should happen behind the scenes.

The attendance operator should not have to type names, search spreadsheets, edit records, or manually prepare certificates.

The system should use:

```text
Barcode → SRN
SRN → Participant
Participant → Registration
SRN + Event → Attendance
Attendance → Eligibility
Eligibility → Certificate
```

That makes the system reusable for future CNEST events instead of being a one-time FLEDGE '26 tool.
