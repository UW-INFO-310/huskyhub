# Week 6 Lab — Authentication: Sessions, Cookies, and Brute Force

**Lecture:** Sessions and Authentication

---

## Overview

HuskyHub trusts editable identity cookies and allows repeated password guesses. This week you examine both weaknesses and compare the cookies before and after login to understand where session fixation can occur. Then you migrate the application to signed sessions, clear pre-login state, and implement account lockout.

---

## Tools

| Tool | Purpose |
|---|---|
| Browser Developer Tools | Inspect and edit cookies |
| Python requests library | Make HTTP requests from Python |
| Flask sessions and itsdangerous | Implement cryptographically signed sessions |
| Terminal | Run scripts |
| MySQL CLI | Add counters and inspect lockout state |

### Platform Notes

Use `python3` on macOS/Linux and `python` on Windows. Check your installation with `python3 --version` or `python --version`.

**Install requests on macOS or Linux**

```bash
python3 -m pip install requests
```

**Install requests on Windows**

```powershell
python -m pip install requests
```

---

## Steps

Run terminal commands from your existing `huskyhub` folder. Continue with Week 4 bcrypt and HTTPS, and keep Week 5’s structured logging.

### 1. Inspect the Authentication Cookies

**What the current trust model is and why it fails**

HuskyHub uses cookie values supplied by the browser to identify the user and their role. Without an integrity check, the application cannot tell whether the values it received match the ones it originally set.

Log in as `jsmith` at `https://localhost`. In Developer Tools, open the cookie storage panel and record each cookie’s name, value, and flags. Which cookies identify the user, their role, or their database ID in readable form?

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

**How session fixation relates to the starter**

Session fixation occurs when the server keeps using an attacker-known session ID after login. A server-side session backend can counter it by issuing a new ID when the user authenticates.

Record the cookies present before login and again after login. HuskyHub’s starter establishes identity with three unsigned cookies. Flask may also use a separate cookie for flash messages. Which cookies does HuskyHub use to recognize the logged-in user?

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

**Why signing prevents cookie forgery**

Flask stores readable session data in a signed cookie. It verifies the signature before accepting the values. Editing the cookie invalidates the signature. A stolen valid cookie can still be replayed.

Generate a strong secret **once**, using the command for your platform:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

On Windows use `python -c` with the same quoted expression. Put the generated key in `.env` as `FLASK_SECRET_KEY` and use the environment setting in `flask/app/__init__.py`. Use the same key across restarts so existing sessions can still be verified.

Set the Flask session values after login checks succeed:

```python
session['authenticated'] = user['username']
session['role'] = user['role']
session['user_id'] = user['user_id']
```

Replace the three login `set_cookie` calls and update logout to clear the session. Use `session.get(...)` everywhere the application reads identity or role from cookies, including the home route and `templates/base.html`. Import `session` where Python code uses it. Keep the earlier labs’ fixes and the existing URL parameters.

Set `SESSION_COOKIE_HTTPONLY=True`, `SESSION_COOKIE_SECURE=True`, and `SESSION_COOKIE_SAMESITE='Lax'` for the HTTPS site.

---

### 7. Remediation — Clear Pre-Login State

**Why the order matters**

Clear any pre-login state after successful credential and approval checks and immediately before writing the authenticated session values.

```python
session.clear()
```

Flask writes the new signed state into the browser cookie. The cookie contains the session data itself. Server-side session ID rotation applies to a backend that stores session data on the server.

---

### 8. Remediation — Account Lockout

**What lockout and generic errors accomplish**

Account lockout temporarily stops password attempts after repeated failures. A shared error message reduces the clues that a login response reveals about whether an account exists or is locked.

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

In the login route, add logic that does the following:

- Checks `lockout_until` before verifying the password.
- Increments `failed_attempts` after a wrong password for an approved account and sets `lockout_until` to 15 minutes in the future after five failures.
- Resets the counter and lockout timestamp when a lockout expires or the account successfully logs in.
- Returns the same generic error for unknown accounts, unapproved accounts, wrong passwords, and locked accounts.

Keep the existing approval checks and logging. Clear pre-login state before writing authenticated session values.

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
