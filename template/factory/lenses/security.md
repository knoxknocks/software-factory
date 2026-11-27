<!--
PLACEHOLDER: this lens is not filled in yet.

Read by the security reviewer. Replace this whole comment with short bullets about this
repo: where the sensitive code is and what must always hold there. Name real files, folders and rules, so each bullet can be checked
against a diff. Delete a lens you don't need. See factory/lenses/README.md.

For example (rewrite for this repo), this is from a fictional repo:

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
-->

No project-specific guidance yet: use your general review method.
