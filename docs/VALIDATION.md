# Validation Record — Autumn 2026

Built October 6, 2026. This record distinguishes checks of the starter/support code and instructional examples from executing the completed student remediations.

## Passed Checks

- Compose configuration parses with .env.example for the normal stack and optional ai profile; named containers, MySQL healthcheck/dependency, uploads/static mounts, native settings, and the configurable fallback port are inspected.
- Makefile targets expand correctly with make -n; no containers or models were started by those dry runs.
- Python files and Python instructional snippets parse. Markdown titles, balanced fences, required week folders/assets, local links, and stale Summer/release instructions are checked.
- The original pinned application requirements and vulnerable auth/grade/admin/message/document routes, HTTP nginx starter, global error target, and GPA fix remain intact. No finished student utility/decorator/test files or new .git directory are present.
- Local runtime tests use the actual pinned Flask 2.3.3 / Werkzeug 2.3.7 / Jinja2 3.1.2 / requests 2.28.2 in a temporary test environment. The database and Ollama backend are mocked. Checks cover normal approved login/grades, rejected wrong/unapproved login, deliberately forgeable identity/role, missing admin check, raw stored-XSS rendering, error disclosure, native/fallback/custom API URL settings, Ollama request payload/timeout/unavailable behavior, and uploader-scoped summarization.
- Instructional-example checks execute Week 4's HTTP exception handler and Week 6's authorization decorator independently: 404/403 survive, own grades without a parameter work, another student's record is denied, and advisor access is preserved.
- ARP helper tests use mocked packet functions only: one spoof direction, explicit adapter selection, and correct restoration addressing are checked. No packets are transmitted.

Final result: **18 automated checks passed**. Both documented certificate-generation methods succeeded in temporary folders and their localhost SANs were verified with OpenSSL. Source fingerprints match the original inspection manifest and both source checkouts remain clean. A final all-Markdown pass verified local links, fences, and Python snippets, including the optional extension. No generated keys, certificates, cached bytecode, or .git directory are included in the course folder.

See [VALIDATION_RESULT.json](VALIDATION_RESULT.json) for the machine-readable record. The validation harness was retained outside the student distribution in the local inspection workspace; this repository includes its results, not completed student test files. Publication also checks tracked-file selection and destination history before a normal, non-forced push.

## Limits

Docker CLI/Compose is installed, but Docker's engine socket is absent. No Docker images were built, no real MySQL service/migrations were run, and no full cumulative hardened application was executed. Mocked database checks do not establish actual SQL injection syntax or query behavior in MySQL.

No live ARP attack, packet capture, Windows/macOS/Linux forwarding, Burp/ZAP scan, vulnerability advisory download, or native/container Ollama model run was performed. Browser certificate trust, CSP behavior, hardware performance, and nondeterministic AI outcomes need the teaching team's runtime walkthrough. Local tests do not certify that a student's future remediation implementation is correct.

[Instructor checklist](INSTRUCTOR_REVIEW.md) · [Source/decision record](MERGE_NOTES.md)
