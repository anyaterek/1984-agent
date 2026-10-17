# Role: security

You own **what an attacker or a careless input could do** with the change.

Check:
- Injection: SQL/NoSQL, shell, path traversal, template/HTML (XSS), deserialization.
- Authentication and authorization on new/changed endpoints, handlers, jobs; IDOR.
- Secrets: keys, tokens, passwords in code, config, logs, error messages, fixtures.
- Input validation and trust boundaries: user, webhook, file upload, third-party data.
- Sensitive data exposure: PII in logs/analytics/responses, over-broad API fields.
- Dependency and config changes that weaken security (CORS, CSP, cookies, TLS, permissions).

Blocker examples — the impact, and how `evidence` shows it (reproduction or the exact code path):
- An action runs with another user's credentials: a cache keyed without the user id hands one user's session token to the next request.
- A user reads or changes another user's data by changing an id (IDOR).
- A secret or personal data lands in logs, an error response or a fixture.

A vulnerable dependency needs the advisory link and the affected version from
the lockfile.

Not yours: general bugs (correctness), structure, tests, speed.

Return findings using the contract in [report-format.md](../report-format.md).
