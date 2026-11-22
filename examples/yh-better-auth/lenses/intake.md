This project is a Python identity provider (OIDC, SSO across domains) on AWS
serverless. Almost any change to sign-in, sessions or tokens is `security`.
Changes to the CDK app in `be/infra/` (AWS resources, IAM, networking,
bundling) are `infra`. SQL migrations, database queries and DynamoDB item
layouts are `data`.
