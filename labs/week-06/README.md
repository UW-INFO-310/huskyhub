# Week 6 Lab — Authentication: Sessions, Cookies, and Brute Force

**Lecture:** Sessions and Authentication

---

## Overview

HTTPS protects traffic, and bcrypt protects stored passwords. This week you examine how HuskyHub trusts identity cookies and handles repeated login failures. You will migrate the application to signed sessions and implement account lockout.

---

## Tools

| Tool | Purpose |
|---|---|
| Browser Developer Tools | Observe and modify cookies |
| Python requests | Run the login exercise |
| Flask session / itsdangerous | Protect authenticated state against tampering |
| MySQL CLI | Add counters and inspect lockout state |

Use `python3` on macOS/Linux and `python` on Windows. See the [troubleshooting guide](../../TROUBLESHOOTING.md) for installing local scripting tools.

---

## Steps

Run terminal commands from your existing `huskyhub` folder. Continue with Week 4 bcrypt and HTTPS, and keep Week 5’s structured logging.

### 1. Inspect Authentication Cookies

Log in as `jsmith` at `https://localhost`. In Developer Tools, identify the cookies that carry the username, role, and database ID.

---

### 2. Demonstrate Role Forgery

Change `role=student` to `role=admin`. Reload and open `/admin/users`. Record the request and what access you gained. Inspect `is_admin()` in `flask/app/routes/admin.py`: what evidence does it actually check?

Restore the original role and log out before the next test. This is cookie forgery, not guessing the admin password.

---

### 3. Demonstrate User Impersonation

Log in again as `jsmith` (ID 3). Change `user_id` to 4, then open `/grades` **without a student_id query parameter**. Record whose grades appear. The URL-based ownership flaw is a separate Week 7 exercise; this test isolates the trusted-cookie identity flaw.

Restore the original cookies and log out. Keep evidence from both role and identity forgery.

---

### 4. Examine the Authentication Transition and Session Fixation

**How session fixation relates to the starter:** Session fixation requires the server to keep using an attacker-known session ID after login. A server-side session backend can counter this by issuing a new ID at login. HuskyHub’s starter uses three unsigned identity cookies to identify the logged-in user.

Compare the cookies before and after a successful login. Note which cookies appear when HuskyHub establishes identity. Flask may also use a cookie for flash messages.

---

### 5. Script a Brute Force Attack

First watch the POST to `/login` in the browser Network tab. A wrong password should return 200 with the generic login error; a correct password should return 302 with a Location leading to the home page. Examine the POST itself, not the 200 obtained after following a redirect.

Write `brute.py` to read `labs/week-06/wordlist.txt`, test username `tbrown`, and stop when login succeeds. The correct fixture password is after the first five guesses, so the same wordlist will later demonstrate lockout. Baseline the unprotected attack **before** adding counters.

Use the following request pattern and add your own loop and attempt counter:

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

On Windows use `python brute.py`. Record the attempt count and whether the baseline run succeeded.

---

### 6. Remediation — Cryptographically Signed Sessions

**What signing protects:** Flask stores readable session data in a signed cookie and verifies the signature before trusting the data. A valid cookie can still be replayed if it is stolen.

Generate a strong secret **once**, using the command for your platform:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

On Windows use `python -c` with the same quoted expression. Replace the fixture value of `FLASK_SECRET_KEY` in `.env`. Require that environment setting in `flask/app/__init__.py`; do not silently use the public development fallback for hardened sessions. Do not generate a different secret at every startup.

Set the Flask session values after login checks succeed:

```python
session['authenticated'] = user['username']
session['role'] = user['role']
session['user_id'] = user['user_id']
```

Keep Week 3’s chatbot fixes, Week 4’s bcrypt verification, and Week 5’s logging.

