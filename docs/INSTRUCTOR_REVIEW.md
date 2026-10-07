# Instructor Review and Customization

This is the complete local Autumn draft. The nine lab files are canonical; change them directly, keeping the course index and troubleshooting guide consistent.

## Fill In Before Distribution

- Course calendar, lecture weekdays, due dates, midterm timing, grading weights, LMS destination, and support/office-hour links.
- Confirm access to [UW-INFO-310/huskyhub](https://github.com/UW-INFO-310/huskyhub) for your students. Setup uses this course repository or its ZIP download, without fetching the Spring/Summer sources.
- Week 2 device availability: the corrected MITM needs distinct client/server/attacker endpoints. Two laptops plus a browser-capable phone can supply them. Provide a tested isolated setup for students who lack the devices or have restricted routing/firewall policies.
- Decide how the optional Week 3 certificate-trust and Week 5 detection extensions are assessed. No extra-credit points were invented.
- Check available RAM/GPU and model performance for Week 9. Native Ollama is preferred, with a slower container fallback; no Discord file replacement is needed.

## Runtime Walkthrough Still Needed

Docker's engine was stopped during this build. Complete a fresh container build and the cumulative student walkthrough before release: plaintext HTTP starter, Week 3 migration/TLS, Week 4 logging/error codes, Week 5 signed sessions/lockout, Week 6 permissions, Week 7 injection/parameterization, Week 8 authenticated scans/CSP/UI behavior, and Week 9 real model answers.

Test Windows/macOS/Linux network forwarding on the teaching setup; verify packet paths and recovery without using a shared network. Confirm certificate trust behavior in the chosen browser and remove imported trust after the exercise. Test current Burp/ZAP interfaces and how scanning interacts with account lockout. Record actual model outcomes rather than assuming all prompt injections succeed.

## Keep Student Work Intact

Keep one cumulative copy. Starter files intentionally lack the student hardening; do not distribute a final hardened instructor copy as the starter. Preserve account approval, normal workflows, seeded usernames/passwords, and meaningful historical grade fixtures. If you change a service, port, endpoint, dependency, or submission, update all affected labs together.

[Merge provenance](MERGE_NOTES.md) · [Validation detail](VALIDATION.md)
