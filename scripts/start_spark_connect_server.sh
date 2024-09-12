#!/bin/bash

# Run this on the Spark cluster to start the Spark Connect server
sudo chmod -R u=rwx,g=rwx,o=rwx /var/log/spark
export SPARK_HOME=/usr/lib/spark
$SPARK_HOME/sbin/start-connect-server.sh --packages org.apache.spark:spark-connect_2.12:3.5.1
