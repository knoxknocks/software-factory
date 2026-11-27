# Example: a real repo's lenses and checks

These are the lenses and `checks.sh` the factory runs with in
yh-better-auth (a private repo), a Python OIDC
identity provider on AWS serverless. They show the level of detail that helps:
short, checkable bullets naming this project's real hot spots.

To use them as a starting point:

```bash
cp examples/yh-better-auth/lenses/*.md  <your-repo>/factory/lenses/
cp examples/yh-better-auth/checks.sh    <your-repo>/factory/checks.sh
```

then rewrite every bullet for your own project.
