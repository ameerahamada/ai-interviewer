# AI Interviewer — Delivery App User Research

A single-file local web app that runs an AI-powered qualitative user interview about food delivery apps. Built as a lightweight tool for fast user research sessions.

## Features

- **Clean, modern UI** with light/dark mode toggle
- **Bilingual** — full English & Arabic support with RTL layout
- **5 focused, qualitative questions** (one specific question per screen — no leading or compound questions)
- **Optional AI follow-ups** powered by Gemini 2.5 Flash (disabled by default to avoid free-tier rate limits)
- **Visible progress bar** showing position in the interview
- **Inline validation** — empty submissions highlight the field in red with a clear error message
- **Auto-save to Google Sheets** via a Google Apps Script webhook at the end of each interview
- **End-of-session recap** of every answer the user gave

## Tech stack

- Vanilla HTML / CSS / JavaScript — no build step, no dependencies
- [Google Gemini API](https://aistudio.google.com/) (`gemini-2.5-flash`) for follow-up generation
- Google Apps Script web app as a serverless write-endpoint to a Google Sheet

## Run locally

```bash
npx serve .
```

Then open the URL it prints (usually `http://localhost:3000`).

Or with Python:

```bash
py -m http.server 8000
```

## Setup

Before running, open `index.html` and replace the two placeholder values near the top of the `<script>` block:

```js
const GEMINI_API_KEY = "YOUR_GEMINI_API_KEY_HERE";
const SHEET_WEBHOOK_URL = "YOUR_APPS_SCRIPT_WEB_APP_URL_HERE";
```

### 1. Get a free Gemini API key

1. Visit https://aistudio.google.com/app/apikey
2. Click **Create API key**
3. Paste it into `GEMINI_API_KEY`

The free tier allows ~20 requests/minute on `gemini-2.5-flash` — enough for testing.

### 2. (Optional) Set up the Google Sheet webhook

If you want responses to auto-save to a sheet:

1. Create a new Google Sheet
2. Extensions → Apps Script
3. Paste the script below, save, then **Deploy → New deployment → Web app**
4. Set **Execute as: Me** and **Who has access: Anyone**
5. Copy the `/exec` URL it gives you and paste it into `SHEET_WEBHOOK_URL`

```javascript
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();

    if (sheet.getLastRow() === 0) {
      sheet.appendRow([
        'Timestamp', 'Interview ID', 'Language', 'Topic',
        'Question #', 'Type', 'Question', 'Answer'
      ]);
    }

    data.responses.forEach(function (r) {
      sheet.appendRow([
        data.createdAt, data.interviewId, data.language, data.topic,
        r.questionId, 'Main', r.question, r.answer
      ]);
      (r.followUps || []).forEach(function (f) {
        sheet.appendRow([
          data.createdAt, data.interviewId, data.language, data.topic,
          r.questionId, 'Follow-up', f.question, f.answer
        ]);
      });
    });

    return ContentService.createTextOutput(JSON.stringify({ ok: true }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ ok: false, error: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
```

The app posts one row per main question and one row per follow-up.

### 3. (Optional) Enable AI follow-ups

Follow-ups are off by default. To enable them, set:

```js
const FOLLOWUPS_ENABLED = true;
```

The app will then ask Gemini to evaluate each answer and ask up to 2 follow-ups per question if it deems the answer vague or incomplete.

## Notes

- The Gemini key is exposed in the browser. For anything beyond local/personal use, proxy the API call through a backend.
- The interview topic and questions are hardcoded for delivery-app research, but they're easy to change in the `I18N.en.questions` and `I18N.ar.questions` arrays.

## License

MIT
