terraform {
  backend "s3" {
    bucket   = "tf-assignment-state-a16adb43"
    key      = "dev/terraform.tfstate"
    region   = "us-east-1"
    encrypt  = true
    use_lockfile = true  # ← instead of dynamodb_table
  }
}