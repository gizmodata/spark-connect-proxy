# spark-connect-proxy
A reverse proxy server which allows secure connectivity to a Spark Connect server

[<img src="https://img.shields.io/badge/GitHub-prmoore77%2Fspark--connect--proxy-blue.svg?logo=Github">](https://github.com/prmoore77/spark-connect-proxy)
[![spark-connect-proxy-ci](https://github.com/prmoore77/spark-connect-proxy/actions/workflows/ci.yml/badge.svg)](https://github.com/prmoore77/spark-connect-proxy/actions/workflows/ci.yml)
[![Supported Python Versions](https://img.shields.io/pypi/pyversions/spark-connect-proxy)](https://pypi.org/project/spark-connect-proxy/)
[![PyPI version](https://badge.fury.io/py/spark-connect-proxy.svg)](https://badge.fury.io/py/spark-connect-proxy)
[![PyPI Downloads](https://img.shields.io/pypi/dm/spark-connect-proxy.svg)](https://pypi.org/project/spark-connect-proxy/)

# Setup (to run locally)

## Install Python package
You can install `spark-connect-proxy` from PyPi or from source.

### Option 1 - from PyPi
```shell
# Create the virtual environment
python3 -m venv .venv

# Activate the virtual environment
. .venv/bin/activate

pip install spark-connect-proxy
```

### Option 2 - from source - for development
```shell
git clone https://github.com/prmoore77/spark-connect-proxy

cd spark-connect-proxy

# Create the virtual environment
python3 -m venv .venv

# Activate the virtual environment
. .venv/bin/activate

# Upgrade pip, setuptools, and wheel
pip install --upgrade pip setuptools wheel

# Install Spark Connect Proxy - in editable mode with client and dev dependencies
pip install --editable .[client,dev]
```

### Note
For the following commands - if you running from source and using `--editable` mode (for development purposes) - you will need to set the PYTHONPATH environment variable as follows:
```shell
export PYTHONPATH=$(pwd)/src
```

### Usage
This repo contains scripts to let you provision an AWS EMR Spark cluster with a secure Spark Connect Proxy server to allow you to securely and remotely connect to it.

The scripts the AWS CLI to provision the EMR Spark cluster - so you will need to have the [AWS CLI installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and configured with your AWS credentials.

You can create a file in your local copy of the `scripts` directory called `.env` with the following contents:
```shell
export AWS_ACCESS_KEY_ID="put value from AWS here"
export AWS_SECRET_ACCESS_KEY="put value from AWS here"
export AWS_SESSION_TOKEN="put value from AWS here"
export AWS_REGION="us-east-2"
```

To provision the EMR Spark cluster - run the following command from the root directory of this repo:
```shell
scripts/provision_emr_spark_cluster.sh
```

That will output several files:
- file: `tls/ca.crt` - the EMR Spark cluster generated TLS certificate - needed for your PySpark client to trust the Spark Connect Proxy server (b/c it is self-signed)
- file: `scripts/output/instance_details.txt` - shows the ssh command for connecting to the master node of the EMR Spark cluster
- file: `scripts/output/spark_connect_proxy_details.log` - shows how to run a PySpark Ibis client example - which connects securely from your local computer to the remote EMR Spark cluster.  Example command:
```shell
spark-connect-proxy-ibis-client-example \
  --host ec2-01-01-01-01.us-east-2.compute.amazonaws.com \
  --port 50051 \
  --use-tls \
  --tls-roots tls/ca.crt \
  --token honey.badger.dontcare
```

### Handy development commands

#### Version management

##### Bump the version of the application - (you must have installed from source with the [dev] extras)
```bash
bumpver update --patch
```
