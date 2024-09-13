import os
from typing import Optional

import click
import ibis
import pandas as pd
from codetiming import Timer
from ibis import _
from pyspark.sql import SparkSession

from ..config import SERVER_PORT
from ..logger import logger

# Constants
TIMER_TEXT = "{name}: Elapsed time: {:.4f} seconds"

# Setup pandas
pd.set_option("display.width", 0)
pd.set_option("display.max_columns", 99)
pd.set_option("display.max_colwidth", None)
pd.set_option("display.float_format", '{:,.2f}'.format)


def run_client_example(host: str,
                       port: int,
                       use_tls: bool,
                       tls_roots: Optional[str] = None,
                       token: Optional[str] = None
                       ):
    arg_dict = locals()
    if arg_dict.pop("token"):
        arg_dict["token"] = "(redacted)"

    logger.info(msg=f"Running Spark Connect Proxy - Ibis client example - args: {arg_dict}")

    spark_connect_server_url = f"sc://{host}:{port}/"
    logger.info(msg=f"Using Spark Connect Server URL: {spark_connect_server_url}")

    if use_tls:
        spark_connect_server_url += ";use_ssl=true"
    if tls_roots:
        os.environ["GRPC_DEFAULT_SSL_ROOTS_FILE_PATH"] = tls_roots
    if token:
        spark_connect_server_url += ";token=" + token

    # Get a Spark Session
    spark = (SparkSession
             .builder
             .appName(name="Ibis-Rocks!")
             .remote(url=spark_connect_server_url)
             .getOrCreate()
             )

    # Connect the Ibis PySpark back-end to the Spark Session
    con = ibis.pyspark.connect(spark)

    # Read the parquet data into an ibis table
    t = con.read_parquet(
        "s3://gbif-open-data-us-east-1/occurrence/2023-04-01/occurrence.parquet/*"
    )

    # Perform a simple query
    with Timer(name=f"Running query in Spark Connect remote cluster",
               text=TIMER_TEXT,
               initial_text=True,
               logger=logger.info
               ):
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
            .to_pandas()
        )

        logger.info(msg=f"Output data:\n{f}")


@click.command()
@click.option(
    "--host",
    type=str,
    default=os.getenv("SERVER_HOST", "localhost"),
    show_default=True,
    required=True,
    help="The Spark Connect Proxy (or server) hostname.",
)
@click.option(
    "--port",
    type=int,
    default=os.getenv("SERVER_PORT", SERVER_PORT),
    show_default=True,
    required=True,
    help="Run the Spark Substrait Gateway server on this port.",
)
@click.option(
    "--use-tls/--no-use-tls",
    type=bool,
    default=False,
    required=True,
    help="Enable transport-level security (TLS/SSL).",
)
@click.option(
    "--tls-roots",
    type=str,
    default=os.getenv("TLS_ROOTS", None),
    show_default=True,
    required=False,
    help="The path to the root certificates for the TLS/SSL connection.",
)
@click.option(
    "--token",
    type=str,
    default=os.getenv("JWT_TOKEN", None),
    show_default=False,
    required=False,
    help="The JWT token to use for authentication - if required.",
)
def click_run_client_example(host: str,
                             port: int,
                             use_tls: bool,
                             tls_roots: str,
                             token: str
                             ):
    run_client_example(**locals())


if __name__ == "__main__":
    click_run_client_example()
