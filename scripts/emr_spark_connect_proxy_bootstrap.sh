#!/bin/bash

################################################################################
# Script Name: emr_spark_connect_proxy_bootstrap.sh
# Description: This script installs the necessary components to run the
#              a secure Spark Connect proxy server.
#
# Usage:       ./emr_spark_connect_proxy_bootstrap.sh
#
# Author:      Voltron Data
# Date:        September 13, 2024 Anno Domini
#
# Version:     1.0
################################################################################

set -e


# Get the Spark version
SPARK_VERSION=$(spark-submit --version 2>&1 | grep -oP '(?<=version )\d+\.\d+\.\d+(?=-amzn)')
echo -e "Using Spark version: ${SPARK_VERSION}"

# Get the Scala version
SCALA_VERSION=$(spark-submit --version 2>&1 | grep -oP '(?<=Scala version )\d+\.\d+\.\d+' | cut -d'.' -f1,2)
echo -e "Using Scala version: ${SCALA_VERSION}"

# Start the Spark Connect server - which listens locally on port: 15002
# Spark Connect does not have a secure mode, so we need to use a proxy server.
# - DO NOT EXPOSE PORT 15002 TO THE INTERNET!!!
sudo chmod -R u=rwx,g=rwx,o=rwx /var/log/spark
export SPARK_HOME=/usr/lib/spark
$SPARK_HOME/sbin/start-connect-server.sh --packages org.apache.spark:spark-connect_${SCALA_VERSION}:${SPARK_VERSION}

# Install the Spark Connect Proxy server Python package
pip3 install --upgrade pip setuptools
pip3 install spark-connect-proxy

# Create a TLS key pair
mkdir tls
spark-connect-proxy-create-tls-keypair \
  --cert-file tls/server.crt \
  --key-file tls/server.key

# Create a random secret key
SECRET_KEY=$(openssl rand -base64 32)

# Start the Spark Connect Proxy server - listen on port: 50051
# It is safe to expose this port to the internet
# because it uses TLS and JWT authentication.
spark-connect-proxy \
   --spark-connect-server-url "localhost:15002" \
   --port 50051 \
   --tls tls/server.crt tls/server.key \
   --enable-auth \
   --jwt-audience "spark-connect-proxy" \
   --secret-key "${SECRET_KEY}" \
   --log-level INFO

# Generate a JWT token for authentication with the Spark Connect Proxy server
spark-connect-proxy-create-jwt \
   --secret-key ${SECRET_KEY}

echo "All steps completed successfully."

exit 0