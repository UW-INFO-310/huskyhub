# Week 5 Lab — Authentication: Sessions, Cookies, and Brute Force

**Quarter:** Autumn 2026 · **Required standalone lab**

**Lecture:** Sessions and Authentication

**Prerequisites:** Week 3 bcrypt and HTTPS; Week 4 structured logging. Continue your cumulative application.

[Course index](../../README.md) · [Setup help](../../TROUBLESHOOTING.md) · [Report requirements](../../LAB_GUIDE.md)

---

## Overview

HTTPS protects traffic, and bcrypt protects stored passwords. Neither prevents a user editing the identity cookies HuskyHub trusts, nor limits online password guesses. This week you demonstrate role and user impersonation, examine the transition into authenticated state, migrate the whole app to signed sessions, and implement account lockout. All nine steps below are required.

Signed sessions, brute force, and lockout are **not** part of Week 3 or extra credit in Autumn. Additional detection alerts are available as an optional extension after this required lab. Midterm timing and due date are **TBD by the instructor**.

## Tools

| Tool | Purpose |
|---|---|
| Browser Developer Tools | Observe and modify cookies |
| Python requests | Measure an online password-guessing attack |
| Flask session / itsdangerous | Protect authenticated state against tampering |
| MySQL CLI | Add counters and inspect lockout state |
| Week 4 JSON logs | Observe successful and failed login attempts |

Use `python3` on macOS/Linux and `python` on Windows. Install local scripting tools in a virtual environment as described in the troubleshooting guide. The Flask application already provides itsdangerous transitively; you do not need a new session backend.

## Steps

### 1. Inspect Authentication Cookies

Log in as `jsmith` at `https://localhost`. In Developer Tools, record every cookie's name, value, domain, path, and HttpOnly/Secure/SameSite attributes. Compare these observations with Week 1.

Explain which values claim identity, role, or database ID. Cookies reside in the browser; a server needs an independent way to validate claims that a client can change.

### 2. Demonstrate Role Forgery

Change `role=student` to `role=admin`. Reload and open `/admin/users`. Record the request and what access you gained. Inspect `is_admin()` in `flask/app/routes/admin.py`: what evidence does it actually check?

Restore the original role and log out before the next test. This is cookie forgery, not guessing the admin password.

### 3. Demonstrate User Impersonation

Log in again as `jsmith` (ID 3). Change `user_id` to 4, then open `/grades` **without a student_id query parameter**. Record whose grades appear. The URL-based ownership flaw is a separate Week 6 exercise; this test isolates the trusted-cookie identity flaw.

Restore the original cookies and log out. Keep evidence from both role and identity forgery.

### 4. Examine the Authentication Transition and Session Fixation

Record cookies before login, after a successful login, and after logout. There may be an unrelated Flask flash-message cookie, but the starter's authentication is based on three unsigned identity cookies, not an authenticated session identifier.

Classical **session fixation** requires an attacker-known identifier that the server continues treating as the same session after a victim logs in. A server-side session backend normally counters this by regenerating its identifier at authentication. Do not claim you observed that exploit in this starter: there is no such authentication identifier to fix. Explain the precondition and compare it with the forgery you actually demonstrated.

In Steps 6–7 you will instead replace untrusted identity claims with authenticated, signed client-side state and discard pre-login state. Record the difference between those mechanisms rather than treating every cookie as a server-side session ID.

### 5. Script and Measure a Brute Force Attack

First watch the POST to `/login` in the browser Network tab. A wrong password should return 200 with the generic login error; a correct password should return 302 with a Location leading to the home page. Examine the POST itself, not the 200 obtained after following a redirect.

Write `brute.py` to read `labs/week-05/wordlist.txt`, test username `tbrown`, and stop when login succeeds. The correct fixture password is after the first five guesses, so the same wordlist will later demonstrate lockout. Baseline the unprotected attack **before** adding counters.

