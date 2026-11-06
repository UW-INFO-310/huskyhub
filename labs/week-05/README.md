# Week 5 Lab — Logging, Error Handling, and Third-Party Risk

**Lecture:** Application Layer, HTTP, Architecture, and Logging; Application Frontend, Backend, and 3rd Parties

---

## Overview

This week you address two problems: verbose error messages that hand attackers a map of the application's internals, and the complete absence of security-relevant logging. You will trigger error conditions deliberately, document what leaks, harden error responses, implement structured logging, and audit the application's dependencies for known CVEs.

---

## Tools

| Tool | Purpose |
|------|---------|
| Browser | Trigger error conditions and observe responses |
| Browser Developer Tools | Inspect error response bodies and headers |
| Python logging module | Implement structured logging |
| pip-audit | Scan dependencies for known CVEs |
| Terminal | Read log output |

### Installing pip-audit by Platform

**macOS / Linux:**
```bash
pip3 install pip-audit
```

**Windows (PowerShell or Git Bash):**
```powershell
pip install pip-audit
```

> If `pip` is not found, install Python from [python.org/downloads](https://www.python.org/downloads/) and ensure **Add Python to PATH** is checked during installation. Then reopen your terminal.

> **macOS note:** If you get a permissions error, use `pip3 install --user pip-audit` or install via `brew install pip-audit`.

---

## Steps

Run terminal commands from your existing `huskyhub` folder. Continue with Week 4 HTTPS, password hashing, and approval checks, and keep your Week 3 AI fixes.

### 1. Trigger Verbose Errors

**Why Flask shows verbose errors by default — and what they expose:**
HuskyHub registers a catch-all handler that returns a Python traceback to the browser. It exposes source file paths, line numbers, exception text, and sometimes SQL details. Flask development debugging can disclose still more information, but do not assume this particular response includes every local variable. This is extremely useful for a developer debugging on their own machine. It is equally useful for an attacker: a stack trace reveals the server's directory structure, the framework version, the names of database tables referenced in the failing query, and sometimes the contents of SQL queries — all without having to find a single vulnerability in the application logic itself. The URLs below intentionally trigger these conditions.

With the application running, **log in as `jsmith` first** (the grades route requires an authenticated session), then navigate to each of the following URLs and record the full response body for each:

```
https://localhost/grades?student_id='
https://localhost/grades?student_id=1%20UNION%20SELECT%201,2,3%23
https://localhost/nonexistent-page
https://localhost/documents/download?file=/etc/passwd
```

The first two trigger database errors. In the starter, the catch-all Exception handler also converts the nonexistent route into a verbose 500; after your remediation that route must return a generic 404. The last URL behaves differently: it does **not** error — it returns HTTP 200 with the contents of `/etc/passwd`. That is a path-traversal / arbitrary-file-read disclosure, not an error condition. Record its response body and note how it differs from the error pages.

For the first response, document:
- The HTTP status code
- Every internal detail exposed (stack traces, file paths, library versions, database errors, SQL queries)
- Ensure that you still take a note of the other 3 pages, you will review them again later.
---

### 2. Analyze What an Attacker Learns

For the first error response, write a structured analysis: what was revealed, and how would an attacker use that specific piece of information in a subsequent attack? Be specific — "file paths were revealed" is not sufficient; "the path `/app/routes/grades.py` was revealed, telling the attacker the Flask routes are organized in an `app/routes/` directory which matches standard Flask project structure" is.

---

### 3. Implement a Global Error Handler

**What a global error handler does and what "least information" means:**
Flask's `@app.errorhandler` decorator registers a function to be called whenever an exception of a given type propagates to the application level unhandled. By registering a handler for the base `Exception` class, you catch everything. The key principle here is *least information*: return only what the client needs to know (that an error occurred), and log everything else server-side where only authorized personnel can read it. `exc_info=True` in the log call tells the Python logging system to capture and include the full stack trace in the log entry — so you do not lose diagnostic information, you just stop broadcasting it to anonymous users.

In `flask/app/__init__.py`, replace the current error handler with one that returns a generic response:

Place the `HTTPException` import at the top of the file. Keep both handler functions and their decorators indented inside `create_app()`, before `return app`.

```python
from werkzeug.exceptions import HTTPException

@app.errorhandler(Exception)
def handle_error(e):
    if isinstance(e, HTTPException):
        return {"error": e.name}, e.code
    app.logger.error(f"Unhandled exception: {str(e)}", exc_info=True)
    return {"error": "An unexpected error occurred."}, 500

@app.errorhandler(404)
def not_found(e):
    return {"error": "Not found."}, 404
```

Rebuild and re-trigger the URLs from Step 1. Confirm the exception/404 responses do not expose internal details. The file-download disclosure still returns 200: generic error handling does not authorize files. Document it and carry that finding to Week 7 rather than claiming this handler fixes it.

---

### 4. Configure Structured Logging

**Why structured (JSON) logs are superior to plain text logs:**
A plain text log entry like `ERROR 2025-01-15 login failed for jsmith` is readable by a human but difficult to query programmatically. When you have millions of log entries and need to find all failed logins by a specific user within a time window, plain text requires fragile string parsing. JSON-formatted logs can be indexed and queried by any log aggregation system (Splunk, Elasticsearch, CloudWatch) without custom parsing. The `LogRecord` object that Python passes to the `format()` method contains all available information about the log event — the `hasattr` checks allow you to include optional context fields (like `user` and `endpoint`) only when the code that generated the log event explicitly attached them.

Create `flask/app/logging_config.py`:

```python
import logging
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.module,
        }
        if hasattr(record, "user"):
            log_entry["user"] = record.user
        if hasattr(record, "endpoint"):
            log_entry["endpoint"] = record.endpoint
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry)
```

Configure Flask to use this formatter and write logs to `/var/log/huskyhub/app.log` inside the container. Create `logs/` in the course root (`mkdir -p logs` in Terminal/Git Bash; `New-Item -ItemType Directory -Force logs` in PowerShell). Add `./logs:/var/log/huskyhub` to the existing Flask service volumes; retain uploads. Set the application logger and file handler to INFO so INFO records are not filtered, replace duplicate default handlers as needed, and create the log directory before opening the file. Configure logging before routes are used. Do not log passwords or entire cookies.

Use `extra={"user": username, "endpoint": request.path}` on authentication/authorization events. Exception records can lack a user; the formatter deliberately treats these context fields as optional. Preserve HTTP exception codes, including the 403 responses you will introduce in Week 7.

---

### 5. Add Security-Relevant Log Events

**What makes a log event "security-relevant" and why log levels matter:**
Security-relevant events are those that indicate something worth investigating: a successful authentication (establishes a timeline of who logged in and when), a failed authentication (establishes whether a brute force attempt is in progress), and an authorization denial (establishes whether a user is attempting to access resources beyond their permissions). Log levels — DEBUG, INFO, WARNING, ERROR — are not just labels; monitoring systems are typically configured to alert on WARNING and above. Using WARNING for failed logins means a spike in warnings can trigger an automatic alert before a human notices.

Add log statements to the following locations in the codebase:

| Event | Level | Location |
|-------|-------|----------|
| Successful login | INFO | `auth.py` login route |
| Failed login attempt | WARNING | `auth.py` login route — include the username attempted |
| Access to a resource without authorization | WARNING | Any route that checks the role cookie |
| Unhandled exception | ERROR | Global error handler (already done in Step 3) |

`current_app` is the Flask object that exposes the logger inside a route. Make sure it is included in the import at the top of `auth.py`:

```python
from flask import Blueprint, current_app, request, redirect, url_for, render_template, make_response
```

If `current_app` is missing from the import, login will throw a `NameError` and return a 500 error on every POST.

Also add `current_app` to the existing Flask import in `admin.py` if you add authorization-denial logging there.

Rebuild after the Python and Compose changes before verifying the log events in Step 6:

```bash
docker compose up --build -d
```

---

### 6. Verify Log Output

Trigger each of the four log events. To test an authorization denial, log in as `jsmith` and visit `https://localhost/admin/users`; the existing redirect should remain, and a WARNING should appear in the log. Then read the log file:

```bash
docker exec -it huskyhub-flask cat /var/log/huskyhub/app.log
```

Paste at least one log entry per event type in your report. Confirm every record has timestamp, level, message, and module; user/endpoint appear when the log call supplies them. Show an exception record with its server-side traceback while its client response stays generic.

---

### 7. Audit Dependencies

**What a CVE is and what pip-audit checks:**
A CVE (Common Vulnerabilities and Exposures) is a standardized identifier for a publicly disclosed security vulnerability in a software component. The National Vulnerability Database (NVD) provides CVE descriptions and severity information (CVSS) for your research in Step 8. By default, `pip-audit` checks package versions resolved from your requirements file against vulnerability data provided through PyPI, rather than querying NVD directly. It does not analyze your application code. A clean audit result means no known vulnerabilities were reported for the packages successfully audited; it does not establish that your application is secure.

Run pip-audit against the application's requirements file:

**macOS / Linux:**
```bash
pip-audit -r flask/requirements.txt --aliases
```

**Windows:**
```powershell
pip-audit -r flask/requirements.txt --aliases
```

The `--aliases` flag displays alternative identifiers, including CVEs when available, alongside the primary advisory ID (such as `PYSEC-...` or `GHSA-...`). These identifiers can refer to the same vulnerability; do not count aliases as separate findings.

Record every finding: advisory ID, CVE identifier if available, affected package, audited version, fixed version (or "none listed"), and a one-line description. If no CVE is listed, record "No CVE listed" and retain the finding. Use a finding with a CVE for Step 8. An exit code of `1` is expected when vulnerabilities are found.

---

### 8. Research the Highest-Severity CVE

**What a CVSS score measures:**
The Common Vulnerability Scoring System (CVSS) describes a vulnerability's technical severity using a score from 0 to 10 and a vector describing its characteristics. For CVSS v3.1, scores of **9.0–10.0 are Critical**. A Critical rating does not automatically mean the vulnerability allows unauthenticated remote access or complete system compromise. Read the actual vector to identify the attack vector, attack complexity, privileges required, user interaction, and effects on confidentiality, integrity, and availability. Then consider whether HuskyHub meets the conditions required for exploitation.

Select the highest-severity CVE from your audit. Look it up at [nvd.nist.gov](https://nvd.nist.gov). Document:
- CVSS score, version, vector string, and source of the score
- Attack vector (network / adjacent / local)
- Whether authentication is required to exploit it
- Whether a patched version exists
- The potential impact on HuskyHub, including whether its configuration and use of the affected package meet the advisory's exploitation conditions. State any uncertainty.

---

## Write-Up Questions

**Q1.** What is the principle of least information in the context of error handling? How does your global error handler implement this principle, and why is this different from "security through obscurity"?

**Q2.** Paste one JSON log entry for each of your four log event types. Explain why each field in the structured format is useful for incident response.

**Q3.** The lecture covered third-party risk. What is a software supply chain attack? How does the SolarWinds breach illustrate that dependency risk extends beyond known CVEs in publicly listed packages?

---

## Hacker Mindset Prompt

Verbose error messages do reconnaissance for the attacker at zero cost. Every stack trace is a map of the application internals. Every database error message is a hint about the schema.

Reflect on:

- **Contrarian:** A developer adds verbose errors to help with debugging. How does the attacker benefit more from this decision than the developer does?
- **Committed:** An attacker who discovers a vulnerable dependency in a target application does not stop at reading the CVE. Describe the exact steps they would take from discovery to exploit in the HuskyHub context.
- **Creative:** Logging is a double-edged sword — it can also be used *against* an application. How could an attacker abuse a logging system itself as an attack vector? Research "Log4Shell" and explain how it fits this idea.
