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

1. **`I18N` object** (~line 640) — contains everything user-facing in `en` and `ar`. All UI strings, all 5 questions, the `progress(cur,total)` formatter, `dir: "ltr|rtl"`. Adding a new piece of UI text means adding a key to **both** language objects.
2. **`state` object** — `{ currentIndex, followUpsForCurrent, currentFollowUp, responses[] }`. `responses` is initialized from `t().questions` and rebuilt on language switch and on restart.
3. **`renderQuestion()`** — the single render function. Branches on `state.currentFollowUp`: when truthy it shows the follow-up badge + accent border + `(Follow-up question)` prefix; otherwise the base question. Also flips the Next button label to `t().finishBtn` on the final base question.
4. **`handleNext()`** — saves the answer, conditionally calls `evaluateFollowUp()` (gated by `FOLLOWUPS_ENABLED && state.followUpsForCurrent < MAX_FOLLOWUPS`), then either re-renders for a follow-up or advances `currentIndex`. End-of-list calls `finishInterview()`.
5. **`evaluateFollowUp()`** — POSTs to Gemini 2.5 Flash. The prompt instructs Gemini to return either a single follow-up question or the literal word `NONE`. Errors are caught one level up in `handleNext` and gracefully degrade to "skip the follow-up, advance to next question."
6. **`finishInterview()` → `submitToSheet()`** — fires a `no-cors` POST to `SHEET_WEBHOOK_URL` with a structured JSON payload (one `responses[]` entry per question, each with its own `followUps[]`). Because `no-cors` returns an opaque response, success is **assumed** if `fetch` doesn't throw.
7. **i18n applier** — walks `[data-i18n]` and `[data-i18n-html]` attributes on each render/language change. The intro screen uses many of these with structured `g1Title`/`g1Body` pairs (post-redesign).

## Critical constants near the top of `<script>`

```js
const GEMINI_API_KEY      // placeholder in index.html, real in index.local.html
const SHEET_WEBHOOK_URL   // placeholder in index.html, real in index.local.html
const FOLLOWUPS_ENABLED   // false by default — flip to true to re-enable Gemini follow-ups
const MAX_FOLLOWUPS = 2   // hard cap per question, also enforced by Gemini prompt rules
```

`FOLLOWUPS_ENABLED` is currently **off** because the free-tier Gemini key (20 req/min) was rate-limiting users mid-interview. When re-enabling, also consider adding 429 retry/backoff in `evaluateFollowUp()`.

## Google Sheets integration

The receiving endpoint is a **Google Apps Script Web App**. The full `doPost` snippet — which is what the deployed Apps Script must contain — is in `README.md`. The schema the frontend sends is also documented in the README and matches what the Apps Script parses. If you change the JS payload shape, you must update the Apps Script too (it's not in this repo).

The browser sends `Content-Type: text/plain` to avoid a CORS preflight; the Apps Script reads `e.postData.contents` and parses it as JSON regardless. Don't switch this to `application/json` — the preflight will fail.

## i18n + RTL conventions

- Toggling language calls `setLang()` which rebuilds `state.responses` from the new question list and re-applies all `data-i18n` attributes.
- RTL layout is driven by `[dir="rtl"]` on `<html>`. Several CSS rules have RTL-specific overrides (search the stylesheet for `[dir="rtl"]`). When adding directional UI (borders, padding, arrow icons), add the matching RTL override.

## Verification workflow

Use the `preview_*` MCP tools, never spawn raw Bash for the dev server. After editing `index.html` (or `index.local.html`), reload via `preview_eval` and verify against the actual rendered DOM. End-to-end interview flow can be driven programmatically by setting `answerInput.value` and clicking `nextBtn` in a loop — see prior runs in conversation history for the exact pattern.

## Known issues / footguns

- **Don't reference `BASE_QUESTIONS`** — it was renamed to `t().questions`. A leftover reference here once silently froze the interview after Q1.
- **Sheet submission cannot be confirmed from the browser** because `no-cors` returns an opaque response. The "Saved successfully" status is best-effort. If you need real confirmation, you'd have to switch the Apps Script to return CORS headers (`setHeader('Access-Control-Allow-Origin', '*')`) and drop `no-cors` mode.
- **Free-tier Gemini quota is 20 req/min.** Re-enabling follow-ups without retry logic will reproduce the rate-limit error users hit before.
