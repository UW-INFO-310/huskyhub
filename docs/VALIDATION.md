# Validation Record — Autumn 2026

## October 20 — Week 3 AI Revision

- The complete supplied AI tests produce **5 expected failures and 3 passes** on the vulnerable starter. In a temporary copy with only the README's Steps 6–8 applied, **all 8 pass**. The distributed starter application remains unsolved.
- Independently restoring excessive prompt context, the unwrapped document prompt, the debug HTML comment, or unsafe response rendering produces the corresponding failures (1, 2, 1, and 1). These checks exercise the real Flask route, prompt builder, document reader, and template with controlled database/Ollama boundaries.
- The existing **18 validation checks pass** after updating lab paths and recognizing the supplied test file. The pinned Flask/Werkzeug/Jinja/requests/MySQL-connector packages were installed in a temporary Python 3.12 environment. Production Docker uses Python 3.11 and was not executed.
- Both normal and optional-AI Compose configurations parse. All nine lab titles, Week 3's nine steps and three questions, local Markdown links, code fences, Python syntax, moved authentication assets, and unchanged starter application/dependency files were checked.
- Summer's first five AI steps retain their structure and wording with the obsolete Discord notice removed, date/record-field corrections, removed SQL-injection comparison, and updated internal step references. The XSS exploit, test-writing assignment, and submission checklist are absent from the AI README.

Docker's engine socket is absent. No image build, real MySQL/Ollama run, or full cumulative student walkthrough was performed. The supplied deterministic tests validate code changes rather than certifying live-model prompt-injection resistance. Earlier checks and their original limits remain recorded below.

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

## Week 2 Documentation Revision — October 13, 2026

Verified the six-step sequence and preceding Wireshark tutorial, Summer's exact Write-Up Questions/Hacker Mindset and platform installation sections, and the policy warning with only the selected-target ARP sentence corrected. Checked local Markdown links and balanced code fences across the distributed course. The lab and setup guide contain no virtual-environment commands or added submission checklist.

The ARP helpers differ only in comments and printed usage/example text. Both missing-argument help paths were checked with Scapy packet functions replaced by stubs that fail if called; no packets were sent. The original 18 runtime checks above remain the October 6 results. No live capture, forwarding change, or hardware walkthrough was performed for this documentation revision.
