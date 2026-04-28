# terraform-project-3
terrraform-project-3
project link
https://claude.ai/share/f9298bf2-53cd-44b5-b827-5a54d2b9e4ad


steps:

Terraform Assignment – Detailed Step-by-Step Guide

📁 Project Structure
terraform-assignment/
├── .github/
│   └── workflows/
│       └── terraform.yml
├── main.tf
├── variables.tf
├── outputs.tf
├── backend.tf
└── terraform.tfvars

STEP 1 — Create Workspace & Deploy Resources
1.1 — Initialize Project Files
variables.tf
hclvariable "aws_region" {
  default = "us-east-1"
}

variable "environment" {
  default = "dev"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "instance_type" {
  default = "t2.micro"
}
main.tf
hclterraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "tf-assignment-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Subnet
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "tf-assignment-subnet"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Security Group
resource "aws_security_group" "main" {
  name        = "tf-assignment-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "tf-assignment-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]

  tags = {
    Name        = "tf-assignment-ec2"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Fetch latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# S3 Bucket (for remote backend — created separately first)
resource "aws_s3_bucket" "tf_state" {
  bucket = "tf-assignment-state-${random_id.suffix.hex}"

  tags = {
    Name      = "tf-assignment-state"
    ManagedBy = "terraform"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB for state locking
resource "aws_dynamodb_table" "tf_lock" {
  name         = "tf-assignment-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "tf-assignment-lock"
    ManagedBy = "terraform"
  }
}
outputs.tf
hcloutput "vpc_id" {
  value = aws_vpc.main.id
}

output "instance_id" {
  value = aws_instance.main.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "security_group_id" {
  value = aws_security_group.main.id
}

1.2 — Create Workspace & Deploy
bash# Initialize Terraform
terraform init

# Create and switch to 'dev' workspace
terraform workspace new dev
terraform workspace list     # confirm you're on 'dev'

# Preview the plan
terraform plan -out=tfplan

# Apply (deploy all resources)
terraform apply tfplan

✅ Screenshot checkpoint: Take a screenshot of terraform apply success output and the AWS Console showing the VPC, EC2, S3, and DynamoDB resources.


STEP 2 — Introduce Manual Drift via AWS Console
Log into the AWS Console and make these manual changes:
ResourceManual ChangeEC2 InstanceAdd a new tag: ManualTag = "drift-test"Security GroupAdd inbound rule: port 8080, source 0.0.0.0/0VPCChange the Name tag to "manual-changed-vpc"
After making changes, run:
bash# Detect drift — Terraform will show what changed outside of code
terraform plan
You will see output like:
~ resource "aws_instance" "main" {
    ~ tags = {
        + "ManualTag" = "drift-test"
        ...
      }
  }

~ resource "aws_security_group" "main" {
    ~ ingress = [
        + {
            from_port   = 8080
            to_port     = 8080
            ...
          }
      ]
  }

✅ Screenshot checkpoint: Screenshot the terraform plan output highlighting the ~ (change) lines — this is your drift report.


STEP 3 — Resolve the Drifts
You have two options to resolve drift:
Option A — Revert (Terraform wins — recommended for IaC discipline)
bash# Apply to force AWS back to match Terraform code
terraform apply -auto-approve
This removes the manual tag, deletes the extra SG rule, and reverts the VPC name.
Option B — Import (AWS wins — absorb drift into code)
If the manual change was intentional, update your .tf file first, then verify:
hcl# In main.tf — add the new SG rule intentionally
ingress {
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "App port"
}
Then run:
bashterraform plan    # Should show "No changes" — drift resolved
terraform apply

✅ Screenshot checkpoint: Screenshot terraform plan showing "No changes. Infrastructure is up-to-date." after resolution.


STEP 4 — Migrate to Remote Backend (S3)
4.1 — Get the S3 bucket name from outputs
bashterraform output s3_bucket_name
# e.g., tf-assignment-state-a1b2c3d4
4.2 — Create backend.tf
hcl# backend.tf
terraform {
  backend "s3" {
    bucket         = "tf-assignment-state-a1b2c3d4"   # ← your actual bucket name
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-assignment-lock"
    encrypt        = true
  }
}
4.3 — Migrate local state to remote
bash# Re-initialize — Terraform detects the new backend and migrates state
terraform init -migrate-state
You'll see:
Do you want to copy existing state to the new backend? Enter "yes"
Type yes. Your state is now stored securely in S3 with DynamoDB locking.

✅ Screenshot checkpoint: Screenshot the S3 Console showing the dev/terraform.tfstate object inside your bucket.


STEP 5 — GitHub Actions Pipeline
5.1 — Add AWS Credentials as GitHub Secrets
In your GitHub repo → Settings → Secrets and variables → Actions, add:
Secret NameValueAWS_ACCESS_KEY_IDYour AWS access keyAWS_SECRET_ACCESS_KEYYour AWS secret keyAWS_REGIONus-east-1TF_BACKEND_BUCKETYour S3 bucket name

5.2 — Create the Workflow File
.github/workflows/terraform.yml
yamlname: Terraform CI/CD

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:        # allows manual trigger from GitHub UI

env:
  TERRAFORM_VERSION: 1.14.9
  AWS_REGION: ${{ secrets.AWS_REGION }}

jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest
    environment: dev

    defaults:
      run:
        working-directory: .

    steps:
      # ── 1. Checkout code ──────────────────────────────────────────
      - name: Checkout Repository
        uses: actions/checkout@v4

      # ── 2. Configure AWS credentials ──────────────────────────────
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ secrets.AWS_REGION }}

      # ── 3. Install Terraform ───────────────────────────────────────
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      # ── 4. Init (connects to remote S3 backend) ───────────────────
      - name: Terraform Init
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" \
            -backend-config="key=dev/terraform.tfstate" \
            -backend-config="region=${{ secrets.AWS_REGION }}" \
            -backend-config="dynamodb_table=tf-assignment-lock" \
            -backend-config="encrypt=true"

      # ── 5. Format check ───────────────────────────────────────────
      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      # ── 6. Validate ───────────────────────────────────────────────
      - name: Terraform Validate
        run: terraform validate

      # ── 7. Plan (on PRs — shows diff, never applies) ──────────────
      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        continue-on-error: true       # don't fail pipeline, post comment instead

      # ── 8. Post plan output as PR comment ─────────────────────────
      - name: Post Plan to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan 📋
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            *Pusher: @${{ github.actor }}*`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

      # ── 9. Apply (only on push to main) ───────────────────────────
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan

      # ── 10. Show outputs ──────────────────────────────────────────
      - name: Terraform Output
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform output

5.3 — Push and Trigger the Pipeline
bash# Stage all files
git init
git add .
git commit -m "feat: terraform assignment with remote backend and CI/CD"

# Push to main — this triggers the GitHub Actions workflow
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main

✅ Screenshot checkpoint: Go to your repo → Actions tab → click the running workflow → screenshot the green checkmarks on each step, especially Terraform Apply.


Summary Checklist
StepActionEvidence✅ 1Workspace created, resources deployedterraform apply success screenshot✅ 2Manual changes made in AWS ConsoleConsole screenshot + terraform plan drift output✅ 3Drift resolved via terraform applyNo changes plan screenshot✅ 4State migrated to S3 remote backendS3 Console showing .tfstate object✅ 5GitHub Actions pipeline triggered and passedActions tab green run screenshot

Pro tip for screenshots: Use the terraform plan output with color using terraform plan 2>&1 | tee plan.txt to save a copy, and use the AWS Console's CloudTrail to show the manual change timestamps as extra evidence of drift.