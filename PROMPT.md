You are the lead software engineer and product designer for the CNEST FLEDGE '26 Attendance System.

I have provided a planning document named:

CNEST_FLEDGE26_Attendance_Planning_for_Claude.md

READ THAT DOCUMENT COMPLETELY BEFORE WRITING OR MODIFYING CODE.

Your job is to IMPLEMENT PHASE 1 ONLY:
ATTENDANCE MANAGEMENT.

Do NOT implement the certificate generation system yet. Do not jump ahead to Phase 2 unless creating clearly isolated backend/data structures that will make Phase 2 easier later.

==================================================
1. PRODUCT GOAL
==================================================

Build a production-quality attendance system for:

CNEST TBI 2.0
FLEDGE '26 – Orientation Programme

Event:
8 October 2026
9:30 AM
KLE Tech Auditorium
KLE Technological University, Belagavi

The system should allow CNEST volunteers to quickly mark attendance by scanning the barcode on a KLE student ID card.

IMPORTANT:

The barcode already contains the COMPLETE student SRN.

Example:

02FE23BCS136

Therefore:

barcode value = SRN

Do NOT try to derive the branch from the barcode.
Do NOT build unnecessary barcode parsing logic.
Treat the complete SRN as the unique student identifier.

CSE, ECE, EEE, ME, etc. can have different SRN formats, but the app should simply treat the scanned value as a string.

==================================================
2. REQUIRED TECH STACK
==================================================

Mobile App:
- Flutter
- Dart
- mobile_scanner for barcode scanning
- Dio or http for API communication
- Isar/Hive/SQLite for local offline scan queue
- connectivity_plus for network awareness

Backend:
- Node.js
- Express
- Mongoose
- JWT authentication
- dotenv
- proper validation
- HTTPS-compatible API design

Database:
- MongoDB Atlas

Registration:
- Google Form
- Google Sheets as the registration response source
- Google Apps Script or another simple integration to sync new Google Form submissions into MongoDB

Do not replace MongoDB with Supabase.

==================================================
3. PHASE 1 SCOPE
==================================================

PHASE 1 IS ONLY ATTENDANCE.

Required capabilities:

1. Operator login
2. Barcode scanning
3. Automatic SRN extraction
4. Participant lookup
5. Registered vs not-registered detection
6. Attendance marking
7. Duplicate attendance prevention
8. Manual SRN entry fallback
9. Google Form QR display for unregistered walk-ins
10. Ability to retry/check registration after the student submits the Google Form
11. Read-only attendance records
12. Search attendance records
13. Attendance statistics
14. Support multiple attendance devices
15. Device ID tracking
16. Reasonable offline support
17. Sync pending attendance when connectivity returns
18. Secure API communication
19. No editing/deleting attendance from the mobile app

==================================================
4. ATTENDANCE USER FLOW
==================================================

The event-day process should be extremely fast.

Desired flow:

Student arrives
↓
Shows college ID
↓
Volunteer scans barcode
↓
SRN is extracted
↓
System checks participant database
↓
If registered:
    mark attendance
    show success
↓
If not registered:
    show "Not Registered"
    show Google Form QR
    student fills form
    registration gets synced
    volunteer checks SRN again
    attendance gets marked

The golden rule is:

SHOW ID → SCAN → CONFIRM → MOVE ON

The operator should not need to type names, manually search spreadsheets, or edit student information.

==================================================
5. MANUAL SRN FALLBACK
==================================================

Barcode scanning will not always work.

Below the scanner, provide a clear and professional fallback:

"Barcode not working?"

[ Enter SRN Manually ]

This opens a manual SRN entry screen/dialog.

The system must:

- trim spaces
- convert to uppercase
- validate that the field is not empty
- send the SRN to the backend
- use exactly the same lookup and attendance logic as barcode scanning

Example:

02fe23bcs136

should normalize to:

02FE23BCS136

Do not duplicate business logic between barcode and manual input.

Both should eventually call the same attendance service.

==================================================
6. REGISTRATION FLOW
==================================================

There are two types of attendees:

A. Pre-registered
B. Walk-in

Pre-registration comes from the CNEST Google Form.

If a scanned SRN exists in MongoDB:

