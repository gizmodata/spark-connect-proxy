#!/bin/bash

################################################################################
# Script Name: provision_emr_spark_cluster.sh
# Description: This script uses the AWS Client to provision a Spark EMR cluster
#              in Amazon Web Services (AWS).  This script requires that you have
#              the AWS cli installed, and are authenticated with an AWS account
#              that has provisioning privileges.
#
#              You must have a .env file in the same directory as this script
#              which has these variables set (with "export " in front) to valid values:
#              AWS_ACCESS_KEY_ID
#              AWS_SECRET_ACCESS_KEY
#              AWS_SESSION_TOKEN
#              AWS_DEFAULT_REGION
#
# Usage:       ./provision_emr_spark_cluster.sh
#
# Author:      Voltron Data
# Date:        March 15, 2023
#
# Version:     1.0
################################################################################

set -e

SCRIPT_DIR=$(dirname ${0})
SCRIPT_OUTPUT_DIR="${SCRIPT_DIR}/output"

# Source the .env file for the AWS env vars needed for authentication
source ${SCRIPT_DIR}/.env

# Process args
INSTANCE_TYPE=${1:-"r5.8xlarge"}  # r5.8xlarge has 32 vCPUs and 256 GiB of memory
INSTANCE_COUNT=${2:-3}
START_SPARK_CONNECT_PROXY=${3:-"TRUE"}
EMR_VERSION=${4:-"emr-7.2.0"}
TAGS=${5:-"creation_method=script_${USER}_voltrondata_com environment=development team=field-eng owner=${USER}_voltrondata_com service=emr-benchmarking no_delete=true"}
RUN_BOOTSTRAP_ACTIONS=${6:-"FALSE"}
SPARK_CONNECT_PROXY_PORT=${7:-"50051"}

# Echo out script parameters
echo "Script: ${0} was called with the following arguments:"
echo "1) INSTANCE_TYPE: ${INSTANCE_TYPE}"
echo "2) INSTANCE_COUNT: ${INSTANCE_COUNT}"
echo "3) START_SPARK_CONNECT_PROXY: ${START_SPARK_CONNECT_PROXY}"
echo "4) EMR_VERSION: ${EMR_VERSION}"
echo "5) TAGS: ${TAGS}"
echo "6) RUN_BOOTSTRAP_ACTIONS: ${RUN_BOOTSTRAP_ACTIONS}"
echo "7) SPARK_CONNECT_PROXY_PORT: ${SPARK_CONNECT_PROXY_PORT}"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Using AWS Account ID: ${AWS_ACCOUNT_ID}"

AVAILABILITY_ZONE="${AWS_DEFAULT_REGION}a"
echo "Using Availability Zone: ${AVAILABILITY_ZONE}"

KEY_DIR="${SCRIPT_DIR}/.ssh"
mkdir -p ${KEY_DIR}

SSH_KEY="${KEY_DIR}/keypair.pem"

# Create an ssh keypair
rm -f ${SSH_KEY}
aws ec2 delete-key-pair --key-name sparkKey || echo "n/a"
aws ec2 create-key-pair --key-name sparkKey --query KeyMaterial --output text > ${SSH_KEY}
chmod u=r,g=,o= ${SSH_KEY}

# Create default roles if needed
aws emr create-default-roles --output text

# Get the default subnet for the availability zone
SUBNET_ID=$(aws ec2 describe-subnets | jq -r --arg az "$AVAILABILITY_ZONE" '.Subnets[] | select(.AvailabilityZone==$az and .DefaultForAz==true) | .SubnetId')

BOOTSTRAP_BUCKET_NAME="emr-bootstrap-bucket-${AWS_ACCOUNT_ID}"
echo "Using EMR Bootstrap bucket with name: ${BOOTSTRAP_BUCKET_NAME}"

LOG_BUCKET_NAME="emr-log-bucket-${AWS_ACCOUNT_ID}"
echo "Using EMR Log bucket with name: ${LOG_BUCKET_NAME}"

# Add a bootstrap script if desired
if [ "${RUN_BOOTSTRAP_ACTIONS}" != "FALSE" ]; then
  BOOTSTRAP_ARG="--bootstrap-actions Path=s3://${BOOTSTRAP_BUCKET_NAME}/emr_ibis_bootstrap.sh"
