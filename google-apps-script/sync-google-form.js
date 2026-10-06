/**
 * CNEST FLEDGE '26 — Google Apps Script for Real-Time Form Sync
 *
 * This script is attached to the Google Sheet collecting Google Form responses.
 * Whenever a student submits the Google Form (walk-in or pre-registration),
 * it sends their details directly to the Node.js / Express backend to upsert into MongoDB.
 *
 * Setup:
 * 1. In your Google Sheet linked to the Google Form, go to Extensions -> Apps Script.
 * 2. Paste this code into Code.gs.
 * 3. Update BACKEND_URL and SYNC_SECRET in the Script Properties (or directly in CONFIG below).
 * 4. Add an Installable Trigger:
 *    - Function: onFormSubmit
 *    - Event source: From spreadsheet
 *    - Event type: On form submit
 */

const CONFIG = {
  // Replace with your deployed backend HTTPS URL (e.g., https://fledge-api.yourdomain.com)
  BACKEND_URL: PropertiesService.getScriptProperties().getProperty('BACKEND_URL') || 'https://YOUR_BACKEND_URL_HERE',
  // Must match the REGISTRATION_SYNC_SECRET in your backend .env file
  SYNC_SECRET: PropertiesService.getScriptProperties().getProperty('SYNC_SECRET') || 'YOUR_SYNC_SECRET_HERE',
};

/**
 * Triggered on each Google Form submission.
 * Sends the new registrant to the backend.
 */
function onFormSubmit(e) {
  if (!e || !e.namedValues) {
    Logger.log('No namedValues found in event object.');
    return;
  }

  try {
    const namedValues = e.namedValues;

    // Helper to find field ignoring case or slight wording variations
    const getField = (...names) => {
      for (const key of Object.keys(namedValues)) {
        const lowerKey = key.trim().toLowerCase();
        for (const target of names) {
          if (lowerKey.includes(target.toLowerCase())) {
            const val = namedValues[key];
            return Array.isArray(val) ? val[0] : val;
          }
        }
      }
      return '';
    };

    const srn = getField('srn', 'usn', 'roll');
    const name = getField('full name', 'name', 'student name');
    const email = getField('email', 'mail');
    const branch = getField('branch', 'department', 'dept');
    const timestamp = getField('timestamp') || new Date().toISOString();

    if (!srn || !name) {
      Logger.log(`Missing required fields: SRN="${srn}", Name="${name}"`);
      return;
    }

    const payload = {
      srn: srn.trim(),
      name: name.trim(),
      email: email.trim(),
      branch: branch.trim(),
      source: 'google_form',
      submittedAt: new Date(timestamp).toISOString(),
    };

    const response = postToBackend(payload);
    Logger.log(`Synced ${srn}: ${response}`);
  } catch (error) {
    Logger.log(`Error in onFormSubmit: ${error.message}`);
  }
}

/**
 * Helper to post payload to backend /api/registration/sync
 */
function postToBackend(payload) {
  const url = `${CONFIG.BACKEND_URL.replace(/\/+$/, '')}/api/registration/sync`;
  const options = {
    method: 'post',
    contentType: 'application/json',
    headers: {
      'x-sync-secret': CONFIG.SYNC_SECRET,
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  };

  const res = UrlFetchApp.fetch(url, options);
  const code = res.getResponseCode();
  const body = res.getContentText();

  if (code >= 200 && code < 300) {
    return body;
  } else {
    throw new Error(`HTTP ${code}: ${body}`);
  }
}

/**
 * Manual utility function to backfill all existing rows from the active sheet into MongoDB.
 * Run this once from the Apps Script editor after setting up the backend.
 */
function syncAllExistingRows() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const data = sheet.getDataRange().getValues();
  if (data.length < 2) {
    Logger.log('No rows to sync.');
    return;
  }

  const header = data[0].map(h => String(h).trim().toLowerCase());
  const colIndex = (...names) => header.findIndex(h => names.some(n => h.includes(n)));

  const srnIdx = colIndex('srn', 'usn', 'roll');
  const nameIdx = colIndex('full name', 'name');
  const emailIdx = colIndex('email', 'mail');
  const branchIdx = colIndex('branch', 'department', 'dept');
  const timeIdx = colIndex('timestamp');

  if (srnIdx < 0 || nameIdx < 0) {
    Logger.log('Could not identify SRN and Name columns in sheet header.');
    return;
  }

  const registrations = [];
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const srn = String(row[srnIdx] || '').trim();
    const name = String(row[nameIdx] || '').trim();
    if (!srn || !name) continue;

    const email = emailIdx >= 0 ? String(row[emailIdx] || '').trim() : '';
    const branch = branchIdx >= 0 ? String(row[branchIdx] || '').trim() : '';
    const ts = timeIdx >= 0 && row[timeIdx] ? new Date(row[timeIdx]).toISOString() : new Date().toISOString();

    registrations.push({
      srn: srn,
      name: name,
      email: email,
      branch: branch,
      source: 'google_form',
      submittedAt: ts,
    });
  }

  Logger.log(`Found ${registrations.length} registrations to sync.`);

  // Send in batches of 100
  const BATCH_SIZE = 100;
  for (let i = 0; i < registrations.length; i += BATCH_SIZE) {
    const batch = registrations.slice(i, i + BATCH_SIZE);
    try {
      const res = postToBackend({ registrations: batch });
      Logger.log(`Batch ${i / BATCH_SIZE + 1} synced: ${res}`);
    } catch (e) {
      Logger.log(`Batch error at offset ${i}: ${e.message}`);
    }
  }

  Logger.log('Finished bulk sync.');
}
