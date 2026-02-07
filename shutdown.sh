#!/bin/bash

###############################################################################
# API Health Monitoring System - Shutdown Script
# 
# This script destroys all AWS resources and cleans up local files:
# 1. Empties S3 buckets (required before Terraform can delete them)
# 2. Runs Terraform destroy
# 3. Cleans up local build artifacts
# 4. Removes Terraform state files
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Print banner
print_banner() {
    echo ""
    echo "============================================================="
    echo "  API Health Monitoring System - Shutdown & Cleanup"
    echo "============================================================="
    echo ""
}

# Confirmation prompt
confirm_destruction() {
    log_warning "This will destroy ALL AWS resources and delete ALL data!"
    echo ""
    echo "Resources that will be deleted:"
    echo "  - All Lambda functions"
    echo "  - DynamoDB tables (including all monitor configs and metrics)"
    echo "  - SQS queues"
    echo "  - S3 buckets and website files"
    echo "  - API Gateway"
    echo "  - EventBridge rules"
    echo "  - SNS topics and SES configuration"
    echo "  - CloudWatch logs and alarms"
    echo "  - IAM roles and policies"
    echo ""
    log_warning "This action is IRREVERSIBLE!"
    echo ""
    
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log_info "Shutdown cancelled."
        exit 0
    fi
    
    echo ""
}

# Empty S3 buckets
empty_s3_buckets() {
    log_info "Emptying S3 buckets..."
    
    # Check if Terraform outputs exist
    if [ ! -f "terraform-outputs.json" ]; then
        log_warning "terraform-outputs.json not found. Skipping S3 cleanup."
        echo ""
        return
    fi
    
    # Get bucket name
    BUCKET_NAME=$(cat terraform-outputs.json | grep -o '"website_bucket_name"[^}]*' | grep -o '"value": "[^"]*' | cut -d'"' -f4)
    
    if [ -z "$BUCKET_NAME" ]; then
        log_warning "Could not find S3 bucket name. Skipping S3 cleanup."
        echo ""
        return
    fi
    
    # Get AWS region
    AWS_REGION=$(cat terraform/terraform.tfvars | grep aws_region | cut -d'"' -f2 || echo "us-east-1")
    
    # Check if bucket exists
    if aws s3 ls "s3://$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
        log_info "Emptying bucket: $BUCKET_NAME"
        aws s3 rm "s3://$BUCKET_NAME" --recursive --region "$AWS_REGION"
        log_success "S3 bucket emptied"
    else
        log_info "Bucket $BUCKET_NAME does not exist or already emptied"
    fi
    
    echo ""
}

# Destroy infrastructure
destroy_infrastructure() {
    log_info "Destroying AWS infrastructure with Terraform..."
    echo ""
    
    cd terraform
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        log_warning "Terraform not initialized. Running terraform init..."
        terraform init
    fi
    
    # Destroy infrastructure
    log_info "Running terraform destroy..."
    terraform destroy -auto-approve
    
    log_success "Infrastructure destroyed successfully!"
    
    cd ..
    echo ""
}

# Clean up local files
cleanup_local_files() {
    log_info "Cleaning up local files..."
    
    # Remove build artifacts
    if [ -d ".build" ]; then
        rm -rf .build
        log_success "Removed .build directory"
    fi
    
    # Remove Terraform outputs
    if [ -f "terraform-outputs.json" ]; then
        rm -f terraform-outputs.json
        log_success "Removed terraform-outputs.json"
    fi
    
    # Remove Terraform state files (optional)
    read -p "Do you want to remove Terraform state files? (y/n): " remove_state
    if [[ $remove_state == "y" || $remove_state == "Y" ]]; then
        cd terraform
        if [ -f "terraform.tfstate" ]; then
            rm -f terraform.tfstate terraform.tfstate.backup
            log_success "Removed Terraform state files"
        fi
        if [ -f "tfplan" ]; then
            rm -f tfplan
            log_success "Removed Terraform plan file"
        fi
        if [ -d ".terraform" ]; then
            rm -rf .terraform
            log_success "Removed .terraform directory"
        fi
        if [ -f ".terraform.lock.hcl" ]; then
            rm -f .terraform.lock.hcl
            log_success "Removed Terraform lock file"
        fi
        cd ..
    fi
    
    echo ""
}

# Display completion info
display_completion_info() {
    echo ""
    echo "============================================================="
    echo "  ✅ Shutdown Complete!"
    echo "============================================================="
    echo ""
    echo "All AWS resources have been destroyed."
    echo ""
    echo "To redeploy the system, run:"
    echo "  ./install.sh"
    echo ""
    echo "============================================================="
    echo ""
}

# Main shutdown flow
main() {
    print_banner
    
    # Step 1: Confirm destruction
    confirm_destruction
    
    # Step 2: Empty S3 buckets
    empty_s3_buckets
    
    # Step 3: Destroy infrastructure
    destroy_infrastructure
    
    # Step 4: Clean up local files
    cleanup_local_files
    
    # Step 5: Display completion info
    display_completion_info
    
    log_success "Shutdown complete! 🧹"
}

# Run main function
main