Use the following request pattern and add your own loop, attempt counter, timing, and output:

```python
import requests

TARGET = "https://localhost/login"
r = requests.post(
    TARGET,
    data={"username": "tbrown", "password": candidate},
    allow_redirects=False,
    verify=False,  # controlled local self-signed lab certificate only
    timeout=10,
)
```

`candidate` is the current wordlist entry, which you define in your loop. Skip empty lines. Confirm success using both status 302 and the expected Location; treat unexpected status codes as errors to investigate. Do not target `http://`: its TLS redirect is not a login result. Browser certificate trust does not necessarily configure Python requests.

Run from the course root:

```bash
python3 brute.py
```

On Windows use `python brute.py`. Record attempts, elapsed time, approximate requests per second, and failed-login records from Week 4. bcrypt deliberately slows password checks, so do not assume a particular guessing speed.

### 6. Migrate the Whole Application to Signed Sessions

Flask's default session stores serialized, **readable but signed** data in a client cookie. Itsdangerous verifies the signature before trusting it. Signing protects integrity; it does not encrypt the values or prevent replay of an already stolen valid cookie. Avoid storing passwords or other secrets in it. The pinned Flask version's default digest is SHA-1 with HMAC; do not describe it as encrypted or as a SHA-256 configuration you never set.

Generate a strong secret **once**, using the command for your platform:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

On Windows use `python -c` with the same quoted expression. Replace the fixture value of `FLASK_SECRET_KEY` in `.env`. Require that environment setting in `flask/app/__init__.py`; do not silently use the public development fallback for hardened sessions. Do not generate a different secret at every startup.

Use Flask `session` assignments after credentials, approval, and any lockout checks succeed:

```python
session['authenticated'] = user['username']
session['role'] = user['role']
session['user_id'] = user['user_id']
```

Keep Week 3's bcrypt verification and Week 4's logging. Complete this checklist:

- Import `session` wherever you use it.
- Replace the three login `set_cookie` calls with signed session state; return the login redirect normally.
- Change logout to clear the session. Delete the old identity cookies during migration so stale browser values do not confuse testing.
- Replace identity/role reads in `auth.py`, `grades.py`, `enrollment.py`, `messages.py`, `documents.py`, `admin.py`, `chatbot.py`, and the home route in `__init__.py` with `session.get(...)`. Retain legitimate request parameters; a grades URL's `student_id` is not a cookie read.
- Update `templates/base.html`, whose navbar and admin links also read cookies. Flask exposes `session` to Jinja automatically.
- Set `SESSION_COOKIE_HTTPONLY=True`, `SESSION_COOKIE_SECURE=True`, and `SESSION_COOKIE_SAMESITE='Lax'`; HTTPS from Week 3 is required for the Secure cookie.
- Search across routes **and templates** for remaining identity reads from `request.cookies`; none should remain. Raw cookie access by Flask's own session machinery is expected.

Recreate/rebuild Flask, log in, and confirm one signed session drives all normal pages and the navbar. It may look encoded, but its data is not secret. Tamper with one character and verify the authenticated state is rejected.

### 7. Clear Pre-Login State Before Establishing Identity

Place `session.clear()` after successful credential/approval/lockout verification and before writing authenticated session values. Check that this ordering preserves Week 4 log events and that logout also clears state.

Record the pre-login and post-login state. Log in as one account, log out, and log in as another; no role or identity should carry over. After a Flask restart, a valid session signed with the same secret should still work.

This is an authenticated-state transition for a signed client-side cookie. It does **not** rotate a server-side identifier or revoke copies of a previously valid signed cookie. Explain why replay of a stolen cookie remains possible until expiry or a separate revocation control, and how HTTPS/HttpOnly reduce theft opportunities. Keep the classical fixation comparison from Step 4 in your report.

### 8. Implement Account Lockout

Add these columns to the running users table, using the MySQL CLI from the course root:

