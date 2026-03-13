# Understanding Terraform - A Practical Guide

## What is Terraform and Why Use It?

### The Problem Without Terraform

Imagine you need to create your AWS infrastructure manually:

1. Log into AWS Console
2. Click through 20+ screens to create an S3 bucket
3. Click through more screens to create a Lambda function
4. Set up IAM roles (10+ clicks)
5. Configure EventBridge rules
6. Set up DynamoDB tables
7. Configure CloudWatch alarms
8. Repeat for dev, staging, and production environments

**Problems:**
- Takes hours of clicking
- Easy to make mistakes (typo in a setting)
- Hard to replicate exactly in another environment
- No record of what you created
- If you delete something by accident, you have to remember all the settings
- Team members don't know what infrastructure exists

### The Solution: Infrastructure as Code (IaC)

Terraform lets you write code that describes your infrastructure. Instead of clicking, you write:

```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-data-bucket"
}
```

Then run `terraform apply` and it creates the bucket for you.

---

## How Terraform Works (Simple Explanation)

### 1. You Write Configuration Files (.tf files)

Think of these as blueprints for your infrastructure:

```hcl
# This says: "I want an S3 bucket named my-bucket"
resource "aws_s3_bucket" "data_lake" {
  bucket = "my-bucket"
}

# This says: "I want a Lambda function"
resource "aws_lambda_function" "processor" {
  function_name = "my-processor"
  runtime       = "python3.11"
  # ... more settings
}
```

### 2. Terraform Reads Your Files

When you run `terraform plan`, Terraform:
- Reads all your .tf files
- Figures out what needs to be created
- Shows you a preview: "I will create 15 resources"

### 3. Terraform Creates Everything

When you run `terraform apply`:
- Terraform calls AWS APIs to create each resource
- It creates them in the right order (S3 bucket before Lambda that uses it)
- It saves the current state in a file

### 4. Terraform Tracks State

Terraform remembers what it created in a "state file":
```
Current state:
- S3 bucket "my-bucket" exists
- Lambda "my-processor" exists
- DynamoDB table "products" exists
```

### 5. You Can Update or Destroy

**Update:** Change your .tf file and run `terraform apply` again
- Terraform sees the difference and updates only what changed

**Destroy:** Run `terraform destroy`
- Terraform deletes everything it created

---

## Key Terraform Concepts

### 1. Resources

A resource is something you want to create in AWS:

```hcl
resource "TYPE" "NAME" {
  # settings
}
```

Example:
```hcl
resource "aws_s3_bucket" "data_lake" {
  bucket = "my-data-lake"
  # This creates an S3 bucket
}
```

**Real-world analogy:** Like ordering items from a catalog
- "TYPE" = what you're ordering (S3 bucket, Lambda, etc.)
- "NAME" = your nickname for it (so you can refer to it later)
- Settings = specifications (size, color, features)

### 2. Variables

Variables let you reuse values and customize deployments:

```hcl
variable "environment" {
  type = string
}

resource "aws_s3_bucket" "data_lake" {
  bucket = "my-bucket-${var.environment}"
  # In dev: "my-bucket-dev"
  # In prod: "my-bucket-prod"
}
```

**Real-world analogy:** Like a template
- You have a form letter with blanks: "Dear _____, "
- You fill in the blanks differently each time
- Same template, different values

### 3. Modules

Modules are reusable groups of resources:

```hcl
# Instead of writing S3 bucket code 5 times,
# write it once in a module:

module "data_lake" {
  source      = "./modules/s3"
  bucket_name = "my-bucket"
}

module "backup_bucket" {
  source      = "./modules/s3"
  bucket_name = "my-backup"
}
```

**Real-world analogy:** Like a recipe
- You write the recipe once (module)
- You can make the dish multiple times with different ingredients (variables)
- You don't rewrite the recipe each time

### 4. Outputs

Outputs let you get information from Terraform:

```hcl
output "bucket_name" {
  value = aws_s3_bucket.data_lake.bucket
}

# After terraform apply, you can see:
# bucket_name = "my-data-lake"
```

**Real-world analogy:** Like a receipt
- After you buy something, you get a receipt with details
- You can use those details later (like the bucket name in your Lambda code)

---

