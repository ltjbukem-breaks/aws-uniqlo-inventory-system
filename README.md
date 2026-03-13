# aws-multi-source-ETL
Multi-Source E-Commerce ETL Pipeline

```text
1. Data Sources
S3 Bucket (sales-data-bucket) - receives sales JSON files

S3 Bucket (product-updates-bucket) - receives product/price change files

EventBridge Rule - triggers restock Lambda on schedule (e.g., every 6 hours)

2. Processing (Lambda Functions)
sales-processor - triggered by S3 sales uploads, validates, writes to RDS

product-updater - triggered by S3 product uploads, updates products table

inventory-restock - triggered by EventBridge, checks low stock, restocks

3. Storage
RDS PostgreSQL (db.t3.micro) - stores products, sales, inventory_logs tables

Lives in VPC with private subnets (Lambdas need VPC access to reach RDS)
- the reasoning for this is so that the PostgreSQL db can't be accessed via the public internet,
only the private connections within the VPC (like the Lambdas function).
- drawback is that the Lambdas function when configured to run inside the VPC, can't connect to the internet

4. Error Handling
SQS DLQ for each Lambda (3 DLQs total)

Failed messages go to DLQ after retry attempts

Optional: SNS Topic to email you when DLQ receives messages

5. CI/CD
GitHub Actions workflow

On push to main: runs terraform plan → terraform apply

Runs tests before deployment

Example flow

Step 1: Tests Run
- Run unit tests (Python pytest for Lambda functions)
- Run Terraform validation (terraform fmt, terraform validate)
- If tests fail → pipeline stops, no deployment

Step 2: Terraform Plan
- terraform init (download providers)
- terraform plan (show what will change)
- Review the plan output in GitHub Actions logs

Step 3: Terraform Apply (only on main branch)
- terraform apply -auto-approve
- Creates/updates AWS resources
- Uploads Lambda code to AWS

6. Networking
VPC with public + private subnets

Security Groups (Lambda → RDS access only)

NAT Gateway OR VPC Endpoints (for Lambda to access S3/Secrets Manager) - using VPC endpoints to stay free
-using secrets manager (costs $0.40 a month) since it has better integration w/ RDS
```

## Project file structure
```text
aws-multi-source-ETL/
├── terraform/
│   ├── main.tf              # Root module, calls all other modules
│   ├── variables.tf         # Input variables (region, project name, etc.)
│   ├── outputs.tf           # Outputs (RDS endpoint, S3 bucket names, etc.)
│   ├── providers.tf         # AWS provider configuration
│   │
│   ├── modules/
│   │   ├── networking/      # VPC, subnets, security groups, VPC endpoints
│   │   ├── storage/         # S3 buckets, RDS database
│   │   ├── compute/         # Lambda functions
│   │   ├── messaging/       # SQS DLQs, SNS topic
│   │   └── scheduling/      # EventBridge rule for inventory restock
│   │
├── lambda/
│   ├── sales_processor/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   ├── product_updater/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   └── inventory_restock/
│       ├── lambda_function.py
│       └── requirements.txt
│
├── tests/
│   ├── test_sales_processor.py
│   ├── test_product_updater.py
│   └── test_inventory_restock.py
│
├── .github/
│   └── workflows/
│       └── deploy.yml       # GitHub Actions CI/CD pipeline
│
└── README.md
```

# Order of work
```text
Phase 1: Foundation & Networking ✅ 
Set up Terraform project structure (providers.tf, variables.tf, outputs.tf, main.tf)
Configure AWS provider + backend (where Terraform stores state)
Build networking module:
VPC
Public + private subnets (across 2 availability zones for RDS requirement)
Internet Gateway
Route tables
Security groups (Lambda SG, RDS SG)
VPC Endpoints (S3, Secrets Manager)
Deliverable: Network infrastructure ready for RDS + Lambdas

Phase 2: Storage Layer
Build storage module:
2 S3 buckets (sales-data, product-updates)
RDS PostgreSQL instance (db.t3.micro)
Secrets Manager secret for RDS credentials
DB subnet group

Initialize database schema:
Create products table
Create sales table
Create inventory_logs table
Seed initial product data (optional)
Deliverable: Database + S3 buckets ready to receive data

Phase 3: Lambda Functions (Code)
Write Python code for 3 Lambda functions:
sales_processor/lambda_function.py - parse sales JSON, validate, insert into DB
product_updater/lambda_function.py - parse product updates, update DB
inventory_restock/lambda_function.py - check stock, restock logic
Create requirements.txt for each (psycopg2, boto3, etc.)
Deliverable: Lambda code ready to deploy

Phase 4: Compute Infrastructure
Build compute module:
Create 3 Lambda functions in Terraform
Configure VPC access for Lambdas
Set up IAM roles/policies (S3 read, Secrets Manager read, RDS access)
Configure S3 event notifications → Lambda triggers
Package and deploy Lambda code
Deliverable: Lambdas deployed and triggered by S3 uploads

Phase 5: Error Handling
Build messaging module:
Create 3 SQS DLQs (one per Lambda)
Configure Lambda DLQ settings
Create SNS topic for alerts
Create email subscription to SNS
Set up CloudWatch alarms (DLQ message count → SNS)
Deliverable: Failed Lambda invocations go to DLQ, you get email alerts

Phase 6: Scheduling
Build scheduling module:
Create EventBridge rule (cron: daily at 2 AM)
Configure EventBridge → inventory-restock Lambda trigger
Set up IAM permissions
Deliverable: Inventory restock runs automatically once per day

Phase 7: Testing
Write unit tests for Lambda functions:
test_sales_processor.py - test data validation, DB insertion logic
test_product_updater.py - test product update logic
test_inventory_restock.py - test restock threshold logic
Write integration tests (optional):
Test end-to-end flow with mock S3 events
Test database connections
Deliverable: Test suite that validates Lambda logic

Phase 8: CI/CD Pipeline
Create .github/workflows/deploy.yml:
Run tests on every push
Run terraform fmt and terraform validate
Run terraform plan on pull requests
Run terraform apply on push to main branch
Set up GitHub secrets (AWS credentials)
Configure Terraform backend (S3 + DynamoDB for state locking)
Deliverable: Automated deployment pipeline

Phase 9: Documentation & Testing
Update README.md with:
Architecture diagram
Setup instructions
How to test the pipeline (upload sample files)
Create sample data files (sales.json, products.json)
Manual end-to-end test
Deliverable: Complete, documented project ready for portfolio
```