Show:

REGISTERED

Name:
<Student Name>

SRN:
<Student SRN>

Registration:
Google Form

Then mark attendance.

If SRN does NOT exist:

Show:

NOT REGISTERED FOR FLEDGE '26

SRN:
<Student SRN>

The student has not registered yet.

Then provide:

[ SHOW REGISTRATION QR ]

The QR opens the CNEST Google Form.

IMPORTANT:

The QR code is ONLY for opening the registration Google Form.

The college ID card itself uses a barcode, not QR.

After the student completes the form, the system should provide:

[ CHECK REGISTRATION AGAIN ]

This should re-query the backend.

Once the registration has reached MongoDB:

Student becomes eligible to be marked present.

==================================================
7. GOOGLE FORM DATA
==================================================

The Google Form should collect at minimum:

- SRN
- Full Name
- Email
- Branch

Google Form responses go into Google Sheets.

Build the system so that new form responses can be synchronized into MongoDB.

Recommended architecture:

Google Form
↓
Google Sheets
↓
Google Apps Script on form submit
↓
Secure backend endpoint
↓
MongoDB participants collection

Use UPSERT by SRN.

Never create duplicate participant records for the same SRN.

The database should be the application's source of truth after synchronization.

==================================================
8. DATABASE DESIGN
==================================================

Create an Event model.

Example:

{
  eventId: "FLEDGE26",
  eventName: "FLEDGE '26",
  date: "2026-10-08",
  time: "09:30",
  venue: "KLE Tech Auditorium, Belagavi",
  registrationFormUrl: "...",
  active: true
}

Create a Participant model.

Example:

{
  srn: "02FE23BCS136",
  name: "Sushil Shashidhar Chandaragi",
  email: "student@example.com",
  branch: "CSE",
  registration: {
    registered: true,
    source: "google_form",
    registeredAt: "..."
  },
  createdAt: "...",
  updatedAt: "..."
}

Create an Attendance model.

Example:

{
  eventId: "FLEDGE26",
  srn: "02FE23BCS136",
  attendanceStatus: "present",
  registrationStatus: "pre_registered",
  scannedAt: "...",
  deviceId: "GATE-A-01"
}

Use:

UNIQUE(eventId + srn)

to prevent duplicates.

The backend must enforce duplicate protection even if two devices scan the same student at nearly the same time.

==================================================
9. MOBILE APP SCREENS
==================================================

Build only the screens actually needed.

Screen 1:
LOGIN

Screen 2:
HOME / ATTENDANCE DASHBOARD

Show:

CNEST
FLEDGE '26
Attendance

Registered
Present
Walk-ins

[ Start Scanning ]

[ View Attendance ]

Screen 3:
SCANNER

Large camera scanning area.

Keep it visually simple.

Below scanner:

Barcode not working?

[ Enter SRN Manually ]

Also show a small recent scan indicator.

Screen 4:
SCAN RESULT

SUCCESS:
✅ Attendance Marked

Student Name
SRN
Registration type
Time

DUPLICATE:
⚠ Already Marked

Student Name
SRN
Original attendance time

NOT REGISTERED:
⚠ Not Registered

SRN

[ Show Registration QR ]
[ Check Registration Again ]

Screen 5:
MANUAL SRN

Simple input
[ Enter SRN ]

[ Check ]

Screen 6:
ATTENDANCE RECORDS

Read-only.

Show:

- total present
- registered attendees present
- walk-ins
- recent scans
- search by SRN
- search by name
- filter pre-registered / walk-in

NO EDIT BUTTON.
NO DELETE BUTTON.

Operators must not be able to modify existing attendance records.

==================================================
10. UI / UX DIRECTION
==================================================

THIS PART IS EXTREMELY IMPORTANT.

The application must NOT look like a generic AI-generated app.

Avoid:
- excessive gradients
- glassmorphism
- liquid glass
- giant rounded cards everywhere
- floating blobs
- excessive animations
- unnecessary illustrations
- neon colors
- rainbow gradients
- excessive shadows
- oversized typography
- dashboard-card spam
- decorative UI that has no functional purpose
- trendy "AI SaaS" styling
- excessive pill buttons
- fake futuristic elements

