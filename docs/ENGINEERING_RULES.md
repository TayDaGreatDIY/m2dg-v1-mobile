\# M2DG Engineering Rules (v1)



\## 0) Prime Directive

\- Make the smallest possible change that solves the problem.

\- No large refactors during feature work unless explicitly scheduled.



\## 1) Security Baseline (Non-Negotiable)

\- All endpoints must be rate-limited.

\- CAPTCHA required on:

&nbsp; - sign up

&nbsp; - sign in (after suspicious attempts)

&nbsp; - password reset

\- No “open routes” (no unauthenticated write endpoints).

\- Use least-privilege access (RLS enforced for every table).

\- Never ship secrets in client apps (Flutter). Keys live in Supabase / env.



\## 2) Data + Auth Rules

\- All user-owned rows must include `user\_id` and be protected by RLS.

\- Server-side validations happen in Edge Functions (not just client checks).

\- Any “check-in” or “anti-cheat” decision is server-authoritative.



\## 3) Anti-Cheat Rules

\- Never trust client location as truth.

\- Validate check-in with:

&nbsp; - distance to court (<= 100m)

&nbsp; - cooldown (30 mins)

&nbsp; - timestamp sanity checks

&nbsp; - device/session signals where possible

\- Suspicious activity gets logged to `security\_events`.



\## 4) UX Rules

\- Countdown timer shown when cooldown is active.

\- Fun, motivational copy for notifications, but never spammy.

\- Streaks: counted once per day.



\## 5) Dev Workflow

\- Every change = commit with clear message.

\- Branch per feature (feature/\*).

\- PRD + Spec are source of truth; update docs when behavior changes.



\## 6) Do Not Do

\- No disabling RLS “just to test”.

\- No shipping without basic error handling and logging.


# M2DG Engineering Rules (v1)

## Change Discipline
- Keep code changes minimal per feature/fix (small PRs / small commits).
- One purpose per commit. Clear commit messages.
- If a bug fix is needed, fix root cause (not band-aids).

## Security Defaults
- Rate-limit every public API endpoint.
- CAPTCHA required on: signup, login, password reset, contact/intake forms.
- No “open routes” (everything private requires auth where appropriate).
- Validate + sanitize all inputs server-side.
- Principle of least privilege via Supabase RLS.

## Anti-Cheat + Integrity
- Cooldown enforced server-side (not just UI).
- Location/radius checks validated on server-side.
- Prevent replay/spam requests (idempotency keys / dedupe).
- Audit trail for check-ins and “Called Next”.

## Reliability
- Fail safe: if location permission is denied → no check-in.
- Offline mode never grants check-in credit (queue only).
- Logging + monitoring for edge functions.

