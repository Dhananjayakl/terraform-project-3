# backend.tf
terraform {
  backend "s3" {
    bucket         = "tf-assignment-state-a16adb43"   # ← your actual bucket name
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-assignment-lock"
    encrypt        = true
  }
}