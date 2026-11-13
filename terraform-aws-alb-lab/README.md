# AWS ALB Behavior Lab

Disposable AWS exercise for observing how an Application Load Balancer routes
requests to Lambda and EC2 targets and how its evidence changes when individual
boundaries fail.

This is deliberately independent of EKS. A later EKS exercise should let the
AWS Load Balancer Controller own its load balancers instead of sharing
authority with this Terraform root.

## Architecture

```text
client
  |
  v
internet-facing ALB :80
  |-- /lambda, /lambda/* --> Lambda target group --> Lambda
  |-- /ec2, /ec2/* ------> instance target group -> EC2 :8080
  `-- unmatched path ----> fixed 404 response from the ALB
```

The ALB spans two public subnets. The single EC2 target has no public IPv4
address, accepts port 8080 only from the ALB security group, and does not expose
SSH. There is no NAT gateway. ALB access logs expire after seven days and are
deleted with the lab.

The configuration pins Terraform, providers, GitHub Actions, and upstream
modules. Dependency upgrades must be deliberate changes with a new plan.

## Cost boundary

The lab creates billable resources, including an ALB, one `t3.nano` instance,
an 8 GiB gp3 volume, S3 objects, Lambda invocations, CloudWatch logs, and any
applicable data transfer. The ALB continues billing while it exists even when
idle.

The `ttl-hours` tag declares a maximum lifetime of 24 hours by default but does
not destroy resources automatically. The operator owns the teardown check:

1. Run the approved `destroy` workflow after every exercise.
2. Confirm the workflow reports `Destroy complete`.
3. Run a fresh `plan`; it must report no changes except a proposed recreation
   of the lab.
4. Confirm the AWS billing dashboard and Resource Explorer show no unexpected
   lab resources.

The state bucket and two GitHub OIDC roles are durable bootstrap resources and
are not part of lab teardown.

## One-time bootstrap

Bootstrap creates:

- a versioned, encrypted S3 state bucket with native S3 lock files;
- a read-only GitHub Actions role for speculative plans; and
- a deployment role trusted only by the `aws-alb-lab` GitHub environment.

The GitHub OIDC provider is account-wide. If one already exists, set
`create_github_oidc_provider = false` and supply its ARN instead of attempting
to create a duplicate.

The first bootstrap apply requires an existing human AWS credential. It does
not run in GitHub Actions:

```bash
cd terraform-aws-alb-lab/bootstrap
cp terraform.tfvars.example terraform.tfvars

terraform init -backend=false
terraform plan -out=tfplan
terraform apply tfplan
```

After the bucket exists, migrate the bootstrap state into it. Replace the
placeholder with the `state_bucket_name` output:

```bash
terraform init -migrate-state \
  -backend-config="bucket=STATE_BUCKET_NAME" \
  -backend-config="region=us-west-2"
```

Configure these GitHub repository variables from the bootstrap outputs:

| Repository variable | Bootstrap output |
|---|---|
| `AWS_ALB_LAB_REGION` | chosen AWS Region |
| `AWS_ALB_LAB_ACCOUNT_ID` | `aws_account_id` |
| `AWS_ALB_LAB_STATE_BUCKET` | `state_bucket_name` |
| `AWS_ALB_LAB_PLAN_ROLE_ARN` | `plan_role_arn` |
| `AWS_ALB_LAB_DEPLOY_ROLE_ARN` | `deploy_role_arn` |

Create a GitHub environment named `aws-alb-lab`, restrict it to the default
branch, and require approval from `eckslopez`. The environment protection is
the authority boundary between a reviewed saved plan and an AWS write.

The plan role trusts same-repository pull requests and the default branch.
Plans from forks are skipped. The deployment role trusts only jobs using the
protected environment. Both legacy and immutable GitHub OIDC subjects are
listed explicitly using this organization's and repository's permanent IDs;
there is no wildcard subject trust. Neither role uses a stored AWS access key.

## Pipeline

Pull requests run formatting and validation for both Terraform roots. After
bootstrap variables exist, same-repository pull requests also run a speculative
plan with the read-only role.

Manual dispatch supports three operations:

- `plan` creates and displays a plan without an apply;
- `apply` creates a saved plan, waits for the protected-environment approval,
  then applies that exact plan; and
- `destroy` creates a saved destroy plan, waits for approval, then applies that
  exact plan.

Saved plan artifacts can contain sensitive state and configuration. They are
retained for one day and are never committed.

## Baseline observations

After an approved apply, wait for the EC2 target to become healthy and use the
Terraform outputs:

```bash
curl -i "$(terraform output -raw lambda_url)"
curl -i "$(terraform output -raw ec2_url)"
curl -i "$(terraform output -raw intentional_ec2_503_url)"
curl -i "http://$(terraform output -raw alb_dns_name)/unmatched"
```

Expected boundaries:

| Request | Expected response origin |
|---|---|
| `/lambda` | Lambda target |
| `/ec2` | EC2 target |
| `/ec2/fail` | EC2 target intentionally returning 503 |
| `/unmatched` | ALB fixed-response action returning 404 |

For each request, compare the response with:

- the ALB access-log fields `actions_executed`, `target_status_code`,
  `elb_status_code`, target address, and timing fields;
- the `AWS/ApplicationELB` request, response-code, connection-error, and
  target-health metrics;
- target-group health and reason codes; and
- Lambda or EC2 application logs where the request reached a target.

An ALB metric identifies an affected boundary over a time window. It does not
establish the path or issuer for one request. Use the access-log record for that
request before descending into a target.

## Controlled failures

Change and deploy only one condition at a time, predict the evidence before
observing it, and restore the baseline before the next repetition.

1. Change the EC2 health-check path to `/missing`.
2. Remove or alter the EC2 ingress rule from the ALB security group.
3. Return an invalid ALB response object from Lambda.
4. Deregister one target through Terraform configuration.
5. Change listener priorities or path patterns so a request matches a different
   action.

For each failure, record separately:

- what the observation proves;
- what it only suggests; and
- what remains unknown.

Live findings belong in the existing local ALB request-path observation after
the experiment. Infrastructure code alone is not runtime evidence.

## Teardown

Use the `destroy` workflow while the same Terraform commit and state are still
available. The bootstrap state's `prevent_destroy` lifecycle rule deliberately
keeps the state bucket out of routine teardown.

If a destroy fails, do not delete state or resources manually. Preserve the
failure output, repair the configuration or permission boundary, and run a new
destroy plan.
