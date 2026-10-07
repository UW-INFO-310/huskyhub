# HuskyHub Autumn 2026 editing guardrails

This is an intentionally vulnerable INFO 310 starter for nine cumulative cybersecurity labs. Its weaknesses are exercise content. Do not silently harden the application or add completed student solutions.

- Preserve f-string SQL, plaintext seed passwords, cookie-based identity, missing ownership/role checks, verbose errors, `| safe` output, and sensitive AI prompt context until the instructor explicitly requests a change to that exercise.
- Preserve pinned starter dependencies and the HTTP-only nginx starter. bcrypt, HTTPS, logging, signed sessions/lockout, authorization, parameterization, CSP/output encoding, and adversarial tests are introduced by students in Weeks 3–9.
- The Ollama environment integration and Week 2 ARP helpers are support code, not completed remediation. Do not remove the remaining exploit targets while editing them.
- Canonical instructions are `labs/week-01` through `labs/week-09`; root README is setup/course index. The course repository is UW-INFO-310/huskyhub. All nine labs are in one cumulative copy, with no weekly release-branch workflow.
- Keep commands, service names, fixtures, ports, submissions, and cross-week dependencies consistent. Read `docs/MERGE_NOTES.md` and `docs/VALIDATION.md` before changing the course.
- Fake credentials are deliberate fixtures. Never include personal secrets, generated TLS private keys, or `.env` in a submission.
- Do not create Git repositories, branches, commits, push destinations, or publication actions unless the user asks. Authorized local course edits may proceed.
