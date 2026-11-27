<!--
PLACEHOLDER: this lens is not filled in yet.

Read by the data reviewer. Replace this whole comment with short bullets about this
repo: migration rules and query conventions. Name real files, folders and rules, so each bullet can be checked
against a diff. Delete a lens you don't need. See factory/lenses/README.md.

For example (rewrite for this repo), this is from a fictional repo:

- Migrations: a new numbered file in `be/src/yh_better_auth/migrations/`; never
  edit an applied migration. The migrator splits on line-ending semicolons, so
  no functions or DO blocks unless the splitter is extended.
- Constraints: login email uniqueness via a citext index, enforced in the
  database.
- Queries: named `:params` through `DataApi`; correct `typeHint` for
  JSON/UUID/timestamps; result sets paged (Data API 1 MB limit). The Data API
  cannot return `citext`: cast to `text` in the SELECT.
- Indexes: JSONB filters on `users.data` use the GIN index or an expression
  index.
- DynamoDB: key design (`pk`/`sk` prefixes), TTL on `expires_at` in epoch
  seconds, no scans on request paths, conditional writes where races matter.
-->

No project-specific guidance yet: use your general review method.
