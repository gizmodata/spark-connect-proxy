#!/bin/bash

set -e

SCRIPT_DIR=$(dirname ${0})
# Source the .env file for the AWS env vars needed for authentication
source ${SCRIPT_DIR}/.env

# Get the AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Using AWS Account ID: ${AWS_ACCOUNT_ID}"

LOG_BUCKET_NAME="emr-log-bucket-${AWS_ACCOUNT_ID}"
echo "Creating EMR Log bucket with name: ${LOG_BUCKET_NAME}"

aws s3api create-bucket --bucket ${LOG_BUCKET_NAME}