Do NOT use liquid glass.

Do NOT create complex visual effects.

The design should look like a polished real-world product used by a university technology/startup organization.

==================================================
11. VISUAL STYLE
==================================================

Take inspiration from the Claude app's design philosophy:

- excellent hierarchy
- calm interface
- lots of breathing room
- clear typography
- restrained components
- minimal clutter
- strong content hierarchy
- very clear primary action

BUT:

Do NOT clone Claude's UI.
Do NOT reproduce its branding.
Do NOT copy its exact visual styling.

Instead create a CNEST-specific identity.

Color direction:

COOL BLUE.

Suggested palette:

Primary:
#2563EB

Dark blue:
#1E3A8A

Very dark text:
#0F172A

Secondary text:
#64748B

Light blue:
#EFF6FF

Background:
#F8FAFC

Surface:
#FFFFFF

Success:
#16A34A

Warning:
#D97706

Error:
#DC2626

Use colors sparingly.

The interface should remain mostly white / off-white with blue accents.

Do not make the entire app blue.

==================================================
12. TYPOGRAPHY
==================================================

Typography should feel premium and professional.

Prefer:

Inter

or:

Manrope

or another high-quality modern sans-serif.

Use a consistent type scale.

Example:

App title:
24–28px / semibold

Section title:
18–20px / semibold

Body:
14–16px

Metadata:
12–13px

Avoid excessive bold text.

Avoid all-caps UI text except where genuinely useful.

Use font weight intentionally.

==================================================
13. DESIGN LANGUAGE
==================================================

Use:

- subtle 8–12px corner radius
- thin borders
- restrained shadows
- clean white surfaces
- excellent spacing
- compact professional controls
- strong alignment
- consistent padding
- clear active states
- clear success/error states

Buttons should look like real product controls.

Primary CTA:

Blue filled button.

Secondary:

White / transparent button with border.

Danger:

Use restrained red only when necessary.

Cards should be used only when content actually benefits from grouping.

Do not put every piece of content inside a card.

==================================================
14. SCANNER SCREEN DESIGN
==================================================

The scanner is the most important screen.

It should prioritize speed.

Recommended hierarchy:

Top:
CNEST
FLEDGE '26

Middle:
Large camera scanner

Below:
"Scan college ID barcode"

Fallback:
Barcode not working?
[ Enter SRN manually ]

Bottom:
Recent attendance / present count

The scanning area should be functional rather than decorative.

When a barcode is detected:

- immediately stop processing duplicate detections
- show result
- prevent accidental repeated scans for a short configurable cooldown
- then automatically return to scanning

The operator should not have to continuously press "scan".

==================================================
15. SUCCESS STATE
==================================================

Make success extremely obvious.

Example:

--------------------------------
✓ Attendance Marked

Sushil Shashidhar Chandaragi
02FE23BCS136

Pre-registered
09:42 AM
--------------------------------

Then return to scanner quickly.

Do not create a huge animated success screen.

==================================================
16. NOT REGISTERED STATE
==================================================

Example:

--------------------------------
Not registered

02FE23BCS200

This attendee does not have a
FLEDGE '26 registration.

Ask them to register using
the CNEST Google Form.

[ Show Registration QR ]

[ Check Again ]
--------------------------------

QR display can be on a clean dedicated screen.

Do not make the QR itself decorative.

==================================================
17. ATTENDANCE RECORDS
==================================================

This screen should feel like a professional internal operations tool.

Example:

Attendance
FLEDGE '26

431 Present
23 Walk-ins

Search
[ SRN or name ]

Filters
All | Pre-registered | Walk-in

Then a clean list/table-like layout.

Each row:

Name
SRN
Time
Registration type

Do not overuse cards.

The screen is VIEW ONLY.

==================================================
18. PERFORMANCE
==================================================

This system may be used for hundreds of students arriving quickly.

Optimize for fast scanning and fast response.

Requirements:

- scanner should remain responsive
- avoid unnecessary API requests
- debounce duplicate barcode detections
- cache participant data where appropriate
- use pagination for large attendance lists
- never load all records into memory unnecessarily
- API responses should be small
- attendance writes should be atomic
- duplicate attendance should be handled server-side

