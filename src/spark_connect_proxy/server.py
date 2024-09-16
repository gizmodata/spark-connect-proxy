import logging
import os
from concurrent import futures
from pathlib import Path
from typing import List, Optional

import click
import grpc
import pyspark.sql.connect.proto.base_pb2_grpc as pb2_grpc
from grpc_channelz.v1 import channelz

from . import __version__ as spark_connect_proxy_version
from .config import SPARK_CONNECT_SERVER_DEFAULT_URL, SERVER_PORT, DEFAULT_JWT_AUDIENCE
from .logger import logger
from .security import BearerTokenAuthInterceptor

# Misc. Constants
SPARK_CONNECT_PROXY_VERSION = spark_connect_proxy_version


class LoggingInterceptor(grpc.ServerInterceptor):
    def intercept_service(self, continuation, handler_call_details):
        # Log the incoming connection details
        method_name = handler_call_details.method
        peer = handler_call_details.invocation_metadata[0].value  # Peer info

        logging.debug(msg=f"Received connection for method {method_name} from {peer}")

        # Call the actual RPC method
        return continuation(handler_call_details)


class SparkConnectProxyServicer(pb2_grpc.SparkConnectServiceServicer):
    """A gRPC servicer that proxies requests to the Spark Connect server."""

    def __init__(self, stub):
        self.stub = stub

    def ExecutePlan(self, request, context):
        return self.stub.ExecutePlan(request=request)

    def AnalyzePlan(self, request, context):
        return self.stub.AnalyzePlan(request=request)

    def Config(self, request, context):
        return self.stub.Config(request=request)

    def AddArtifacts(self, request_iterator, context):
        return self.stub.AddArtifacts(request=request_iterator)

    def ArtifactStatus(self, request, context):
        return self.stub.ArtifactStatus(request=request)

    def Interrupt(self, request, context):
        return self.stub.Interrupt(request=request)

    def ReattachExecute(self, request, context):
        return self.stub.ReattachExecute(request=request)

    def ReleaseExecute(self, request, context):
        return self.stub.ReleaseExecute(request=request)


def serve(
        version: bool,
        spark_connect_server_url: str,
        port: int,
        wait: bool,
        tls: Optional[List[str]] = None,
        enable_auth: bool = False,
        jwt_audience: Optional[str] = None,
        secret_key: Optional[str] = None,
        log_level: str = "INFO",
):
    """Start the Spark Connect Proxy server."""
    if version:
        print(f"Spark Connect Proxy - version: {SPARK_CONNECT_PROXY_VERSION}")
        return

    arg_dict = locals()
    if arg_dict.pop("secret_key"):
        arg_dict["secret_key"] = "(redacted)"

    logger.info(
        msg=f"Initializing Spark Connect Proxy server - version: {SPARK_CONNECT_PROXY_VERSION} - args: {arg_dict}")
    logger.info(msg=f"Proxying Spark Connect server at: {spark_connect_server_url}")

    # Set up the Spark Connect gRPC client (without TLS)
    channel = grpc.insecure_channel(target=spark_connect_server_url)
    stub = pb2_grpc.SparkConnectServiceStub(channel=channel)

    interceptors = [LoggingInterceptor()]
    if enable_auth:
        if not secret_key:
            raise ValueError("Secret key must be provided when enabling auth.")
        interceptors.append(
            BearerTokenAuthInterceptor(audience=jwt_audience, secret_key=secret_key, logger=logger)
        )
        logger.info(msg="Token authentication is required for client connections.")
    else:
        logger.warning(msg="Token authentication is disabled - client connections will be insecure.")

    server = grpc.server(
        thread_pool=futures.ThreadPoolExecutor(max_workers=10), interceptors=interceptors
    )

    # Add the proxy service
    proxy_servicer = SparkConnectProxyServicer(stub)
    pb2_grpc.add_SparkConnectServiceServicer_to_server(servicer=proxy_servicer, server=server)

    server_credentials = None
    if tls:
        tls_certfile = Path(tls[0])
        tls_keyfile = Path(tls[1])

        # Load server certificate and key
        with open(tls_certfile, "rb") as f:
            server_certificate = f.read()
        with open(tls_keyfile, "rb") as f:
            server_key = f.read()

        # Create SSL credentials for the server
        server_credentials = grpc.ssl_server_credentials(
            private_key_certificate_chain_pairs=[(server_key, server_certificate)]
        )
        logger.info(msg="TLS/SSL is enabled for client connections.")
    else:
        logger.warning(msg="TLS/SSL not enabled - client connections will be insecure.")

    if server_credentials:
        server.add_secure_port(address=f"[::]:{port}", server_credentials=server_credentials)
    else:
        server.add_insecure_port(address=f"[::]:{port}")

    channelz.add_channelz_servicer(server)

    logger.info(
        f"Starting SparkConnect Proxy server - version: {SPARK_CONNECT_PROXY_VERSION} - listening on port: {port}")
    server.start()
    if wait:
        server.wait_for_termination()
    return server


@click.command()
@click.option(
    "--version/--no-version",
    type=bool,
    default=False,
    show_default=False,
    required=True,
    help="Prints the Spark Connect Proxy version and exits."
)
@click.option(
    "--spark-connect-server-url",
    type=str,
    default=os.getenv("SPARK_CONNECT_SERVER_URL", SPARK_CONNECT_SERVER_DEFAULT_URL),
    show_default=True,
    required=True,
    help="The running Spark Connect server URL (for which we will proxy).",
)
@click.option(
    "--port",
    type=int,
    default=os.getenv("SERVER_PORT", SERVER_PORT),
    show_default=True,
    required=True,
    help="Run the Spark Connect Server Proxy server on this port.",
)
@click.option(
    "--wait/--no-wait",
    type=bool,
    default=True,
    show_default=True,
    required=True,
    help="Keep the server running until it is manually stopped.",
)
@click.option(
    "--tls",
    nargs=2,
    default=os.getenv("TLS").split(" ") if os.getenv("TLS") else None,
    required=False,
    metavar=("CERTFILE", "KEYFILE"),
    help="Enable transport-level security (TLS/SSL).  Provide a "
         "Certificate file path, and a Key file path - separated by a space.  "
         "Example: tls/server.crt tls/server.key",
)
@click.option(
    "--enable-auth/--no-enable-auth",
    type=bool,
    default=os.getenv("ENABLE_AUTH", "False").upper() == "TRUE",
    required=True,
    help="Enable JWT authentication for the server.",
)
@click.option(
    "--jwt-audience",
    type=str,
    default=os.getenv("JWT_AUDIENCE", DEFAULT_JWT_AUDIENCE),
    required=False,
    help="The JWT audience used for verification.",
)
@click.option(
    "--secret-key",
    type=str,
    default=os.getenv("SECRET_KEY"),
    required=False,
    help="The secret key used to sign/verify the JWT - if authentication is enabled.",
)
@click.option(
    "--log-level",
    type=str,
    default=os.getenv("LOG_LEVEL", "INFO"),
    required=True,
    help="The logging level to use for the server.",
)
def click_serve(
        version: bool,
        spark_connect_server_url: str,
        port: int,
        wait: bool,
        tls: List[str],
        enable_auth: bool,
        jwt_audience: str,
        secret_key: str,
        log_level: str,
):
    return serve(**locals())


if __name__ == "__main__":
    click_serve()
