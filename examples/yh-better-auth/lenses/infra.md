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