==================================================
19. OFFLINE SUPPORT
==================================================

Implement reasonable offline support.

Before the event, the app should be able to cache a read-only participant snapshot.

When scanning:

If online:
    validate against backend
    mark attendance

If temporarily offline:
    queue the scan locally
    indicate pending sync
    sync automatically when connectivity returns

IMPORTANT:

Do not falsely claim server confirmation when the device is offline.

Clearly distinguish:

SYNCED
vs
PENDING SYNC

Example:

✓ Attendance synced

or:

✓ Attendance recorded locally
Waiting for sync

This distinction is important.

==================================================
20. MULTIPLE DEVICES
==================================================

The system must support multiple attendance phones.

Each device has a unique device ID:

GATE-A-01
GATE-A-02
GATE-B-01

Every attendance record stores deviceId.

The duplicate rule is global across all devices.

Example:

Phone A scans:
02FE23BCS136

Then Phone B scans the same student.

Phone B must receive:

ALREADY ATTENDED

rather than creating a second record.

==================================================
21. AUTHENTICATION
==================================================

Attendance operators must authenticate.

Do not leave attendance endpoints publicly writable.

Use:

JWT authentication

Operator roles:

attendance_operator
admin

Phase 1 mobile app should primarily use attendance_operator.

Attendance operators can:

- scan
- manually enter SRN
- mark attendance
- view attendance
- view statistics
- show registration QR

Attendance operators cannot:

- edit attendance
- delete attendance
- edit participant master data
- generate certificates
- change event settings

Admin functionality can be added separately later.

==================================================
22. API DESIGN
==================================================

Create clean REST APIs.

Authentication:

POST /api/auth/login

Participants:

GET /api/participants/:srn

Attendance:

POST /api/events/:eventId/attendance
GET /api/events/:eventId/attendance
GET /api/events/:eventId/attendance/stats

Registration:

POST /api/registration/sync

Use proper HTTP status codes.

Validate all input server-side.

Do not trust Flutter input.

==================================================
23. CODE QUALITY
==================================================

This is NOT a prototype-only coding exercise.

Write maintainable code.

Requirements:

- clear folder structure
- separation of UI/business/data layers
- reusable Flutter services
- reusable widgets
- backend controllers/services/models separated
- environment variables
- meaningful error handling
- no hardcoded secrets
- no duplicated business logic
- comments only where useful
- no unnecessary abstraction
- no giant single-file implementation

Do not create fake/mock functionality and pretend it works.

If a service is not configured yet, clearly isolate it and provide setup instructions.

==================================================
24. ERROR HANDLING
==================================================

Handle:

- no internet
- backend unavailable
- invalid SRN
- unknown SRN
- duplicate attendance
- Google Form registration not yet synced
- timeout
- authentication expiry
- malformed barcode
- scanner permission denied
- camera unavailable
- database errors

User-facing error messages should be simple and understandable.

Do not expose stack traces to users.

==================================================
25. IMPORTANT DATA RULES
==================================================

Never ask the user to type the student's name during attendance.

The official participant name always comes from MongoDB.

Student information flow:

SRN
↓
Participant record
↓
Name / Email / Branch

This same principle will later be used for certificates.

Do NOT let students type their own certificate name.

==================================================
26. GOOGLE FORM WALK-IN EXPERIENCE
==================================================

When a person is not registered:

1. Scan SRN
2. Show "Not Registered"
3. Show Google Form QR
4. Person opens the form
5. Person submits:
   SRN
   Full Name
   Email
   Branch
6. Form response enters Google Sheet
7. Google Apps Script sends response to backend
8. MongoDB participant record is upserted
9. Operator presses "Check Again"
10. SRN is found
11. Attendance is marked

Make this flow easy and fast.

==================================================
27. IMPORTANT: DO NOT OVERBUILD
==================================================

This must be a simple event attendance product.

Do not add:

- analytics dashboards with charts unless actually necessary
- complex admin workflows
- notifications
- social login
- unnecessary roles
- AI features
- chat
- maps
- elaborate onboarding
- animations everywhere
- unnecessary settings
- certificate generation in Phase 1

