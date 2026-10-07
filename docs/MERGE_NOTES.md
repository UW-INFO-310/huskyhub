# Autumn 2026 Merge Notes

Built locally on October 6, 2026. The instructor approved the nine-week plan and then authorized building the whole course for later editing. The subsequent instruction was to create **only a local folder with code**. The initial build created no Git repository or publication. The instructor subsequently authorized pushing to UW-INFO-310/huskyhub on October 6, 2026. Publication uses a separate checkout and preserves destination initial commit `8d478479714a185713ca7f30f8a61ac682a0a547`; the original local course folder and both source clones remain separate. No Spring or Summer source repository is modified.

## Source Baseline

- Spring: [andy-herman/huskyhub](https://github.com/andy-herman/huskyhub), main `1517835cca5e63aae46f90cd267dafc813e76e47`.
- Summer: [Coltigo/huskyhub-su26](https://github.com/Coltigo/huskyhub-su26), main `18b5c874e3c6d8b251ecc9da878546078dc68d1c`.
- Spring weekly heads were also inspected. Full refs are recorded in [SOURCE_MANIFEST.json](SOURCE_MANIFEST.json). The repositories' newest shared commit in Summer history is `c3c4c552dd49ba0a2f878b01f1c780e11064ae43`; Summer does not inherit all Spring June corrections.
- Spring main supplies the vulnerable Flask/MySQL/nginx starter, pinned requirements, seed accounts, nine-week sequence, GPL license, and March GPA fix `0f5fff3`. Most Summer application files are identical; its useful newer changes are mainly instructional.

## Weekly Sources and Adaptations

| Autumn week | Kept from Spring | Selected from Summer / Autumn adaptation |
|---|---|---|
| 1 | AI interface/source baseline and Week 9 revisit | Week 1 beginner terminal/DevTools explanations, observation tables, and account comparisons; cookie tampering deferred to Week 5 |
| 2 | Full capture/MITM goals; week-02 single-direction ARP and restore helpers from `d5cf6d7` | Summer `821186c` interface/tutorial clarity; corrected three-endpoint path and explicit forwarding; helpers now resolve MACs on the requested adapter |
| 3 | Ten-step bcrypt/migration/TLS lab, including June `37dd518` idempotency/copy/static fixes | Compatible newer prose; optional local certificate trust from `6387329`; localhost SAN and portable certificate config |
| 4 | June `91d7297` audit/disclosure corrections | Current_app import and logging guidance from Summer Week 4; preserve HTTP exception codes and specify log mounting/context |
| 5 | Required standalone scope, wordlist, stable secret and seed-schema reset guidance from `d01f1bb` | Full route/navbar/logout migration from readme3.5.md; HTTPS/brute-force measurement from `b641989`; extra detection alerts optional |
| 6 | Full required second IDOR plus Repeater/Intruder practice; June `26b0d5c` route distinctions | Compatible Summer authorization wording; corrected signed-session prerequisites, own-grades default, and advisor policy |
| 7 | June `971f1a2` MySQL # payloads and full threat-model/parameterization scope | Summer Week 6 is nearly the same; adapt tooling and login expectations to prior bcrypt, lockout, and signed sessions |
| 8 | June `39dcaa9` inline-script CSP and reflected-search clarification; bug bounty and test workload | Compatible Summer prose; separate encoding/CSP verification, authenticated scans, and positive payload assertions |
| 9 | Week 1 revisit, uploader-scoped indirect injection from `dcc7798`, full AI objectives | Summer August native Ollama setup (`1cc88b0`, `202814b`, `18b5c87`) with actual local code/config support, container fallback, and consistent HTTPS/authenticated tests |

No completed student bcrypt, HTTPS, logging, signed-session, lockout, authorization, SQL-parameterization, CSP, or output-encoding solution was added to the application. Doc snippets/scaffolding remain guided instructional examples; students implement them in their own cumulative copy.

## How Week 5 Was Restored

Summer `6387329` moved signed-session material to Week 3 Part 2. `b641989` made brute force and lockout optional. `f4d6026` replaced required Week 5 with shortened authorization material, and `68d858b` shifted SQLi/XSS/AI to Weeks 6/7/8 and deleted Week 9.

Autumn puts cookie inspection/forgery, authenticated-state transition, complete signed-session migration, brute force, lockout, and verification into one **required Week 5**. Week 3 retains hashing/TLS only, with optional certificate trust. The extra alert fields/events remain optional in OPTIONAL_DETECTION.md. Authorization, SQLi, XSS, and AI return to Weeks 6, 7, 8, and 9.

Summer Week 1's role-tampering exercise and Spring's older Week 2 session-remediation extra credit were omitted as duplicated/early authentication work. Flask's client-side signed state is described accurately: clearing it is not server-side ID rotation or revocation of stolen copies.

## Shared Code and Configuration Changes

- Keep Spring's June `9433d43` / `8c88082` Compose corrections: named containers, no legacy nginx/Flask probes, MySQL healthcheck and service_healthy dependency retained. Historical removal was verified; failures were not reproduced on running images.
- Keep Spring main's GPA correction rather than importing weekly branch templates that regress it. Bring the Week 8 branch's corrected XSS seed comments into the seed file; students insert their own payloads.
- Update current quarter in enrollment route/default, home/enrollment UI, seeded enrollments, and welcome/enrollment messages to Autumn 2026. Historical transcript terms and fake passwords remain fixtures; remove a stale graduation forecast rather than inventing a date.
- Add OLLAMA_BASE_URL, OLLAMA_MODEL, and OLLAMA_KEEP_ALIVE to Compose/app settings. Normalize the base URL, use /api/chat, send keep_alive=30m, and use a 5-second connect / 60-second read timeout. Existing controlled unavailable behavior remains. Sensitive prompt context and unsafe AI rendering remain student targets.
- Make the optional Ollama container host port configurable (default 11435, internal 11434), matching the fallback instructions. Native and container setup helpers are separate.
- Add a localhost-SAN example config for OpenSSL versions without -addext. No certificate/key or HTTPS configuration is pre-generated in the starter.
- Root README is a course/setup index. LAB_GUIDE.md and TROUBLESHOOTING.md replace stale release-branch workflows and reconcile resets, tool environments, auth, and submissions.
- Exclude apply-fixes.sh from the student folder: it reintroduces old checks and commits/pushes source branches. Preserve it only in untouched inspection sources. The course contains no automatic commit/push script.

## Decisions and Instructor Editing

Nine required labs, Spring progression, separate required Week 5, optional certificate trust/extra detection alerts, vulnerable starter, and the original local build are accepted. The later explicit request authorizes publishing this course to UW-INFO-310/huskyhub. Per-week approval pauses were superseded by the instructor's request to build everything now and edit afterwards.

Dates, weekdays, due dates, grading weights, midterm timing, support links, are intentionally TBD. The course distribution URL is now https://github.com/UW-INFO-310/huskyhub. Use [INSTRUCTOR_REVIEW.md](INSTRUCTOR_REVIEW.md) for remaining choices and [VALIDATION.md](VALIDATION.md) for tested behavior and limitations.