## How We're Using Terraform in This Project

### Our Structure

```
terraform/
├── main.tf              # Main configuration (calls modules)
├── variables.tf         # Input variables (environment, region, email)
├── outputs.tf           # Output values (bucket names, ARNs)
├── environments/
│   ├── dev.tfvars      # Dev values (environment = "dev")
│   └── prod.tfvars     # Prod values (environment = "prod")
└── modules/
    ├── s3/             # Reusable S3 bucket module
    ├── lambda/         # Reusable Lambda module
    ├── dynamodb/       # Reusable DynamoDB module
    └── sqs/            # Reusable SQS module
```

### Example: S3 Module

**modules/s3/main.tf** (the recipe):
```hcl
resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name  # Use the variable passed in
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id  # Reference the bucket above
  versioning_configuration {
    status = "Enabled"
  }
}
```

**modules/s3/variables.tf** (the ingredients list):
```hcl
variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the bucket"
}
```

**modules/s3/outputs.tf** (the receipt):
```hcl
output "bucket_name" {
  value = aws_s3_bucket.data_lake.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.data_lake.arn
}
```

### Using the Module in main.tf

```hcl
module "data_lake" {
  source      = "./modules/s3"           # Where the module is
  bucket_name = "ecommerce-data-lake-dev" # Pass in the bucket name
  tags = {
    Project = "ecommerce-etl"
    Environment = "dev"
  }
}

# Now you can use the outputs:
resource "aws_lambda_function" "processor" {
  # ...
  environment {
    variables = {
      BUCKET_NAME = module.data_lake.bucket_name  # Use the output!
    }
  }
}
```

---

## Real-World Benefits

### 1. Version Control

Your infrastructure is in Git:
```bash
git log
# commit abc123: Added CloudWatch alarms
# commit def456: Increased Lambda memory
# commit ghi789: Added new S3 bucket
```

You can see who changed what and when. You can roll back if something breaks.

### 2. Consistency

Same code = same infrastructure every time:
- Dev environment looks exactly like prod (just smaller)
- New team member can spin up their own environment
- No "it works on my machine" problems

### 3. Documentation

The code IS the documentation:
```hcl
# Anyone can read this and know exactly what exists:
resource "aws_lambda_function" "product_processor" {
  function_name = "product-processor-dev"
  runtime       = "python3.11"
  memory_size   = 256
  timeout       = 60
}
```

### 4. Collaboration

Multiple people can work on infrastructure:
```bash
# Person A adds S3 bucket
# Person B adds Lambda function
# Both push to Git
# Terraform merges the changes
# terraform apply creates both
```

### 5. Disaster Recovery

If AWS region goes down or you accidentally delete everything:
```bash
# Just run terraform apply again
# Everything gets recreated exactly as it was
```

### 6. Cost Management

You can see all resources in one place:
```bash
terraform state list
# Shows everything Terraform manages
# Easy to find and delete unused resources
```

---

## How Companies Use Terraform

### Startup (5-10 people)
- One person writes Terraform
- Everyone else reviews changes
- Deploy manually with `terraform apply`
- State stored in S3

### Mid-size Company (50-100 people)
- Infrastructure team writes Terraform modules
- Other teams use the modules
- CI/CD pipeline runs Terraform automatically
- Multiple environments (dev, staging, prod)
- State stored in Terraform Cloud

