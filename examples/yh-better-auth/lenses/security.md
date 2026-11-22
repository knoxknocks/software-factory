Hot spots in this project (an identity provider):

- Passwords: Argon2id params, legacy PBKDF2 verify, constant-time compares,
  pepper handling; passwords or hashes never logged.
- Sessions and tokens: only hashes of tokens stored; cookie flags
  (`__Host-`, HttpOnly, Secure, SameSite); expiry enforced in code, not only by
  DynamoDB TTL; revocation takes effect immediately.
- Account enumeration: identical responses and similar timing for unknown
  email vs wrong password; sign-up doesn't reveal existing emails.
- Origin/CSRF checks on state-changing endpoints; open redirects via
  `return_to` or redirect URIs.
- SQL through `DataApi`: always named parameters, never string formatting.
- IAM grants in `be/infra/` are least privilege; secrets come from Secrets
  Manager or KMS, never env literals.