```bash
docker compose exec huskyhub-db mysql -u user -psupersecretpw huskyhub
```

```sql
ALTER TABLE users
  ADD COLUMN failed_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN lockout_until DATETIME NULL;
```

Inspect the schema first and do not repeat ADD COLUMN if it already exists. Also add both columns to the users table definition in `database/init.sql`, so resetting Docker volumes leaves a schema compatible with your hardened login. Keep plaintext fixture data there as the migration input and rerun your Week 3 hashing migration after a reset.

Implement the login logic yourself:

1. Retrieve the account and retain its approval restriction. Unknown, unapproved, wrong-password, and locked-account cases return the same generic client error.
2. If lockout_until is still in the future, reject without checking the password.
3. Clear expired lockout state before counting a new failure, so the account can recover after 15 minutes.
4. Increment and persist failed_attempts for an existing eligible account after a wrong password. At five failures, set a 15-minute lockout using the database's clock.
5. On a valid, approved login, reset counters and lockout state; clear pre-login session state, then establish signed identity.
6. Preserve security log events without logging passwords or signed cookie contents.

Do not give unknown users a different client response, and do not lock out unrelated accounts. Handle invalid input without raising an exception or bypassing bcrypt. Consider the denial-of-service tradeoff of an attacker deliberately locking other users' accounts.

### 9. Verify All Required Defenses

Record before/after evidence for each case:

| Check | Expected hardened outcome |
|---|---|
| Old role/user_id cookies changed or supplied directly | Do not grant a different identity or role |
| One character changed in signed session | Authenticated state rejected |
| Correct approved credentials | Normal login and grades access |
| pending1 or a new unapproved registration | Generic login failure |
| Logout, then a normal request without copied cookies | Login required |
| Switch accounts | No previous role/identity retained |
| Restart Flask with the same secret | Existing valid session remains usable |
| Re-run wordlist against an unlocked tbrown | Five failures trigger lockout; later correct password fails during lockout |
| Expired lockout / successful permitted login | Account recovers and counters reset |
| Wrong password, nonexistent user, locked user | Same generic error, no traceback |

To repeat lockout tests without resetting all course work, clear just the test account in MySQL:

```sql
UPDATE users SET failed_attempts = 0, lockout_until = NULL WHERE username = 'tbrown';
```

Inspect code and seed schema for reset compatibility. If you test an actual volume reset, back up evidence first and rerun password migration before testing login. A copied valid signed session is still replayable: report that limitation instead of claiming logout or signing alone provides server-side revocation.

## Write-Up Questions

**Q1.** Explain session fixation and its attacker precondition. How does clearing pre-login state help your actual Flask implementation, and why is this different from rotating a server-side session ID? What does signing fail to prevent?

**Q2.** Why do wrong-password, nonexistent-user, and locked-account cases share a generic error? Explain the enumeration and lockout tradeoffs.

**Q3.** Where would MFA intervene in the login flow, and why would it not eliminate the need for password hashing, safe sessions, and account lockout?

## Hacker Mindset Prompt

- **Contrarian:** What was wrong with trusting a role cookie, and how does signing change that trust boundary?
- **Committed:** Compare bcrypt's offline protection with account lockout's online protection. What does each leave unaddressed?
- **Creative:** Explain credential stuffing and password spraying. Which detection or prevention control would you add, and why?

## Optional Extension

After the required lab, use [Attack-Detection Logging](OPTIONAL_DETECTION.md) to enrich your Week 4 logs. Its additional alerts are optional and do not replace any required authentication step.

## Submission Checklist

Submit the four-section report in [LAB_GUIDE.md](../../LAB_GUIDE.md), the cookie/transition evidence, brute.py and measurements, before/after lockout results, changed route/template/schema files or a diff, and normal-use verification. Mark optional alerts separately. Due date, points, and LMS destination are **TBD by the instructor**.
