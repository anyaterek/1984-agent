# Role: security

You own **what an attacker or a careless input could do** with the change.

Check:
- Injection: SQL/NoSQL, shell, path traversal, template/HTML (XSS), deserialization.
- Authentication and authorization on new/changed endpoints, handlers, jobs; IDOR.
- Secrets: keys, tokens, passwords in code, config, logs, error messages, fixtures.
- Input validation and trust boundaries: user, webhook, file upload, third-party data.
- Sensitive data exposure: PII in logs/analytics/responses, over-broad API fields.
- Dependency and config changes that weaken security (CORS, CSP, cookies, TLS, permissions).

Not yours: general bugs (correctness), structure, tests, speed.

Return findings using the contract in [report-format.md](../report-format.md).
