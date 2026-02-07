#!/bin/bash

###############################################################################
# API Health Monitoring System - Installation Script
# 
# This script automates the complete deployment of the monitoring system:
# 1. Validates prerequisites (AWS CLI, Terraform, Node.js)
# 2. Deploys AWS infrastructure via Terraform
# 3. Packages and deploys Lambda functions
# 4. Deploys frontend to S3
# 5. Configures SES email verification
# 6. Displays access information
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
    echo "  API Health Monitoring System - Automated Installation"
    echo "============================================================="
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=0
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Install from: https://aws.amazon.com/cli/"
        missing_deps=1
    else
        log_success "AWS CLI found: $(aws --version)"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run: aws configure"
        missing_deps=1
    else
        log_success "AWS credentials configured"
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        AWS_REGION=$(aws configure get region || echo "us-east-1")
        log_info "Account ID: $AWS_ACCOUNT_ID"
        log_info "Region: $AWS_REGION"
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Install from: https://www.terraform.io/downloads"
        missing_deps=1
    else
        log_success "Terraform found: $(terraform version | head -n1)"
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Install from: https://nodejs.org/"
        missing_deps=1
    else
        log_success "Node.js found: $(node --version)"
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        log_error "npm not found. Install Node.js from: https://nodejs.org/"
        missing_deps=1
    else
        log_success "npm found: $(npm --version)"
    fi
    
    # Check zip
    if ! command -v zip &> /dev/null; then
        log_error "zip not found. Install via: apt-get install zip (Ubuntu) or brew install zip (Mac)"
        missing_deps=1
    fi
    
    if [ $missing_deps -eq 1 ]; then
        log_error "Missing required dependencies. Please install them and try again."
        exit 1
    fi
    
    log_success "All prerequisites met!"
    echo ""
}

