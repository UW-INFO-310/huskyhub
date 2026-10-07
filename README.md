# HuskyHub — INFO 310, Autumn 2026

HuskyHub is a deliberately vulnerable student services portal. Across nine labs you will discover weaknesses, demonstrate their effects, implement defenses, and check that normal student and advisor workflows still work. The application starts vulnerable: the remediation code is yours to write.

**Start here:** [Setup & Troubleshooting](TROUBLESHOOTING.md), then [Week 1](labs/week-01/README.md). Read the [lab workflow and report guide](LAB_GUIDE.md) before submitting your first lab.

Use this environment only on your own machine or the isolated, authorized lab network described in Week 2. The seeded accounts and records are fictional lab data.

## First-time setup

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and start its engine. Download the Autumn course from [UW-INFO-310/huskyhub](https://github.com/UW-INFO-310/huskyhub).

If Git is installed, run:

```bash
git clone https://github.com/UW-INFO-310/huskyhub.git
cd huskyhub
```

Alternatively use **Code → Download ZIP**, extract it, rename the extracted folder to `huskyhub`, and open a terminal inside it. You should see this README and `docker-compose.yaml`. Use the course repository above rather than either source repository. All nine labs are already present; do not switch weekly Git branches or download a fresh starter each week.

**macOS / Linux / Windows Git Bash:**

```bash
cp .env.example .env
docker compose up --build
```

**Windows PowerShell:**

```powershell
Copy-Item .env.example .env
docker compose up --build
```

Create `.env` once; preserve it in later weeks instead of copying over your settings. Wait for `huskyhub-db` to be **healthy**, with `huskyhub-flask` and `huskyhub-nginx` **running**. Only MySQL has a healthcheck; that is expected. Open [http://localhost](http://localhost) and log in as `jsmith` / `password123`.

The starter serves HTTP on port 80. You add HTTPS on port 443 in Week 3. Flask listens on 5000 inside Docker; its port is not published. MySQL's host port is controlled by `MYSQL_PORT` in `.env` (default 3306). Native Ollama is introduced in Week 9; its absence in early weeks is expected.

## Nine-week course

| Week | Lab | Builds on |
|---|---|---|
| 1 | [Reconnaissance and The Hacker Mindset](labs/week-01/README.md) | Setup and browser Developer Tools |
| 2 | [Networking, Packet Capture, and MITM](labs/week-02/README.md) | Week 1 observations |
| 3 | [Cryptography: Password Hashing and HTTPS](labs/week-03/README.md) | Week 2 cleartext capture |
| 4 | [Logging, Error Handling, and Third-Party Risk](labs/week-04/README.md) | Week 3 HTTPS |
| 5 | [Authentication: Sessions, Cookies, and Brute Force](labs/week-05/README.md) — **required standalone lab** | Week 3 bcrypt/HTTPS and Week 4 logs |
| 6 | [Authorization, IDOR, and Offensive Tools](labs/week-06/README.md) | Week 5 signed sessions |
| 7 | [SQL Injection and OWASP Top 10](labs/week-07/README.md) | Weeks 3–6 cumulative fixes |
| 8 | [XSS, Bug Bounty, and Automated Testing](labs/week-08/README.md) | HTTPS, sessions, authorization, and parameterized queries |
| 9 | [AI Security: Prompt Injection and Insecure Output](labs/week-09/README.md) | Week 8 CSP and Week 9 Ollama pre-lab |

Certificate trust is an optional Week 3 extension. Additional attack-detection logging is an optional [Week 5 extension](labs/week-05/OPTIONAL_DETECTION.md). Required signed sessions, brute force, and lockout are all in Week 5.

**Course dates, lecture weekdays, due dates, grading weights, and midterm timing: TBD by the instructor.** Use the topics in each lab and the course LMS for the schedule.

## Keep your work across weeks

Continue in this same folder. Each lab builds on your earlier edits and database migrations; returning to a fresh starter would undo them. Save a code backup before editing and preserve database data you need. Version control is optional when using a ZIP download. A Git clone already tracks the course repository, but the labs do not require weekly branch switches or publishing your changes.

After changing code or Python requirements:

```bash
docker compose up -d --build
```

After changing `.env`, recreate the affected service so its environment updates:

```bash
docker compose up -d --force-recreate huskyhub-flask
```

## Accounts

| Username | Password | Role |
|---|---|---|
| admin | admin | Admin |
| mwilson | advisor123 | Advisor |
| jsmith | password123 | Student; primary lab account, ID 3 |
| alee | alexpass | Student, ID 4 |
| pchen | priya2024 | Student, ID 5 |
| tbrown | tyler99 | Student, ID 6 |
| sgarcia | sofia!123 | Student, ID 7 |
| dkim | dkim2025 | Student |
| rnguyen | rachel456 | Student |
| cmartinez | carlos789 | Student |
| lthompson | lauren!pass | Student |
| pending1 | newuser | Student; unapproved, cannot log in |

All fixture details are in `database/init.sql`. New registrations require admin approval. Keep that restriction when hardening login and registration.

## Useful commands

```bash
docker compose ps
docker compose logs huskyhub-flask
docker compose logs huskyhub-nginx
docker compose down
docker compose exec huskyhub-db mysql -u user -psupersecretpw huskyhub
```

`down` stops containers while retaining database data. To stop the optional Week 9 container too, use `docker compose --profile ai down`. The [Makefile](Makefile) offers shortcuts if `make` is installed; it is not required on Windows.

### Recovering a broken database

Back up evidence first. These commands delete database data and any model stored in the optional Docker volume:

```bash
docker compose --profile ai down -v
docker compose up -d --build
```

The database is recreated from your `database/init.sql`. After Week 3, rerun your password migration before logging in; after Week 5, your seed schema must include lockout columns. A reset does not undo your Python code, so stale seed data can be incompatible with hardened routes. See [LAB_GUIDE.md](LAB_GUIDE.md#recovering-after-a-reset).

## Files and sources

- `flask/app/`: routes, templates, static assets, and uploaded documents.
- `flask/requirements.txt`: pinned starter dependencies; additions required by labs are student tasks.
- `nginx/default.conf`: HTTP starter; students add TLS and CSP later.
- `database/init.sql`: fictional seed records and starter schema.
- `labs/week-01` through `labs/week-09`: canonical instructions and provided assets.
- [Merge notes](docs/MERGE_NOTES.md): instructor-facing source history and Autumn decisions.
- [Validation record](docs/VALIDATION.md): checks and outstanding runtime/instructor review.

Based on [Andy Herman's Spring HuskyHub](https://github.com/andy-herman/huskyhub) and [Coltigo's Summer 2026 HuskyHub](https://github.com/Coltigo/huskyhub-su26). See the [source attribution](docs/MERGE_NOTES.md) and preserved [GPL-3.0 license](LICENSE).