fi

# Create the cluster
CLUSTER_ID=$(aws emr create-cluster \
              --name "Sparky1" \
              --release-label ${EMR_VERSION} \
              --applications Name=Spark \
              --ec2-attributes KeyName=sparkKey,SubnetId="${SUBNET_ID}" \
              --instance-type ${INSTANCE_TYPE} \
              --instance-count ${INSTANCE_COUNT} \
              --use-default-roles \
              --log-uri s3://${LOG_BUCKET_NAME}/logs/ \
              --no-auto-terminate \
              --auto-termination-policy IdleTimeout=3600 --query ClusterId --output text \
              --tags ${TAGS} \
              ${BOOTSTRAP_ARG}
            )

echo "The EMR Cluster ID is: ${CLUSTER_ID}"

# Loop until the command returns a non-null value
while [[ $(aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query Cluster.MasterPublicDnsName --output text) == "None" ]]; do
  echo "Waiting for EMR cluster to start..."
  sleep 10
done

# Set the environment variable to the returned value
export MASTER_DNS=$(aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query Cluster.MasterPublicDnsName --output text)
echo "The EMR Cluster Public DNS Name is: ${MASTER_DNS}"

EMR_SECURITY_GROUP=$(aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query Cluster.Ec2InstanceAttributes.EmrManagedMasterSecurityGroup --output text)
echo "The EMR Security Group is: ${EMR_SECURITY_GROUP}"

# Allow ssh traffic to the EMR cluster
aws ec2 authorize-security-group-ingress \
--output text \
--group-id ${EMR_SECURITY_GROUP} \
--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]' || echo "SSH Ingress already setup"

# Allow secured Spark Connect Proxy traffic
aws ec2 authorize-security-group-ingress \
--output text \
--group-id ${EMR_SECURITY_GROUP} \
--ip-permissions "[{\"IpProtocol\": \"tcp\", \"FromPort\": ${SPARK_CONNECT_PROXY_PORT}, \"ToPort\": ${SPARK_CONNECT_PROXY_PORT}, \"IpRanges\": [{\"CidrIp\": \"0.0.0.0/0\", \"Description\": \"Spark Connect\"}]}]" || echo \"Spark Connect Ingress already setup\"

# Loop until the cluster is ready and completed all bootstrap actions
while true; do
    # Get the status of the cluster
    status=$(aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query Cluster.Status.State --output text)
    echo "Cluster status: $status"

    # If the cluster and bootstrap actions are both done, break out of the loop
    if [ "$status" == "WAITING" ]; then
        break
    fi

    # If the cluster has terminated with errors, exit with failure
    if [ "$status" == "TERMINATED_WITH_ERRORS" ]; then
        error_message=$(aws emr describe-cluster --cluster-id ${CLUSTER_ID} --query Cluster.Status.StateChangeReason.Message --output text)
        echo "The Cluster has terminated with error: '${error_message}' - exiting script..."
        exit 1
    fi

    # Wait 30 seconds before checking again
    sleep 30
done

# Start the Spark Connect Proxy server if desired
if [ "${START_SPARK_CONNECT_PROXY}" == "TRUE" ]; then
  echo "Starting the Spark Connect Proxy server..."
  SPARK_CONNECT_PROXY_OUTPUT_FILE="${SCRIPT_OUTPUT_DIR}/spark_connect_proxy_details.log"
  ${SCRIPT_DIR}/emr_start_spark_connect_proxy.sh ${MASTER_DNS} ${SSH_KEY} ${SPARK_CONNECT_PROXY_PORT} | tee ${SPARK_CONNECT_PROXY_OUTPUT_FILE}
  echo -e "Details of the Spark Connect Proxy server are in the file: ${SPARK_CONNECT_PROXY_OUTPUT_FILE}"
fi

echo "Cluster is ready!"

INSTANCE_DETAILS_OUTPUT_FILE="${SCRIPT_OUTPUT_DIR}/instance_details.txt"
echo -e "Use this SSH command to connect to the EMR cluster: \nssh -i ${SSH_KEY} hadoop@${MASTER_DNS}" | tee ${INSTANCE_DETAILS_OUTPUT_FILE}
echo -e "Details of the EMR cluster are in the file: ${INSTANCE_DETAILS_OUTPUT_FILE}"

exit 0