# Prompt for configuration
prompt_configuration() {
    log_info "Configuration Setup"
    echo ""
    
    # Check if terraform.tfvars already exists
    if [ -f "terraform/terraform.tfvars" ]; then
        log_warning "Configuration file already exists: terraform/terraform.tfvars"
        read -p "Do you want to use existing configuration? (y/n): " use_existing
        if [[ $use_existing == "y" || $use_existing == "Y" ]]; then
            log_info "Using existing configuration"
            return
        fi
    fi
    
    # Get alert email
    read -p "Enter your email address for alerts: " ALERT_EMAIL
    while [[ ! "$ALERT_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$ ]]; do
        log_error "Invalid email format"
        read -p "Enter your email address for alerts: " ALERT_EMAIL
    done
    
    # Get AWS region (with default)
    read -p "Enter AWS region [us-east-1]: " INPUT_REGION
    AWS_REGION=${INPUT_REGION:-us-east-1}
    
    # Create terraform.tfvars
    cat > terraform/terraform.tfvars <<EOF
# AWS Configuration
aws_region = "$AWS_REGION"

# Project Configuration
project_name = "api-health-monitor"

# Alert Configuration
alert_email = "$ALERT_EMAIL"

# Health Check Configuration
check_interval_minutes = 1
lambda_timeout = 30
sqs_visibility_timeout = 30
EOF
    
    log_success "Configuration saved to terraform/terraform.tfvars"
    echo ""
}

# Deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying AWS infrastructure with Terraform..."
    echo ""
    
    cd terraform
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    log_info "Creating deployment plan..."
    terraform plan -out=tfplan
    
    # Apply deployment
    log_info "Applying infrastructure changes..."
    log_warning "This will create AWS resources and may incur charges."
    
    terraform apply tfplan
    
    log_success "Infrastructure deployed successfully!"
    
    # Save outputs to file for later use
    terraform output -json > ../terraform-outputs.json
    
    cd ..
    echo ""
}

# Package Lambda functions
package_lambdas() {
    log_info "Packaging Lambda functions..."
    echo ""
    
    # Create deployment directory
    mkdir -p .build
    
    # Package API Handler
    log_info "Packaging API Handler Lambda..."
    cd lambdas/api-handler
    npm install --production
    zip -q -r ../../.build/api-handler.zip .
    cd ../..
    log_success "API Handler packaged"
    
    # Package Orchestrator
    log_info "Packaging Orchestrator Lambda..."
    cd lambdas/orchestrator
    npm install --production
    zip -q -r ../../.build/orchestrator.zip .
    cd ../..
    log_success "Orchestrator packaged"
    
    # Package Worker
    log_info "Packaging Worker Lambda..."
    cd lambdas/worker
    npm install --production
    zip -q -r ../../.build/worker.zip .
    cd ../..
    log_success "Worker packaged"
    
    echo ""
}

# Deploy Lambda functions
deploy_lambdas() {
    log_info "Deploying Lambda functions..."
    echo ""
    
    # Get function names from Terraform outputs
    API_HANDLER_NAME=$(cat terraform-outputs.json | grep -o '"api_handler_function_name"[^}]*' | grep -o '"value": "[^"]*' | cut -d'"' -f4)
    ORCHESTRATOR_NAME=$(cat terraform-outputs.json | grep -o '"orchestrator_function_name"[^}]*' | grep -o '"value": "[^"]*' | cut -d'"' -f4)
    WORKER_NAME=$(cat terraform-outputs.json | grep -o '"worker_function_name"[^}]*' | grep -o '"value": "[^"]*' | cut -d'"' -f4)
    
    # Deploy API Handler
    log_info "Deploying API Handler..."
    aws lambda update-function-code \
        --function-name "$API_HANDLER_NAME" \
        --zip-file fileb://.build/api-handler.zip \
        --region "$AWS_REGION" > /dev/null
    log_success "API Handler deployed"
    
    # Deploy Orchestrator
    log_info "Deploying Orchestrator..."
    aws lambda update-function-code \
        --function-name "$ORCHESTRATOR_NAME" \
        --zip-file fileb://.build/orchestrator.zip \
        --region "$AWS_REGION" > /dev/null
    log_success "Orchestrator deployed"
    
    # Deploy Worker
    log_info "Deploying Worker..."
    aws lambda update-function-code \
        --function-name "$WORKER_NAME" \
        --zip-file fileb://.build/worker.zip \
        --region "$AWS_REGION" > /dev/null
    log_success "Worker deployed"
    
    echo ""
}

# Deploy frontend
deploy_frontend() {
    log_info "Deploying frontend to S3..."
    echo ""
    
    # Get S3 bucket name and API URL from Terraform outputs
    BUCKET_NAME=$(cat terraform-outputs.json | grep -o '"website_bucket_name"[^}]*' | grep -o '"value": "[^"]*' | cut -d'"' -f4)
    API_URL=$(cat terraform-outputs.json | grep -o '"api_gateway_url"[^}]*' | grep -o '"value": "[^"]*' | cut -d'"' -f4)
    
    # Update frontend with API URL
    log_info "Configuring frontend with API URL..."
    sed -i.bak "s|API_GATEWAY_URL_PLACEHOLDER|$API_URL|g" frontend/app.js
    
    # Sync to S3
    log_info "Uploading files to S3..."
    aws s3 sync frontend/ s3://$BUCKET_NAME/ \
        --exclude "*.bak" \
        --region "$AWS_REGION"
    
    # Restore original file
    mv frontend/app.js.bak frontend/app.js
    
    log_success "Frontend deployed to S3"
    echo ""
}

# Display completion info
display_completion_info() {
    echo ""
    echo "============================================================="
    echo "  ✅ Deployment Complete!"
    echo "============================================================="
    echo ""
    
    # Extract outputs
    WEBSITE_URL=$(cat terraform-outputs.json | grep -o '"website_url"[^}]*' | grep -o '"value": "[^"]*' | cut -d'"' -f4)
    API_URL=$(cat terraform-outputs.json | grep -o '"api_gateway_url"[^}]*' | grep -o '"value": "[^"]*' | cut -d'"' -f4)
    ALERT_EMAIL=$(cat terraform/terraform.tfvars | grep alert_email | cut -d'"' -f2)
    
    echo -e "${GREEN}📱 Website URL:${NC}"
    echo "   $WEBSITE_URL"
    echo ""
    echo -e "${GREEN}🔗 API Endpoint:${NC}"
    echo "   $API_URL"
    echo ""
    echo -e "${YELLOW}📧 Email Verification Required:${NC}"
    echo "   Check your inbox at: $ALERT_EMAIL"
    echo "   Click the verification link from AWS SES"
    echo "   (Check spam folder if not received within 5 minutes)"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "   1. Verify your email address (check inbox/spam)"
    echo "   2. Open the website URL in your browser"
    echo "   3. Create your first monitor"
    echo "   4. Wait 1-2 minutes for the first health check"
    echo "   5. Check your email for alerts"
    echo ""
    echo -e "${BLUE}Test Endpoints:${NC}"
    echo "   ✅ Always UP:    https://httpstat.us/200"
    echo "   ❌ Always DOWN:  https://httpstat.us/500"
    echo "   ⏱️  Slow (2s):    https://httpstat.us/200?sleep=2000"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "   View logs:       aws logs tail /aws/lambda/api-health-monitor-worker --follow"
    echo "   List monitors:   aws dynamodb scan --table-name MonitorConfigs"
    echo "   Cleanup:         ./shutdown.sh"
    echo ""
    echo "============================================================="
    echo ""
}

# Main installation flow
main() {
    print_banner
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Get configuration
    prompt_configuration
    
    # Step 3: Package Lambda functions
    package_lambdas
    
    # Step 4: Deploy infrastructure
    deploy_infrastructure
    
    # Step 5: Deploy Lambda code
    deploy_lambdas
    
    # Step 6: Deploy frontend
    deploy_frontend
    
    # Step 7: Display completion info
    display_completion_info
    
    log_success "Installation complete! 🎉"
}

# Run main function
main
