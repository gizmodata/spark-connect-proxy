#!/bin/bash

################################################################################
# Script Name: emr_ibis_bootstrap.sh
# Description: This script installs the necessary components to run the
#              ibis-framework on an AWS EMR (Spark) cluster.
#              It installs Python 3.10 from source with OpenSSL.
#              This is because the latest EMR version (as of March 15, 2023) -
#              6.10.0 comes with Python 3.7 and doesn't work with the latest
#              ibis-framework version (which requires Python 3.8 or above).
#
# Usage:       ./emr_ibis_bootstrap.sh
#
# Author:      Voltron Data
# Date:        March 15, 2023
#
# Version:     1.0
################################################################################

set -e

OPENSSL_VERSION="3.1.0"
PYTHON_VERSION="3.10.10"

# Install dependencies
sudo yum update -y
sudo yum groupinstall "Development Tools" -y
sudo yum install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel libffi-devel perl-IPC-Cmd -y

pushd /tmp

# Install OpenSSL from source
curl -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar xzf openssl-${OPENSSL_VERSION}.tar.gz
pushd openssl-${OPENSSL_VERSION}
./config \
  --prefix=/usr/local/custom-openssl \
  --libdir=lib \
  --openssldir=/etc/pki/tls
make -j1 depend
make -j8
sudo make install_sw
popd

# Get Python source code
curl -O https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
tar -xvzf Python-${PYTHON_VERSION}.tgz

pushd Python-${PYTHON_VERSION}

# Configure, build, and install
./configure \
    --prefix=/usr \
    --enable-optimizations \
    --with-openssl=/usr/local/custom-openssl \
    --with-openssl-rpath=auto

make -j8
sudo make install

popd
popd

# Install ibis PySpark requirements
pip3 install --upgrade pip setuptools
pip3 install ibis-framework[pyspark] sqlalchemy==1.4.*

echo "All steps completed successfully."

exit 0
