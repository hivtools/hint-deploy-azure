"""
Deploy and manage hint on Azure.

Run with no arguments to be walked through the options, or pass them directly:
    python main.py --env production deploy all
    python main.py --env staging deploy containers
    python main.py --env production update-hintr
    python main.py --env production user-cli add-user test.user@example.com password
"""

import argparse
import subprocess
import sys

from .commands.deploy import TARGETS, deploy_stack, stacks_for_target
from .commands.update_hintr import update_hintr
from .commands.user_cli import user_cli
from .common.az import DeployError
from .common.azure_login import azure_login
from .common.environment import set_env
from .common.secret_env import fetch_and_set_secret_env
from .interactive import prompt_for_args


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--env", required=True, help="Environment from config/environments.json"
    )
    commands = parser.add_subparsers(dest="command", required=True)

    deploy = commands.add_parser("deploy", help="Deploy one or more bicep stacks")
    deploy.add_argument("target", choices=TARGETS)
    deploy.add_argument(
        "--debug", action="store_true", help="Pass --verbose --debug to az"
    )

    commands.add_parser(
        "update-hintr",
        help="Update hintr and workers to the latest image for their tag",
    )

    cli = commands.add_parser(
        "user-cli",
        help="Run the hint user CLI, e.g. user-cli add-user <email> <password>",
    )
    cli.add_argument("cli_args", nargs=argparse.REMAINDER)

    return parser.parse_args(argv)


def run(config, args):
    if args.command == "deploy":
        fetch_and_set_secret_env("AVENIR_NM_DB_PASSWORD")
        azure_login()
        for stack in stacks_for_target(args.target, config):
            deploy_stack(stack, config, args.debug)
    elif args.command == "update-hintr":
        fetch_and_set_secret_env("AVENIR_NM_DB_PASSWORD")
        azure_login()
        update_hintr(config)
    elif args.command == "user-cli":
        fetch_and_set_secret_env(
            "AVENIR_NM_DB_PASSWORD",
            "AVENIR_NM_EMAIL_PASSWORD",
            "AVENIR_NM_ISSUE_REPORT_URL",
        )
        azure_login()
        user_cli(config, args.cli_args)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    try:
        if argv:
            args = parse_args(argv)
            config = set_env(args.env)
        else:
            config, args = prompt_for_args()
            if args is None:
                print("Cancelled")
                return 0
        run(config, args)
    except KeyboardInterrupt:
        print("\nCancelled")
        return 130
    except DeployError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print(f"Error: command failed with exit code {e.returncode}", file=sys.stderr)
        return e.returncode
    return 0
