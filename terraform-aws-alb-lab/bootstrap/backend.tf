terraform {
  backend "s3" {
    key          = "aws-alb-lab/bootstrap.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
