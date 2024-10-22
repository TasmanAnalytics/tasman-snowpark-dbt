import argparse
import logging
import os
import sys

from dbt.cli.main import dbtRunner

logging.basicConfig(stream=sys.stdout, level=logging.INFO)  # To enable logs in Snowpark
logger = logging.getLogger(__name__)


def get_snowflake_oauth_token() -> str:
    with open("/snowflake/session/token", "r") as f:
        return f.read()


def parse_command():
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", type=str, default="dbt debug")

    args = parser.parse_args()
    command = args.command

    return command


def run_dbt_command(command: str) -> None:
    dbt = dbtRunner()

    cli_args = command.split(" ")
    cli_args.remove("dbt")  # "dbt" not required to be in the list

    result = dbt.invoke(cli_args)

    if result.exception:
        raise Exception(f"dbt command failed! Error: {result.exception}")

    for r in result.result:
        logger.info(f"{r.node.name}: {r.status}")


def main():
    os.environ["SNOWFLAKE_TOKEN"] = get_snowflake_oauth_token()
    dbt_command = parse_command()

    logger.info(f"Running command '{dbt_command}'...")

    run_dbt_command(dbt_command)


if __name__ == "__main__":
    main()
