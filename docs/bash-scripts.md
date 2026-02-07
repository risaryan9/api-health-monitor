# Bash Scripts Documentation

## Overview

- Two main scripts: install.sh (deploy) and shutdown.sh (teardown).
- Both use bash; install.sh sets ROOT_DIR from script location so it can run from any working directory.
- No emojis in documentation; scripts may use colored output and symbols for console UX.

## install.sh

- **Purpose:** End-to-end deployment: prerequisites, config, package Lambdas, Terraform apply, deploy Lambda code, deploy frontend, print URLs and next steps.
- **Flow:**
  1. Print banner; cd to ROOT_DIR.
  2. check_prerequisites: AWS CLI, credentials (sts get-caller-identity), Terraform, Node.js, npm, zip; sets AWS_ACCOUNT_ID, AWS_REGION.
  3. prompt_configuration: If terraform.tfvars missing, prompt for alert_email, region; write terraform/terraform.tfvars.
  4. package_lambdas: For api-handler, orchestrator, worker: npm install in lambdas/<name>, zip to .build/<name>.zip.
  5. deploy_infrastructure: cd terraform; terraform init, validate, plan -out=tfplan, apply tfplan; terraform output -json to ROOT_DIR/terraform-outputs.json; cd back.
  6. deploy_lambdas: Read api_handler_function_name, orchestrator_function_name, worker_function_name from terraform-outputs.json via get_tf_output (jq or python3); exit with clear error if any empty; aws lambda update-function-code for each zip.
  7. deploy_frontend: Read website_bucket_name, api_gateway_url; sed replace API_GATEWAY_URL_PLACEHOLDER in frontend/app.js; aws s3 sync frontend to bucket; restore app.js from .bak.
  8. display_completion_info: Print website URL, API URL, alert email, next steps (verify email, open site, create monitor), test endpoints, useful commands.
- **get_tf_output(key):** Reads ROOT_DIR/terraform-outputs.json; uses jq if available else python3 to output .key.value; fails if file missing.
- **Requirements:** AWS CLI, Terraform, Node.js/npm, zip; optional jq for robust output parsing.

## shutdown.sh

- **Purpose:** Destroy all AWS resources and clean local artifacts.
- **Flow:**
  1. Print banner; confirm with user (must type 'yes').
  2. empty_s3_buckets: Read bucket name from terraform output (or terraform-outputs.json if present); aws s3 rm s3://bucket --recursive if bucket exists.
  3. cd terraform; terraform destroy -auto-approve (or with input as per script); cd back.
  4. Remove .build/, terraform-outputs.json, terraform/.terraform*, terraform/tfplan, terraform/*.tfstate*.
  5. Print completion and how to redeploy.
- **Requirements:** AWS CLI, Terraform; must be run from project root (or script dir) so paths to terraform and outputs are correct.

## Common Conventions

- set -e so any command failure exits the script.
- ROOT_DIR in install.sh ensures terraform-outputs.json and frontend paths resolve regardless of cwd.
- Terraform outputs are the single source of truth for Lambda names, bucket name, API URL; scripts never hardcode resource names.
