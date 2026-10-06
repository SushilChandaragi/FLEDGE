# CNEST FLEDGE '26 — Attendance System (Phase 1)

Production attendance management system for **CNEST TBI 2.0 FLEDGE '26 Orientation Programme** (KLE Technological University, Belagavi).

Built with **Flutter (Mobile Client)**, **Node.js + Express (Backend REST API)**, **MongoDB Atlas (Database)**, and **Google Forms / Sheets (Registration Sync)**.

---

## Quick Start Guide

### 1. Backend Setup

1. Open a terminal in the `backend` folder:
   ```bash
   cd backend
   npm install
   ```

2. Generate or verify `.env`:
   ```bash
   node scripts/make-env.js
   ```
   *Your `.env` is configured with your MongoDB Atlas cluster URI, a secure random JWT secret, and a sync secret.*

3. Seed the Event & Create Operators:
   ```bash
   # Initialize the FLEDGE '26 Event
   npm run seed:event

   # Create an Attendance Operator for Gate 1
   npm run operator:create -- gate1 fledge2026 "Gate 1 Operator" attendance_operator

   # Create an Admin Operator
   npm run operator:create -- admin admin2026 "Lead Coordinator" admin
   ```

4. Import Pre-registered Students (Optional / Initial Load):
   ```bash
   node scripts/import-participants.js scripts/sample-participants.csv
   ```

5. Run Automated Tests:
   ```bash
   npm test
   ```

6. Start the Backend Server:
   ```bash
   npm start
   # Or for development with auto-reload:
   npm run dev
   ```
   *Server listens on `http://localhost:4000` (or configured PORT).*

---

### 2. Flutter Mobile App Setup & Run

1. Open a terminal in the `attendance-app` folder:
   ```bash
   cd attendance-app
   flutter pub get
   ```

2. Run Tests & Lint:
   ```bash
   flutter test
   flutter analyze
   ```

3. Run on Connected Android Device or Emulator:
   ```bash
   # When testing against local backend on Android Emulator:
   flutter run

   # When testing on physical Android phone connected via USB / Wi-Fi:
   # (Replace 192.168.1.50 with your computer's local Wi-Fi IP address)
   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:4000
   ```

4. Build Release Android APK:
   ```bash
   # Debug APK (for instant sideloading and testing on volunteer phones):
   flutter build apk --debug --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN.com

   # Production Release APK:
   flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN.com
   ```
   *Output APK will be generated at:* `attendance-app/build/app/outputs/flutter-apk/app-release.apk`

---

## 3. Google Form & Google Apps Script Setup (Real-Time Walk-ins)

1. Create a Google Form with fields:
   - **SRN** (Required)
   - **Full Name** (Required)
   - **Email** (Optional)
   - **Branch** (Optional)
2. Link the Form to a Google Sheet (**Responses** -> **Link to Sheets**).
3. In the Google Sheet, navigate to **Extensions** -> **Apps Script**.
4. Paste the content of [`google-apps-script/sync-google-form.js`](./google-apps-script/sync-google-form.js).
5. Update `BACKEND_URL` and `SYNC_SECRET` (matching `REGISTRATION_SYNC_SECRET` in backend `.env`).
6. Set up the trigger in Apps Script:
   - Click **Triggers** (Alarm Clock icon on the left).
   - Click **+ Add Trigger**.
   - Choose `onFormSubmit`, Event Source: `From spreadsheet`, Event Type: `On form submit`.
   - Click Save.
7. *Backfill:* You can run the `syncAllExistingRows()` function inside Apps Script at any time to sync all historical responses to MongoDB.

---

## 4. Operator Workflow on Event Day

1. **Sign In:**
   - **Operator ID:** `gate1`
   - **Password:** `fledge2026`
   - **Device ID:** `GATE-A-01` (unique for each phone)
