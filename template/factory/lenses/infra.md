<!--
PLACEHOLDER: this lens is not filled in yet.

Read by the infra reviewer. Replace this whole comment with short bullets about this
repo: naming rules, required settings, and what must never be public. Name real files, folders and rules, so each bullet can be checked
against a diff. Delete a lens you don't need. See factory/lenses/README.md.

For example (rewrite for this repo), this is from a fictional repo:

- Exposure: nothing newly public: S3 block-public-access, Aurora not publicly
  accessible, API reachable only through CloudFront, WAF still attached.
- Naming: resources prefixed `yh-better-auth-<stage>-` and parameterised by
  stage; use `grant_*` helpers over hand-written `*` policies.
- Lambda: arm64, Python 3.12, sane timeouts and memory, log retention set,
  bundling through `be/infra/bundling.py` (no layers, no Docker).
- Data safety: `RETAIN`/`SNAPSHOT` in prod, `DESTROY` only in dev, PITR,
  deletion protection, KMS key pending windows.
- Cost: new always-on resources (NAT gateways, provisioned capacity, min ACU
  above 0 in dev) called out.
- Synth: `cdk synth --no-lookups` still works from committed context.
-->

No project-specific guidance yet: use your general review method.
