# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project shape

Single-file vanilla web app — the **entire** application (HTML, CSS, JS, i18n strings, all 5 questions in EN+AR, Gemini integration, Google Sheets webhook, theme + language toggles, summary screen) lives in `index.html`. There is no build step, no framework, no `package.json`, no dependencies. Edit `index.html` directly.

## The two-file pattern (important)

There are two parallel copies of the app:

| File | Purpose | Tracked by git? |
|---|---|---|
| `index.html` | Public version with `YOUR_GEMINI_API_KEY_HERE` and `YOUR_APPS_SCRIPT_WEB_APP_URL_HERE` placeholders | ✅ Yes |
| `index.local.html` | Working copy with **real** Gemini key and Apps Script URL for actual local testing | ❌ No (in `.gitignore`) |

When changing app behavior you almost always need to **edit both files** (or edit `index.local.html`, then port the change to `index.html` while preserving the placeholders). The preview at `/` serves the placeholder version; for end-to-end testing of Gemini calls and sheet submissions, preview `/index.local.html` instead.

Never commit the real keys back into `index.html`. Never delete `index.local.html`.

## Run locally

```bash
npx serve .          # auto-port; preferred (the launch.json default)
# or
py -m http.server    # falls back to 8000
```

`.claude/launch.json` defines `npx-serve` (preferred) and `python-http-server` with `autoPort: true` so port collisions are handled automatically. Both Python and `gh` are available on this Windows machine.

## Architecture inside `index.html`

Read these sections in this order if you need to understand the flow:

1. **`I18N` object** — contains everything user-facing in `en` and `ar`. All UI strings, the `progress(cur,total)` formatter, `dir: "ltr|rtl"`. Adding a new piece of UI text means adding a key to **both** language objects.
2. **`state` object** — `{ history: [], currentQuestion: "", done: false, lastAnalysis: null }`. `history` is an array of `{ question, answer }` pairs built up during the interview.
3. **`generateNextQuestion()`** — POSTs to Gemini 2.5 Flash with the full conversation transcript. Gemini generates the next adaptive question or returns `"DONE"` when it has enough data. No predefined question list — every question is AI-generated.
4. **`handleNext()`** — saves the answer to `state.history`, shows a loading skeleton, calls `generateNextQuestion()`, and either renders the next question or calls `finishInterview()` when done or `MAX_QUESTIONS` is reached.
5. **`finishInterview()` → `submitToSheet()` + `generateAnalysis()`** — transitions to summary screen, fires sheet submission and AI analysis in parallel. Analysis results are saved to `state.lastAnalysis` and persisted to interview history.
6. **`switchScreen(from, to, cb)`** — animated screen transition helper (350ms CSS opacity + transform). Replaces direct `.hidden` toggling.
7. **Interview history** — completed interviews are saved to `localStorage.interviewHistory` (max 20, newest first). Users can view past transcripts in a modal and export as `.txt`.
8. **i18n applier** — walks `[data-i18n]` and `[data-i18n-html]` attributes on each render/language change.

## Critical constants near the top of `<script>`

```js
const GEMINI_API_KEY      // placeholder in index.html, real in index.local.html
const SHEET_WEBHOOK_URL   // placeholder in index.html, real in index.local.html
const MAX_QUESTIONS = 5   // AI wraps up around this many exchanges
```

## Google Sheets integration

The receiving endpoint is a **Google Apps Script Web App**. The full `doPost` snippet — which is what the deployed Apps Script must contain — is in `README.md`. The schema the frontend sends is also documented in the README and matches what the Apps Script parses. If you change the JS payload shape, you must update the Apps Script too (it's not in this repo).

The browser sends `Content-Type: text/plain` to avoid a CORS preflight; the Apps Script reads `e.postData.contents` and parses it as JSON regardless. Don't switch this to `application/json` — the preflight will fail.

## i18n + RTL conventions

- Toggling language calls `applyLang()` which re-applies all `data-i18n` attributes and updates direction.
- RTL layout is driven by `[dir="rtl"]` on `<html>`. Several CSS rules have RTL-specific overrides (search the stylesheet for `[dir="rtl"]`). When adding directional UI (borders, padding, arrow icons), add the matching RTL override.

## Interview history

- **localStorage key**: `interviewHistory` — JSON array of `{ id, date, language, questionCount, history, analysis }` objects
- **Max 20 entries** — oldest are trimmed when cap is exceeded
- **Functions**: `saveInterviewToHistory(analysis)`, `loadHistory()`, `renderHistoryList()`, `openHistoryModal(interview)`, `closeHistoryModal()`, `clearHistory()`
- History section appears below the start button on the intro screen when entries exist
- Past interviews open in a modal overlay with transcript and analysis

## Export as text

- `buildExportText(interview)` generates a plain-text transcript with header, Q&A pairs, and analysis sections
- `downloadText(text, filename)` creates a Blob download
- Available from both the summary screen (`#exportBtn`) and the history modal (`#modalExportBtn`)
- Arabic exports include a UTF-8 BOM (`\uFEFF`) for Windows text editor compatibility

## Screen transitions

- `switchScreen(from, to, cb)` replaces direct `.hidden` toggling with a 350ms CSS opacity + translateY animation
- Uses `.screen-exit` (fade up) and `.screen-enter` (fade in from below) CSS classes
- Optional callback `cb` runs after the transition completes (e.g., `renderHistoryList`)

## Loading skeleton

- `#questionSkeleton` shows 3 shimmer bars during AI question generation
- Replaces the typing dots indicator for the longer question-generation wait
- CSS `@keyframes shimmer` animates a gradient sweep across the skeleton lines

## Responsive breakpoints

- `@media (max-width: 540px)` — reduced padding, smaller fonts, input-row stacks vertically (mic below textarea), topbar wraps
- `@media (max-width: 380px)` — further size reductions for very small phones

## Verification workflow

Use the `preview_*` MCP tools, never spawn raw Bash for the dev server. After editing `index.html` (or `index.local.html`), reload via `preview_eval` and verify against the actual rendered DOM. End-to-end interview flow can be driven programmatically by setting `answerInput.value` and clicking `nextBtn` in a loop — see prior runs in conversation history for the exact pattern.

## Known issues / footguns

- **No predefined questions** — the app uses adaptive AI-generated questions. There is no `BASE_QUESTIONS` or `t().questions` array. All questions come from `generateNextQuestion()`.
- **Sheet submission cannot be confirmed from the browser** because `no-cors` returns an opaque response. The "Saved successfully" status is best-effort.
- **Free-tier Gemini quota is 20 req/min.** Each interview uses ~6 Gemini calls (5 questions + 1 analysis). Back-to-back interviews may hit rate limits.
- **`state.lastAnalysis`** must be set before `saveInterviewToHistory()` is called — this happens inside `generateAnalysis()` after the AI response is parsed.