2. **Scan College ID Barcode:**
   - Point the camera at the 1D barcode on the student ID card.
   - The barcode value is treated directly as the student's full SRN (e.g. `02FE23BCS136`).
   - **Success:** Shows green confirmation banner with Name, SRN, and Registration Type, then automatically resumes scanning.
   - **Duplicate Scan:** Shows warning that attendee was already marked present (with original scan time & device ID).
   - **Not Registered:** Shows red notice with **[Show QR]** (displays Google Form QR) and **[Check Again]**.
3. **Manual SRN Fallback:**
   - If ID card is scratched/unreadable, tap **"Enter SRN Manually"**, type SRN, and tap **"Check"**. Automatically converts to uppercase and normalizes spaces.
4. **Offline Resilience:**
   - If Wi-Fi drops, scans for cached participants are saved locally to SQLite with `PENDING SYNC` status and automatically synced with the server once connectivity resumes.
5. **View-Only Records:**
   - Tap **"View Attendance"** to see live counts, search by name or SRN, and filter by pre-registered / walk-in. **No edit or delete buttons exist**, ensuring data integrity.

---

## 5. Testing Checklist

- [x] **Registered CSE Student:** Barcode / SRN lookup succeeds, marks attendance with status `pre_registered`.
- [x] **Other Branches (ECE, EEE, ME, Civil, AI):** Barcodes from various branches parse as opaque SRN strings without branch hardcoding.
- [x] **Duplicate Prevention:** Scanning same student on Phone A and Phone B produces `already_attended` (tested with 12 concurrent requests).
- [x] **Manual SRN Entry:** Handles lowercase (`02fe23bcs136`) and whitespace (` 02FE23BCS136 `).
- [x] **Walk-in Flow:** Unregistered student scans QR -> submits Google Form -> volunteer clicks "Check Again" -> marked as `walk_in`.
- [x] **Offline Cache & Sync:** Scans queued in local SQLite when offline and flushed to MongoDB with original timestamp.
- [x] **Security:** JWT authentication enforced; sensitive routes reject unauthorized clients; zero client exposure to raw MongoDB credentials.
- [x] **Immutability:** Attendance records are strictly append-only (no PUT/PATCH/DELETE endpoints).

---

## 6. Project Structure

```
FLEDGE/
├── backend/                         # Node.js + Express Backend
│   ├── src/
│   │   ├── config/                  # DB connection and env loader
│   │   ├── controllers/             # Request handlers
│   │   ├── middleware/              # JWT auth, Sync auth, Zod validation
│   │   ├── models/                  # Mongoose models (Event, Participant, Attendance, Operator)
│   │   ├── routes/                  # REST API routes
│   │   ├── services/                # Business logic
│   │   ├── utils/                   # SRN normalization and error classes
│   │   ├── app.js
│   │   └── server.js
│   ├── scripts/                     # Seed event, create operator, import CSV
│   ├── test/                        # Node.js integration tests (npm test)
│   ├── .env.example
│   └── package.json
│
├── attendance-app/                  # Flutter Mobile Client
│   ├── lib/
│   │   ├── config/                  # App constants & timeouts
│   │   ├── models/                  # Data classes (Event, Stats, Record, Outcome)
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── scanner_screen.dart
│   │   │   ├── manual_srn_screen.dart
│   │   │   ├── registration_qr_screen.dart
│   │   │   └── attendance_records_screen.dart
│   │   ├── services/                # ApiClient, LocalDb (SQLite), AttendanceService, SyncService
│   │   ├── state/                   # AppState ChangeNotifier
│   │   ├── theme/                   # Calm, cool-blue CNEST typography and tokens
│   │   ├── utils/                   # SRN regex and formatting
│   │   ├── widgets/                 # StatusBanner, BrandHeader, StatFigure
│   │   └── main.dart
│   ├── assets/fonts/                # Inter font family
│   ├── test/                        # Flutter unit tests
│   └── pubspec.yaml
│
├── google-apps-script/
│   └── sync-google-form.js          # Google Form -> Backend webhook sync
└── docs/
    └── ARCHITECTURE_AND_API.md      # API specifications and database schemas
```