- Import `session` wherever you use it.
- Replace the three login `set_cookie` calls with signed session state and keep the login redirect.
- Change logout to clear the session. Delete the old identity cookies during migration so stale browser values do not confuse testing.
- Replace identity and role reads in `auth.py`, `grades.py`, `enrollment.py`, `messages.py`, `documents.py`, `admin.py`, `chatbot.py`, and the home route in `__init__.py` with `session.get(...)`. Keep URL parameters such as `student_id`.
- Update `templates/base.html`, whose navbar and admin links also read cookies. Flask exposes `session` to Jinja automatically.
- Set `SESSION_COOKIE_HTTPONLY=True`, `SESSION_COOKIE_SECURE=True`, and `SESSION_COOKIE_SAMESITE='Lax'`; HTTPS from Week 4 is required for the Secure cookie.

---

### 7. Remediation — Clear Pre-Login State

**Why the order matters:** Clear the pre-login session so its state does not carry into the newly authenticated session.

Place `session.clear()` after successful credential and approval checks and immediately before writing authenticated session values. Keep this ordering when you add lockout in Step 8.

---

### 8. Remediation — Account Lockout

**What lockout does:** After repeated failed logins, the account temporarily stops accepting password attempts. A generic error gives the browser the same message for different login failures.

Add these columns to the running users table, using the MySQL CLI from the course root:

```bash
docker compose exec huskyhub-db mysql -u user -psupersecretpw huskyhub
```

```sql
ALTER TABLE users
  ADD COLUMN failed_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN lockout_until DATETIME NULL;
```

Add only missing columns. Also add both to the users table definition in `database/init.sql` so the schema survives a volume reset. Rerun the Week 4 hashing migration if you reset the database.

Implement the login logic yourself:

1. Retrieve the account and retain its approval restriction. Unknown, unapproved, wrong-password, and locked-account cases return the same generic client error.
2. If `lockout_until` is still in the future, reject without checking the password.
3. Clear expired lockout state before counting a new failure, so the account can recover after 15 minutes.
4. Increment and persist `failed_attempts` for an existing eligible account after a wrong password. At five failures, set a 15-minute lockout using the database's clock.
5. On a valid, approved login, reset counters and lockout state; clear pre-login session state, then establish signed identity.
6. Preserve security log events without logging passwords or signed cookie contents.

---

### 9. Verify the Remediations

Rebuild and recreate Flask after Steps 6–8 so it picks up your code and the new secret in `.env`. Record the result of each check.

| Check | Expected hardened outcome |
|---|---|
| Normal login, grades, navbar, and logout | The correct identity appears after login. Protected pages require login again after logout. |
| Repeat the identity and role checks from Steps 2–3 | The old identity cookies no longer control access. |
| Change one character in the signed session cookie | The application rejects the modified session. |
| Repeat Step 5 and check lockout | Five failed attempts trigger lockout. A correct password during lockout returns the same generic error as a wrong password. |

To repeat lockout tests without resetting all course work, clear just the test account in MySQL:

```sql
UPDATE users SET failed_attempts = 0, lockout_until = NULL WHERE username = 'tbrown';
```

---

## Write-Up Questions

**Q1.** Describe the session fixation attack in your own words. What precondition must an attacker satisfy before the victim logs in? How does rotating a server-side session ID prevent fixation, and what does clearing pre-login state accomplish in HuskyHub?

**Q2.** Your account lockout returns the same error message whether the password is wrong or the account is locked. Why? What attack does this generic message help mitigate?

**Q3.** Suppose HuskyHub required multi-factor authentication (MFA) to complete login. At exactly what point in the authentication flow does MFA intervene? Why does MFA not eliminate the need for strong password policies and account lockout?

---

## Hacker Mindset Prompt

Attackers can guess passwords against a live login, try to crack stolen password hashes offline, or reuse credentials exposed by another service.

Reflect on:

- **Contrarian:** The application trusts a cookie value to determine who the user is and what they are allowed to do. What is the fundamental flaw in this trust model, and how does signing correct it?
- **Committed:** Combine bcrypt from Week 4 with account lockout this week. Describe how these two controls create a layered defense. What does each one stop that the other does not?
- **Creative:** What is credential stuffing and why does it succeed even against applications that have never been breached themselves? What control would you add to HuskyHub to detect and block a credential stuffing campaign?

---

## Optional Extension

Use [Attack-Detection Logging](OPTIONAL_DETECTION.md) to enrich your Week 5 logs.