Focus on reliability.

==================================================
28. IMPLEMENTATION PROCESS
==================================================

Follow this exact order:

STEP 1
Inspect the existing repository.

Do not blindly overwrite existing code.

Identify:
- current Flutter setup
- current backend
- current website
- package versions
- existing environment variables
- existing reusable components

STEP 2
Create/confirm architecture.

STEP 3
Implement MongoDB models.

STEP 4
Implement backend APIs.

STEP 5
Test backend independently.

STEP 6
Implement Flutter login.

STEP 7
Implement barcode scanner.

STEP 8
Implement participant lookup.

STEP 9
Implement automatic attendance marking.

STEP 10
Implement duplicate prevention.

STEP 11
Implement manual SRN fallback.

STEP 12
Implement view-only attendance records.

STEP 13
Implement Google Form QR flow.

STEP 14
Implement registration synchronization.

STEP 15
Implement offline queue and synchronization.

STEP 16
Test on real Android devices with actual KLE student ID cards.

==================================================
29. ACTUAL TESTING
==================================================

Do not stop when the code compiles.

Test the actual workflow.

Minimum test cases:

1. Registered CSE student
2. Registered student from another branch
3. Unknown SRN
4. Manual SRN
5. Lowercase SRN
6. SRN with accidental spaces
7. Duplicate scan
8. Same student scanned from second phone
9. Walk-in registration
10. Registration sync
11. Offline attendance
12. Reconnection and sync
13. Camera permission denied
14. Invalid barcode
15. Backend unavailable
16. Expired login token

Test actual physical barcode scanning with real KLE ID cards.

==================================================
30. UI ACCEPTANCE CRITERIA
==================================================

The application should feel like:

- a professional internal university system
- modern
- quiet
- premium
- trustworthy
- fast
- operational

It should NOT feel like:

- an AI-generated demo
- a Dribbble concept
- a startup landing page
- a gaming app
- a futuristic dashboard
- a glassmorphism showcase

Use restraint.

Professional design is more important than visual complexity.

==================================================
31. RESPONSIVENESS
==================================================

The Flutter app should work well on common Android phones.

Scanner screen must make excellent use of the camera viewport.

Buttons must be comfortable to tap.

Text must remain readable.

Do not assume flagship phone dimensions.

==================================================
32. FUTURE COMPATIBILITY
==================================================

Design the database so Phase 2 can later support:

- certificate eligibility
- email OTP
- certificate generation
- PDF generation
- certificate ID
- verification URL
- automated email

But DO NOT build those features now.

Do not compromise Phase 1 by mixing certificate logic into attendance code.

==================================================
33. DELIVERABLES
==================================================

At the end of implementation, provide:

1. Working Flutter attendance app
2. Working Node.js/Express backend
3. MongoDB schema/models
4. Google Form → MongoDB synchronization mechanism
5. `.env.example`
6. API documentation
7. Setup instructions
8. Android build/run instructions
9. Database setup instructions
10. Google Apps Script setup instructions
11. Operator login credentials setup instructions
12. Testing checklist
13. Known limitations

If possible, provide:

- debug APK build instructions
- production APK build instructions

==================================================
34. WHEN SOMETHING IS UNCLEAR
==================================================

Do not invent requirements silently.

First inspect the repository and existing implementation.

If a choice is needed, choose the simplest production-appropriate solution consistent with this plan.

Do not add technologies just because they are trendy.

Do not replace MongoDB with another database.

Do not replace Flutter with another mobile framework.

Do not implement certificates yet.

==================================================
35. FINAL INSTRUCTION
==================================================

Start by reading:

CNEST_FLEDGE26_Attendance_Planning_for_Claude.md

Then inspect the entire repository.

Then give me a concise implementation plan based on the ACTUAL repository structure you found.

After that, begin implementing PHASE 1.

Do not merely describe code.
Actually create/modify the files and make the feature work.

Prioritize:

RELIABILITY
SPEED
SIMPLICITY
PROFESSIONAL UI
REAL BARCODE SCANNING
CORRECT ATTENDANCE DATA

over visual gimmicks.

The final product should look like something a professional university tech team would actually deploy at the entrance of a large event.