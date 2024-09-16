# SPDX-License-Identifier: Apache-2.0
"""A utility to create a JWT token for the gateway."""

import logging
import os
import time
import sys

import click
import jwt
from ..config import DEFAULT_JWT_SUBJECT, DEFAULT_JWT_ISSUER, DEFAULT_JWT_AUDIENCE, DEFAULT_JWT_LIFETIME

# Setup logging
logging.basicConfig(format='%(asctime)s - %(levelname)-8s %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S %Z',
                    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper()),
                    stream=sys.stdout
                    )

logger = logging.getLogger()


def create_jwt(
        issuer: str,
        subject: str,
        audience: str,
        lifetime: int,
        secret_key: str
):
    """Create a JWT token for the given issuer, subject, audience, lifetime and secret key."""
    iat = time.time()
    exp = iat + lifetime
    payload = {"iss": issuer, "sub": subject, "aud": audience, "iat": iat, "exp": exp}
    signed_jwt = jwt.encode(payload=payload, key=secret_key, algorithm="HS256")

    logger.info(msg=f"Created JWT:\n{signed_jwt}")


@click.command()
@click.option(
    "--issuer",
    type=str,
    default=os.getenv("JWT_ISSUER", DEFAULT_JWT_ISSUER),
    show_default=True,
    required=True,
    help="The issuer to set within the JWT.",
)
@click.option(
    "--subject",
    type=str,
    default=os.getenv("JWT_SUBJECT", DEFAULT_JWT_SUBJECT),
    show_default=True,
    required=True,
    help="The subject to set within the JWT.",
)
@click.option(
    "--audience",
    type=str,
    default=os.getenv("JWT_AUDIENCE", DEFAULT_JWT_AUDIENCE),
    show_default=True,
    required=True,
    help="The audience to set within the JWT.",
)
@click.option(
    "--lifetime",
    type=int,
    default=DEFAULT_JWT_LIFETIME,
    show_default=True,
    required=True,
    help="The lifetime (in seconds) for the JWT.",
)
@click.option(
    "--secret-key",
    type=str,
    default=os.getenv("SECRET_KEY"),
    required=True,
    help="The secret key used to sign the JWT.",
)
def click_create_jwt(issuer: str,
                     subject: str,
                     audience: str,
                     lifetime: int,
                     secret_key: str
                     ):
    create_jwt(**locals())


if __name__ == "__main__":
    click_create_jwt()
