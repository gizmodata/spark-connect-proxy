#!/bin/bash

################################################################################
# Script Name: emr_start_spark_connect_proxy.sh
# Description: This script installs the necessary components to run the
#              a secure Spark Connect proxy server.
#
# Usage:       ./emr_start_spark_connect_proxy_remote.sh <<EMR_MASTER_DNS>>
#
# Author:      Gizmo Data LLC
# Date:        September 13, 2024 Anno Domini
#
# Version:     1.0
################################################################################

set -e

EMR_MASTER_DNS="${1:?Please provide the EMR Master DNS as the first argument.}"
SPARK_CONNECT_PROXY_PORT="${2:?Please provide the Spark Connect Proxy Port as the second argument.}"

echo "Script: ${0} was called with the following arguments:"
echo "1) EMR_MASTER_DNS: ${EMR_MASTER_DNS}"
echo "2) SPARK_CONNECT_PROXY_PORT: ${SPARK_CONNECT_PROXY_PORT}"

# Get the Spark version
SPARK_VERSION=$(spark-submit --version 2>&1 | grep -oP '(?<=version )\d+\.\d+\.\d+(?=-amzn)')
echo -e "Using Spark version: ${SPARK_VERSION}"

# Get the Scala version
SCALA_VERSION=$(spark-submit --version 2>&1 | grep -oP '(?<=Scala version )\d+\.\d+\.\d+' | cut -d'.' -f1,2)
echo -e "Using Scala version: ${SCALA_VERSION}"

# Start the Spark Connect server - which listens locally on port: 15002
# Spark Connect does not have a secure mode, so we need to use a proxy server.
# - DO NOT EXPOSE PORT 15002 TO THE INTERNET!!!
SPARK_LOG_DIR="/var/log/spark"
sudo setfacl -R -m g:hadoop:rwx ${SPARK_LOG_DIR}
export SPARK_HOME=/usr/lib/spark
$SPARK_HOME/sbin/start-connect-server.sh --packages org.apache.spark:spark-connect_${SCALA_VERSION}:${SPARK_VERSION}

# Install the Spark Connect Proxy server Python package
pip install --upgrade pip setuptools
pip install spark-connect-proxy

# Set up the path
export PATH=${PATH}:/home/hadoop/.local/bin

# Create a TLS key pair
mkdir -p tls
spark-connect-proxy-create-tls-keypair \
  --cert-file tls/server.crt \
  --key-file tls/server.key \
  --overwrite \
  --common-name "${EMR_MASTER_DNS}"

# Create a random secret key
SECRET_KEY=$(openssl rand -base64 32)

# Generate a JWT token for authentication with the Spark Connect Proxy server
JWT_TOKEN=$(spark-connect-proxy-create-jwt --secret-key ${SECRET_KEY} | sed -n '2p')

# Start the Spark Connect Proxy server - listen on port: 50051
# It is safe to expose this port to the internet
# because it uses TLS and JWT authentication.
nohup spark-connect-proxy-server \
       --spark-connect-server-url "localhost:15002" \
       --port ${SPARK_CONNECT_PROXY_PORT} \
       --tls tls/server.crt tls/server.key \
       --enable-auth \
       --jwt-audience "spark-client" \
       --secret-key "${SECRET_KEY}" \
       --log-level INFO > ${SPARK_LOG_DIR}/spark-connect-proxy.log 2>&1 &

cat << EOF
# Example Ibis client usage (run in bash):
spark-connect-proxy-ibis-client-example --host ${EMR_MASTER_DNS} --port ${SPARK_CONNECT_PROXY_PORT} --use-tls --tls-roots tls/ca.crt --token ${JWT_TOKEN}

EOF

cat << EOF
# Example Python Spark Connect client usage (run in python):
import os
import ibis
from pyspark.sql import SparkSession
from ibis import _


# Set the GRPC environment variable to use the CA cert
os.environ["GRPC_DEFAULT_SSL_ROOTS_FILE_PATH"] = "tls/ca.crt"

# Get our spark remote session
spark = (SparkSession
         .builder
         .appName("Spark Connect Proxy Example")
         .remote(url="sc://${EMR_MASTER_DNS}:${SPARK_CONNECT_PROXY_PORT}/;use_ssl=true;token=${JWT_TOKEN}")
         .getOrCreate()
         )

# Read a parquet file from S3
df = spark.read.parquet("s3://gbif-open-data-us-east-1/occurrence/2023-04-01/occurrence.parquet/000000")
df.show(n=10)

# Connect the Ibis PySpark back-end to the Spark Session (optional)
con = ibis.pyspark.connect(spark)

# Read the parquet data into an ibis table
t = con.read_parquet(path="s3://gbif-open-data-us-east-1/occurrence/2023-04-01/occurrence.parquet/000000",
                     table_name="t"
                     )

f = (
    t.select([_.gbifid,
             _.family,
             _.species
    ])
    .filter(_.family.isin(["Corvidae"]))
    # Here we limit by 10,000 to fetch a quick batch of results
    .limit(10000)
    .group_by(_.species)
    .count()
    )

f.execute()

EOF

exit 0
