# Lab workflow and report guide

Work from the `huskyhub` folder every week. Your code, database, HTTPS settings, and later signed sessions carry forward.

## Before and after each lab

1. Check earlier fixes still work. Do not preemptively complete a later week's remediation.
2. Record vulnerable behavior before changing it. Include account, URL, request, status code, and relevant output.
3. Save a code backup before editing. Version control is optional and local; the labs do not require publishing anything.
4. Rebuild after Python/dependency edits. Recreate Flask after `.env` edits. Keep `.env` and generated private keys out of submissions.
5. Repeat the attack and a normal user workflow after remediation. An error, an empty response, or a login redirect is not proof that a protected page was tested successfully.

## Report format

Use one report per required week with these four sections. Due dates, weights, and LMS submission location are **TBD by the instructor**.

| Section | Include |
|---|---|
| 1. Work and observations | What you attempted; account/endpoint; before-and-after evidence for required steps; unexpected results. |
| 2. Changes and verification | Files changed; explanation of defenses; attack outcomes and normal-use checks; scripts/test output when requested. |
| 3. Class Principles | Answers to that week's Write-Up Questions. |
| 4. Hacker Mindset | Responses to reflection prompts. |

Include files you wrote or changed (or a readable diff), plus the evidence/tests named in the lab. Keep screenshots legible. Mark optional extensions separately. Report inconclusive or failed attempts honestly; do not invent model outputs or scan findings. Do not include `.env`, `nginx/key.pem`, runtime uploads, Docker volumes, or unrelated personal data.

## Authentication and HTTPS in later tools

From Week 3 onward use `https://localhost`. Some examples use `verify=False` or `curl -k` for this local self-signed lab certificate. Browser trust and Python's certificate trust are separate; the optional trust extension does not automatically configure `requests`.

From Week 5 onward obtain a real signed `session` cookie by logging in. Old `authenticated`, `role`, and `user_id` cookies should no longer grant access. Burp and ZAP need an authenticated browser/context; scripts must confirm successful login before testing protected pages.

## Recovering after a reset

Resetting Docker volumes deletes data without reverting application code. Preserve evidence and note your hardening stage before resetting.

- **Weeks 1–2:** unchanged seed data matches starter login.
- **Week 3 onward:** restart, then rerun your idempotent password migration on fresh plaintext records. Copy `flask/migrate_passwords.py` back into a recreated container first. New registrations must already be hashed by your registration route.
- **Week 5 onward:** include `failed_attempts` and `lockout_until` in your seed table definition. A reset clears counters and restores fixture users; rerun hashing as above.
- **Weeks 7–9:** parameterized queries and output encoding remain in code, while test messages, documents, and custom accounts may need recreating. Native Ollama models live outside Docker; pull the container model again if its volume was deleted.

Confirm normal student login, unapproved-account rejection, student grades, and advisor/admin workflows before continuing. For lockout tests, clear only the test account's counters rather than deleting every volume.
