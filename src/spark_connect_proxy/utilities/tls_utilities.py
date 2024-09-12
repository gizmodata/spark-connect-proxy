# SPDX-License-Identifier: Apache-2.0
"""Utilities for generating self-signed TLS certificates using pyOpenSSL."""

import logging
import socket
from datetime import datetime, timedelta
from pathlib import Path
import os

import click
from OpenSSL import crypto

from ..config import DEFAULT_CERT_FILE, DEFAULT_KEY_FILE

_LOGGER = logging.getLogger(__name__)


def _gen_pyopenssl() -> tuple[bytes, bytes]:
    """Generate a self-signed certificate using pyOpenSSL."""

    # Generate RSA private key
    private_key = crypto.PKey()
    private_key.generate_key(crypto.TYPE_RSA, 2048)

    # Generate X.509 certificate
    cert = crypto.X509()

    # Set certificate subject and issuer to be the same (self-signed)
    cert.get_subject().CN = socket.gethostname()
    cert.set_issuer(cert.get_subject())

    # Set public key
    cert.set_pubkey(private_key)

    # Set certificate serial number
    cert.set_serial_number(int.from_bytes(os.urandom(8), "big"))

    # Set validity period (valid from now to 5 years in the future)
    cert.gmtime_adj_notBefore(0)
    cert.gmtime_adj_notAfter(5 * 365 * 24 * 60 * 60)  # 5 years

    # Add subject alternative names
    san_list = [
        f"DNS:{socket.gethostname()}",
        f"DNS:*.{socket.gethostname()}",
        "DNS:localhost",
        "DNS:*.localhost"
    ]
    san_extension = crypto.X509Extension(b"subjectAltName", False, ", ".join(san_list).encode())
    cert.add_extensions([
        san_extension,
        crypto.X509Extension(b"basicConstraints", True, b"CA:FALSE")
    ])

    # Sign the certificate with the private key
    cert.sign(private_key, 'sha256')

    # Convert certificate and private key to PEM format
    cert_pem = crypto.dump_certificate(crypto.FILETYPE_PEM, cert)
    private_key_pem = crypto.dump_privatekey(crypto.FILETYPE_PEM, private_key)

    return cert_pem, private_key_pem


def gen_self_signed_cert() -> tuple[bytes, bytes]:
    """Return (cert, key) as ASCII PEM strings using pyOpenSSL."""
    return _gen_pyopenssl()


def create_tls_keypair(
        cert_file: str = DEFAULT_CERT_FILE, key_file: str = DEFAULT_KEY_FILE, overwrite: bool = False
):
    """Create a self-signed TLS key pair and write to disk."""
    cert_file_path = Path(cert_file)
    key_file_path = Path(key_file)

    if cert_file_path.exists() or key_file_path.exists():
        if not overwrite:
            raise RuntimeError(
                f"The TLS Cert file(s): '{cert_file_path}' or '{key_file_path}' exist - "
                "and overwrite is False, aborting."
            )

        cert_file_path.unlink(missing_ok=True)
        key_file_path.unlink(missing_ok=True)

    cert, key = gen_self_signed_cert()

    cert_file_path.parent.mkdir(parents=True, exist_ok=True)
    with cert_file_path.open(mode="wb") as cert_file:
        cert_file.write(cert)

    with key_file_path.open(mode="wb") as key_file:
        key_file.write(key)

    _LOGGER.info("Created TLS Key pair successfully.")
    _LOGGER.info(f"Cert file path: {cert_file_path}")
    _LOGGER.info(f"Key file path: {key_file_path}")


@click.command()
@click.option(
    "--cert-file",
    type=str,
    default=DEFAULT_CERT_FILE,
    required=True,
    help="The TLS certificate file to create.",
)
@click.option(
    "--key-file",
    type=str,
    default=DEFAULT_KEY_FILE,
    required=True,
    help="The TLS key file to create.",
)
@click.option(
    "--overwrite/--no-overwrite",
    type=bool,
    default=False,
    show_default=True,
    required=True,
    help="Can we overwrite the cert/key if they exist?",
)
def click_create_tls_keypair(cert_file: str, key_file: str, overwrite: bool):
    """Provide a click interface to create a self-signed TLS key pair."""
    create_tls_keypair(cert_file, key_file, overwrite)


if __name__ == "__main__":
    click_create_tls_keypair()
