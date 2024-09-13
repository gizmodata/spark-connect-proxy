# SPDX-License-Identifier: Apache-2.0
"""Configuration settings for the gateway."""

from pathlib import Path

# Constants
TLS_DIR = Path("tls")
DEFAULT_CERT_FILE = (TLS_DIR / "server.crt").as_posix()
DEFAULT_KEY_FILE = (TLS_DIR / "server.key").as_posix()
SPARK_CONNECT_SERVER_DEFAULT_URL = "[::]:15002"  # localhost:15002
SERVER_PORT = 50051
DEFAULT_JWT_AUDIENCE = "spark-client"
DEFAULT_JWT_ISSUER = "spark-connect-proxy"
DEFAULT_JWT_SUBJECT = "spark-client"
DEFAULT_JWT_LIFETIME: int = 3600 * 24  # 1 day