### Large Company (1000+ people)
- Dedicated platform team maintains Terraform
- Self-service portal for teams to request infrastructure
- Automated testing of Terraform changes
- Policy enforcement (can't create resources without tags)
- Multi-cloud (AWS, Azure, GCP)

### Example Workflow at a Company

```
1. Developer needs a new Lambda function
2. Developer writes Terraform code in a branch
3. Opens Pull Request on GitHub
4. CI/CD runs `terraform plan` and posts results
5. Team reviews the plan
6. After approval, merge to main
7. CI/CD runs `terraform apply` automatically
8. Lambda function is created
9. Slack notification: "New Lambda deployed"
```

---

## Common Terraform Commands

### terraform init
**What it does:** Downloads provider plugins (AWS, Azure, etc.)
**When to use:** First time in a new Terraform directory
```bash
cd terraform/
terraform init
```

### terraform plan
**What it does:** Shows what will change (preview)
**When to use:** Before applying, to see what will happen
```bash
terraform plan -var-file=environments/dev.tfvars
# Output: Will create 15 resources, change 2, destroy 0
```

### terraform apply
**What it does:** Creates/updates infrastructure
**When to use:** After reviewing the plan
```bash
terraform apply -var-file=environments/dev.tfvars
# Type "yes" to confirm
```

### terraform destroy
**What it does:** Deletes everything Terraform created
**When to use:** Tearing down a test environment
```bash
terraform destroy -var-file=environments/dev.tfvars
# Type "yes" to confirm
```

### terraform state list
**What it does:** Shows all resources Terraform manages
**When to use:** To see what exists
```bash
terraform state list
# Output:
# aws_s3_bucket.data_lake
# aws_lambda_function.processor
# ...
```

---

## Understanding Our Project's Terraform

### What Happens When You Run terraform apply

1. **Terraform reads all .tf files**
   - main.tf, variables.tf, modules/*/main.tf

2. **Terraform builds a dependency graph**
   ```
   S3 Bucket
      ↓
   Lambda Function (needs bucket name)
      ↓
   EventBridge Rule (needs Lambda ARN)
   ```

3. **Terraform creates resources in order**
   - Creates S3 bucket first
   - Then Lambda (passes bucket name as env var)
   - Then EventBridge rule (passes Lambda ARN)

4. **Terraform saves state**
   - Records what was created
   - Stores ARNs, IDs, names

### Example: Creating a Lambda Function

**What you write:**
```hcl
module "product_processor" {
  source        = "./modules/lambda"
  function_name = "product-processor-dev"
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  source_dir    = "../src/lambdas/product_processor"
}
```

**What Terraform does:**
1. Zips the source_dir folder
2. Uploads zip to AWS
3. Creates IAM role for Lambda
4. Creates Lambda function with the zip
5. Configures handler, runtime, memory, timeout
6. Returns the Lambda ARN as output

**Equivalent AWS Console clicks:** ~30 clicks across 5 different pages

---

## Why This Matters for Your Portfolio

### Shows Professional Skills

Recruiters look for:
- ✅ Infrastructure as Code experience
- ✅ Understanding of DevOps practices
- ✅ Ability to automate deployments
- ✅ Knowledge of best practices (modules, variables)

### Demonstrates Scalability

Without Terraform:
- "I manually created 5 Lambda functions"

With Terraform:
- "I built a modular infrastructure that can deploy to dev, staging, and prod with one command"

### Shows You Think Like an Engineer

- You're not just writing code
- You're thinking about deployment, maintenance, and team collaboration
- You understand the full software lifecycle

---

## Learning Path

### Start Simple
1. Create one S3 bucket with Terraform
2. Add a variable for the bucket name
3. Add an output for the bucket ARN

### Add Complexity
4. Create a Lambda function
5. Connect Lambda to S3 (Lambda reads from bucket)
6. Add EventBridge to trigger Lambda

### Modularize
7. Move S3 code to a module
8. Move Lambda code to a module
9. Reuse modules for multiple resources

### Production-Ready
10. Add multiple environments (dev, prod)
11. Add remote state storage (S3 backend)
12. Add CI/CD to run Terraform automatically

---

## Key Takeaways

1. **Terraform = Infrastructure as Code**
   - Write code instead of clicking in AWS Console

2. **Benefits:**
   - Repeatable (same code = same infrastructure)
   - Version controlled (track changes in Git)
   - Documented (code shows what exists)
   - Collaborative (team can work together)

3. **Core Concepts:**
   - Resources (things to create)
   - Variables (customizable values)
   - Modules (reusable components)
   - Outputs (information to use later)

4. **Real-world use:**
   - Every company with cloud infrastructure uses IaC
   - Terraform is the most popular tool
   - Essential skill for DevOps, Platform Engineering, Data Engineering

5. **For your project:**
   - Shows you can build production-grade infrastructure
   - Demonstrates automation and best practices
   - Makes you stand out from candidates who only click in AWS Console

Don't feel bad about copying code to start - everyone learns by example. The key is understanding what each piece does and being able to modify it for your needs. As you work through the project, you'll naturally learn how it all fits together.
