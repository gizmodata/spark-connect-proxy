#!/bin/bash

################################################################################
# Script Name: emr_start_spark_connect_proxy.sh
# Description: This script installs the necessary components to run the
#              a secure Spark Connect proxy server.
#
# Usage:       ./emr_start_spark_connect_proxy.sh <<EMR_MASTER_DNS>> [IDENTITY_FILE] <<SPARK_CONNECT_PROXY_PORT>>
#
# Author:      Voltron Data
# Date:        September 13, 2024 Anno Domini
#
# Version:     1.0
################################################################################

set -e

SCRIPT_DIR=$(dirname ${0})
TLS_DIR=${SCRIPT_DIR}/../tls

EMR_MASTER_DNS="${1:?Please provide the EMR Master DNS as the first argument.}"
IDENTITY_FILE="${2:?Please provide the Identity File as the second argument.}"
SPARK_CONNECT_PROXY_PORT="${3:?Please provide the Spark Connect Proxy Port as the third argument.}"

echo "Script: ${0} was called with the following arguments:"
echo "1) EMR_MASTER_DNS: ${EMR_MASTER_DNS}"
echo "2) IDENTITY_FILE: ${IDENTITY_FILE}"
echo "3) SPARK_CONNECT_PROXY_PORT: ${SPARK_CONNECT_PROXY_PORT}"

ssh-keyscan -H ${EMR_MASTER_DNS} >> ~/.ssh/known_hosts

REMOTE_SCRIPT="emr_start_spark_connect_proxy_remote.sh"

scp -i ${IDENTITY_FILE} ${SCRIPT_DIR}/${REMOTE_SCRIPT} hadoop@${EMR_MASTER_DNS}:/home/hadoop/

ssh -i ${IDENTITY_FILE} hadoop@${EMR_MASTER_DNS} "bash /home/hadoop/${REMOTE_SCRIPT} ${EMR_MASTER_DNS} ${SPARK_CONNECT_PROXY_PORT}"

# Copy the server.crt file to the local machine so it can be used with the --tls-roots arg for the client
scp -i ${IDENTITY_FILE} hadoop@${EMR_MASTER_DNS}:/home/hadoop/tls/server.crt ${TLS_DIR}/ca.crt

exit 0
