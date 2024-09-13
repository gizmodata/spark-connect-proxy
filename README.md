# spark-connect-proxy
A reverse proxy server which allows secure connectivity to a Spark Connect server

[<img src="https://img.shields.io/badge/GitHub-prmoore77%2Fspark--connect--proxy-blue.svg?logo=Github">](https://github.com/prmoore77/spark-connect-proxy)
[![spark-connect-proxy-ci](https://github.com/prmoore77/spark-connect-proxy/actions/workflows/ci.yml/badge.svg)](https://github.com/prmoore77/spark-connect-proxy/actions/workflows/ci.yml)
[![Supported Python Versions](https://img.shields.io/pypi/pyversions/spark-connect-proxy)](https://pypi.org/project/spark-connect-proxy/)
[![PyPI version](https://badge.fury.io/py/spark-connect-proxy.svg)](https://badge.fury.io/py/spark-connect-proxy)
[![PyPI Downloads](https://img.shields.io/pypi/dm/spark-connect-proxy.svg)](https://pypi.org/project/spark-connect-proxy/)

# Setup (to run locally)

## Install package
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
TODO

### Handy development commands

#### Version management

##### Bump the version of the application - (you must have installed from source with the [dev] extras)
```bash
bumpver update --patch
```
