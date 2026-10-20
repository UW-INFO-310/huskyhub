# HuskyHub — Setup & Troubleshooting

Autumn 2026 uses one cumulative working folder and nine labs, obtained from the [course repository](https://github.com/UW-INFO-310/huskyhub) or its ZIP download. Start with the [course index](README.md); report format is in [LAB_GUIDE.md](LAB_GUIDE.md). Copy commands one at a time from the course root, and read the output before continuing.

## Terminal Basics

**macOS:** Cmd+Space → Terminal. **Windows:** Git Bash is a useful shell with the same cp/ls commands as macOS; it comes with [Git for Windows](https://git-scm.com/downloads). Git itself is optional for this local distribution. Some networking steps specifically require PowerShell as Administrator.

| Goal | Terminal / Git Bash | PowerShell |
|---|---|---|
| Current folder | pwd | Get-Location |
| List files | ls | Get-ChildItem |
| Enter the course folder from its parent | cd huskyhub | cd huskyhub |
| Create .env once | cp .env.example .env | Copy-Item .env.example .env |
| Stop a foreground command | Ctrl+C | Ctrl+C |

Paths in every lab are relative to the folder containing docker-compose.yaml. If you opened a terminal elsewhere, change to that folder first; quote a full path if it contains spaces. Edit code with a text editor such as VS Code. Do not create .env in a way that appends .txt.

## Core Tools

- Install and start [Docker Desktop](https://www.docker.com/products/docker-desktop/). On Windows follow its WSL 2/virtualization requirements and restart if the installer asks.
- Install [Python](https://www.python.org/downloads/) for local tools from Week 2 onward. On Windows select the PATH option; reopen the terminal after installation. Python inside the Flask image is separate from this local tool environment.
- Use a current browser with Developer Tools (F12/Ctrl+Shift+I on Windows; Cmd+Option+I on macOS).

Verify with docker --version, docker compose version, and python3 --version (macOS/Linux) or python --version (Windows). This course uses Compose v2 syntax. Use Docker Desktop's supported Compose plugin if docker compose is unavailable.

## Python Tools

Use `pip3` and `python3` on macOS/Linux, or `pip` and `python` on Windows. Follow each lab's platform-specific installation commands; Week 2 installs Scapy directly and runs its macOS/Linux helpers with `sudo python3`, or `python` in PowerShell as Administrator on Windows.

For local scripts that need requests:

**macOS/Linux:**

```bash
pip3 install requests
```

**Windows:**

```powershell
pip install requests
```

Install tools as their labs introduce them: scapy in Week 2, pip-audit in Week 5, sqlmap in Week 8, and pytest in the Week 3 Flask container using the commands in that lab. Application dependencies go in flask/requirements.txt and require a Docker rebuild; installing bcrypt only on your laptop will not put it in the Flask image.

## Docker and Ports

### Cannot connect to Docker / daemon socket missing

Start Docker Desktop and wait for the engine to run. Then try docker compose ps. An installed CLI alone does not mean the engine is running.

### Port 80, 443, or 3306 is occupied

Find the actual process rather than guessing. On macOS/Linux use `lsof -i :80` (change the port); on Windows use `Get-NetTCPConnection -LocalPort 80` in PowerShell. Stop only a process you recognize or ask the teaching team. Changing MYSQL_PORT in .env changes only the database's published host port; Flask still uses huskyhub-db internally. If changing web ports, update every URL and redirect consistently with the teaching team.

### Containers are running, but only MySQL is healthy

That is expected. Spring's June correction removed nginx/Flask probes and retained MySQL's mysqladmin check. Wait for the database to be healthy and inspect docker compose logs huskyhub-flask if login fails. Do not add probes merely to obtain extra badges.

### Code edits do not appear

Run docker compose up -d --build after code/requirements edits. Hard-refresh your browser. After an .env edit use docker compose up -d --force-recreate huskyhub-flask; a restart alone does not reload container environment values.

### A docker exec command says no such container

The names are huskyhub-db, huskyhub-flask, huskyhub-nginx, and optional huskyhub-ollama. Prefer docker compose exec with the service name and verify docker compose ps. Do not substitute old Summer-generated container names.

### Git Bash reports a TTY error

Run an interactive command in PowerShell, or prefix docker exec/compose exec with winpty when required by your terminal. Noninteractive commands can omit -t. Docker commands must be run from the course root for Compose to find the config.

### Database reset breaks hardened login

A volume reset restores seed data, while your hardened code stays changed. Rerun password hashing after Week 4 and retain lockout columns in init.sql after Week 6. Read [the recovery checklist](LAB_GUIDE.md#recovering-after-a-reset). Back up evidence before down -v; clear a test account's lockout counters when you only need another lockout test.

## Week 1 — Browser Observations

Headers are under Network → selected request → Response Headers. Cookies are under Application/Storage → Cookies. Firefox uses Storage rather than Chrome's Application label. Inspect the POST response to see Set-Cookie; a page loaded later need not set the cookies again. Leave the AI Advisor for Week 3; there is no chatbot step or model setup in Week 1.

## Week 2 — Packet Capture and ARP

Use loopback for localhost (lo0/lo/Npcap Loopback Adapter) and the real LAN interface for the second device's requests. Install Wireshark's capture-permission helper/Npcap if no appropriate interface is visible. Install Scapy using the platform commands in [Week 2](labs/week-02/README.md#installing-tools-by-platform). The helper resolves MAC addresses on the interface you give it, so choose the matching Scapy interface identifier.

The laptop hosts HuskyHub and runs the tools; a phone or another browser-capable device is the victim. Use the laptop's LAN IP in the victim's browser. Requests addressed to that server can be captured before ARP spoofing, so record cookie exposure/replay and ARP evidence separately. A true client–server–attacker MITM demonstration with a third endpoint is an optional instructor-led activity.

For the ARP demonstration, the laptop, victim, and gateway must have distinct IP addresses. An isolated home router can supply the gateway with two participant devices. If the phone or laptop also provides the hotspot, those roles overlap; use an isolated home-router network or ask the teaching team for an alternative. Hotspot client isolation or forwarding/firewall restrictions may prevent access. Do not treat a disconnected victim as interception success. Stop both spoof processes, restore both peers' ARP mappings, and restore the original forwarding setting even when troubleshooting.

## Week 3 — Ollama and Provided AI Tests

Native setup is in [Week 3](labs/week-03/README.md). Use http://localhost; HTTPS begins in Week 4. OLLAMA_BASE_URL is a base address without /api/chat. Confirm llama3.2 is pulled, a single server is reachable from Docker, and normal chatbot questions work before attacks. Check ollama ps for CPU/GPU placement. A 60-second read timeout is an unavailable-model result, not a security refusal.

For the fallback set OLLAMA_BASE_URL=http://huskyhub-ollama:11434, enable the ai profile, and pull the model inside that container. OLLAMA_PORT is only its published host port. Recreate Flask after URL changes. Native downloads survive Docker volume resets; container downloads do not.

The complete tests are provided in flask/tests/test_ai_security.py. Rebuild, install pytest in huskyhub-flask, and run the file using the three commands in Week 3. A rebuild includes the test file; installing pytest on your laptop does not install it inside Docker. The tests use controlled database/model responses and do not need a running Ollama model or completed later labs. They check code changes, including page-source disclosure and output encoding. Students do not write tests. Continue the live-model observations separately.

## Week 4 — bcrypt and TLS

The Dockerfile copies flask/app/, not flask/migrate_passwords.py. Rebuild utils.py into the image, docker cp the migration script to /app/migrate_passwords.py, and then execute it. Run it idempotently after resets. Keep approved=1 checks and normal registration behavior.

TLS certificates need a localhost SAN, valid dates, and matching mounts. A self-signed warning is expected until the optional trust exercise. Check docker compose logs huskyhub-nginx if it cannot start; confirm key.pem/cert.pem exist and the static mount remains. Use port-443/TLS capture filters: an empty HTTP filter is not proof of encryption by itself.

## Week 5 — Logging and Audits

Install pip-audit in your local toolbox and run pip-audit -r flask/requirements.txt (or python -m pip_audit with the same arguments). The audit needs internet; an unavailable advisory service is an incomplete audit, not a clean result. Actual advisory counts change, so document your run rather than expecting a fixed output.

Login must import current_app before logging from a route. Create/mount logs/ before opening /var/log/huskyhub/app.log; keep INFO enabled on the logger and handler. Optional user/endpoint fields appear only when supplied. Preserve HTTP exceptions so later abort(403) does not become a generic 500. Generic error handling does not fix the successful arbitrary-file disclosure.

## Week 6 — Sessions and Lockout

Use https://localhost/login in brute.py: the HTTP redirect is not the login result. Run from the course root so the wordlist resolves. Python may not share your browser's certificate trust. A strong secret is generated once into .env and passed through Compose, not regenerated at startup.

Migrate every route and base.html identity read; missing template changes can hide the navbar even when login works. Use session.clear for logout and authenticated-state initialization, while understanding that a signed client cookie is not a revocable server-side session ID. Lockout must recover after its timeout. Clear only tbrown's counters to repeat the test; update init.sql as well as the running schema.

## Week 7 — Authorization and Burp

Use Burp's built-in browser, log in over HTTPS, and ensure held requests are forwarded. Old plaintext role cookies should no longer work. Retain own grades without a student_id parameter and advisor access to /admin/grades; do not stack an admin-only decorator there. If you changed a system proxy, restore it after the lab. Community Intruder can be slow; document completion and content rather than assuming every 200 response is a valid record.

## Week 8 — SQL Injection and sqlmap

Keep bcrypt, signed sessions, lockout, and authorization enabled. An arbitrary password should no longer bypass Python bcrypt just because SQL username lookup is injectable. Search endpoints provide the remaining injection targets. Use MySQL # comments; encode # as %23 in URL parameters. Give sqlmap a current signed session cookie, use HTTPS, and verify it reaches your own grades. Flush old scan-session results before remediation verification. Do not undo earlier defenses to get an obsolete result.

## Week 9 — XSS, ZAP, CSP, and pytest

Use two browser sessions for sender/recipient tests. HttpOnly can make document.cookie empty even when an injected alert runs. Configure an authenticated ZAP context and confirm protected pages are reached. Findings already fixed in earlier weeks should disappear.

After encoding a stored message, reopening it will not produce a CSP violation; use the lab's separate inline-script probe. Check legitimate Bootstrap/UI behavior too. Regression tests must reach the actual content and assert payload-specific encoding, not merely the absence of a tag in an error page. Keep the chatbot output encoding from Week 3.

## Asking for Help

Bring the exact command, current folder, account/URL, status code, and relevant docker compose logs to the teaching team. Support channel/form links and office-hour schedule are **TBD by the instructor**. Remove personal information and generated secrets from shared logs.
