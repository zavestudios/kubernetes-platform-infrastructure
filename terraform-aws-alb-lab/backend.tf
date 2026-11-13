terraform {
  backend "s3" {
    key          = "aws-alb-lab/lab.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
