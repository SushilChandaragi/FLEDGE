# FLEDGE26 — Event Attendance Management System

A production-grade, multi-device attendance management system designed for **CNEST TBI 2.0 FLEDGE '26** and multi-event university programmes (KLE Technological University, Belagavi).

Built with **Flutter (Android Mobile App)**, **Node.js + Express (Backend REST API on Render)**, **MongoDB Atlas (Cloud Database)**, and **Google Forms / Sheets (Live Registration Webhook)**.

---

## 📱 User & Volunteer Guide (Event Day Workflow)

### 1. Signing In to the App
1. Install and open the **FLEDGE26** app on your Android phone.
2. Enter your credentials:
   - **Operator ID:** `gate1` *(or your assigned operator ID)*
   - **Password:** `fledge26`
   - **Device ID:** `GATE-01` *(or any identifier, e.g. `PHONE-A`, `COUNTER-2`)*
3. Tap **Sign in**.

---

### 2. Scanning Student ID Barcodes
1. On the Home screen, tap **Start scanning**.
2. Aim the camera at the 1D barcode on the student's KLE Tech ID card.
3. The app scans the barcode as the full student SRN (e.g. `02FE23BCS136`):
   - 🟢 **Success (Green Banner):** Displays Student Name, SRN, and "Pre-registered" or "Walk-in". The scanner automatically resets after 1.5 seconds for the next student.
   - 🟡 **Already Marked (Amber Banner):** Indicates this student has **already entered** (prevents duplicate entry across multiple gates).
   - 🔴 **Not Registered (Red Banner):** Indicates the student is not in the system. Tap **Show QR** so the student can scan your screen to fill the Google Form, then tap **Check Again** once submitted.

---

### 3. Manual SRN Entry (Damaged / Unreadable Barcode)
1. If an ID card barcode is scratched or camera cannot read it, tap **Enter SRN** (or **Manual SRN Entry**).
2. Type the student's SRN (e.g. `02fe23bcs136`).
3. The app automatically capitalizes and trims whitespace, checks the server, and marks attendance.

---

### 4. Viewing Live Records & Form Responses
Tap **View attendance** on the Home screen to view two live tabs:
- **Tab 1: Total Scanned (Present):** Real-time count of total students present at the venue, search bar by SRN or Name, and filters for Pre-registered vs Walk-in attendees.
- **Tab 2: Registered List (Form):** Complete directory of students synced from the Google Form with their Branch, Email, and registration timestamp.

---

### 5. Offline Operation
- If Wi-Fi or mobile data drops, the app switches to **Offline Mode**.
- Scans are validated against a local SQLite snapshot downloaded to the phone, stored in a local pending queue, and automatically synchronized to MongoDB Atlas as soon as internet connectivity resumes.

---

## 🛠️ Coordinator & Admin Management Guide

### A. Resetting Attendance on Event Day Morning
To clear test scans before attendees arrive:
```bash
cd backend
npm run reset:attendance
```
Type `YES` when prompted. This clears only the check-in timestamps in MongoDB; **it will NEVER delete or modify your Google Sheet responses**.

---

### B. Exporting the Final Present Attendee List to CSV
At the end of the event, export the verified list of all attendees present:
```bash
cd backend
npm run export:present
```
*(Or specify a custom filename: `npm run export:present fledge26_final_present.csv`)*

**Exported CSV Columns:**
`Sl No`, `SRN`, `Student Name`, `Branch`, `Email`, `Attendance Time (IST)`, `Registration Status`, `Operator ID`, `Device ID`.

You can also download this directly via browser / API:
`GET https://YOUR_BACKEND_URL/api/events/FLEDGE26/attendance/export` (with Operator Bearer token).

---

### C. Re-importing Pre-Registered Students via CSV
To bulk load participants from an Excel / CSV export of your Google Sheet:
```bash
cd backend
node scripts/import-participants.js path/to/participants.csv
```

---

## 🔁 Using This App for Other Events

This architecture is multi-event ready. To run this app for another event (e.g., `HACKATHON26`, `INDUCTION27`):

1. **Bootstrap the New Event in MongoDB:**
   In `backend/.env` (or Render Environment Variables), set:
   ```env
   EVENT_ID=HACKATHON26
   REGISTRATION_FORM_URL=https://forms.gle/YOUR_NEW_FORM_URL
   ```
   Run:
   ```bash
   npm run seed:event
   ```

2. **Configure the Google Sheet Webhook:**
   Link your new event's Google Form to a new Google Sheet, paste `google-apps-script/sync-google-form.js`, update `BACKEND_URL` and `SYNC_SECRET`, and add the `onFormSubmit` trigger.

3. **Build APK for the New Event:**
   ```bash
   flutter build apk --release --dart-define=EVENT_ID=HACKATHON26 --dart-define=API_BASE_URL=https://your-backend.onrender.com
   ```

---

## 🏗️ Technical Architecture & Security

### System Overview
```
┌─────────────────────────┐         ┌─────────────────────────┐
│ Google Form / Sheet     │         │ Flutter Android Client  │
│ (Attendee Registration) │         │ (Camera Barcode + UI)   │
└────────────┬────────────┘         └────────────┬────────────┘
             │ Webhook POST                      │ HTTPS + JWT
             ▼                                   ▼
┌─────────────────────────────────────────────────────────────┐
│               Node.js + Express Backend REST API             │
│   - Rate Limiter, Helmet Security, Zod Input Validation     │
│   - Atomic Upsert & Compound Unique Indexes                 │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                 MongoDB Atlas Cloud Database                 │
│   - `operators`    : Bcrypt hashed credentials & roles       │
│   - `events`       : Event bootstrap & Google Form QR config │
│   - `participants` : Pre-registered & walk-in students       │
│   - `attendance`   : Append-only event check-ins             │
└─────────────────────────────────────────────────────────────┘
```

### Security & Data Integrity
1. **Zero Client DB Access:** Mobile devices never communicate with MongoDB directly; all requests pass through authenticated Node.js REST endpoints with JWT validation.
2. **Duplicate Attack Protection:** MongoDB enforces a compound unique index `{ eventId: 1, srn: 1 }` on the `attendance` collection, making duplicate check-ins mathematically impossible even with 20+ operators scanning simultaneously.
3. **Append-Only Immutability:** No `PUT`, `PATCH`, or `DELETE` endpoints exist for attendance records over public HTTP.
4. **Offline Delta Sync:** Mobile clients track snapshot timestamps (`updatedSince`) and UUID cursors to sync delta changes without downloading the full dataset repeatedly.

---

## 🚀 Deployment & Installation

### Live Backend URL
`https://cnest-fledge-attendance.onrender.com`

### Building the Mobile APK
```bash
cd attendance-app
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```
Output APK: `attendance-app/build/app/outputs/flutter-apk/app-release.apk`
