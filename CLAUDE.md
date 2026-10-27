# HuskyHub Autumn 2026 editing guardrails

This is an intentionally vulnerable INFO 310 starter for nine cumulative cybersecurity labs. Its weaknesses are exercise content. Do not silently harden the application or add completed student solutions.

- Preserve f-string SQL, plaintext seed passwords, cookie-based identity, missing ownership/role checks, verbose errors, `| safe` output, and sensitive AI prompt context until the instructor explicitly requests a change to that exercise.
- Preserve pinned starter dependencies and the HTTP-only nginx starter. bcrypt, HTTPS, logging, signed sessions/lockout, authorization, parameterization, CSP/output encoding, and adversarial tests are introduced by students across Weeks 3–9, with AI defenses and provided pytest checks in Week 3.
- The Ollama environment integration and Week 2 ARP helpers are support code, not completed remediation. Do not remove the remaining exploit targets while editing them.
- Canonical instructions are `labs/week-01` through `labs/week-09`; root README is setup/course index. The course repository is UW-INFO-310/huskyhub. All nine labs are in one cumulative copy, with no weekly release-branch workflow.
- Keep commands, service names, fixtures, ports, submissions, and cross-week dependencies consistent. Instructor notes in `docs/` are local only and excluded from Git; consult them when available.
- Fake credentials are deliberate fixtures. Never include personal secrets, generated TLS private keys, or `.env` in a submission.
- Do not create Git repositories, branches, commits, push destinations, or publication actions unless the user asks. Authorized local course edits may proceed.

## October 20 AI lab revision

AI is Week 3; cryptography, logging, authentication, authorization, SQL injection, and XSS are Weeks 4–9. The AI lab follows Summer formatting, keeps the output-text fix without an XSS exploit, and supplies complete deterministic tests for students to run. Keep the starter exercises unsolved; tests are supplied checks, not remediation solutions. Preserve the Week 3 AI fixes during later session and query migrations.
