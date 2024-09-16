#!/bin/bash

set -e

SCRIPT_DIR=$(dirname ${0})
# Source the .env file for the AWS env vars needed for authentication
source ${SCRIPT_DIR}/.env

# Get the AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Using AWS Account ID: ${AWS_ACCOUNT_ID}"

BOOTSTRAP_BUCKET_NAME="emr-bootstrap-bucket-${AWS_ACCOUNT_ID}"
echo "Creating EMR Bootstrap bucket with name: ${BOOTSTRAP_BUCKET_NAME}"

# Create the bootstrap script bucket for use with EMR
aws s3api create-bucket --bucket ${BOOTSTRAP_BUCKET_NAME}

# Upload our bootstrap shell script
chmod u=rwx,g=rx,o=rx ./emr_ibis_bootstrap.sh
aws s3 cp emr_ibis_bootstrap.sh s3://${BOOTSTRAP_BUCKET_NAME}/

echo "All done."

exit 0
