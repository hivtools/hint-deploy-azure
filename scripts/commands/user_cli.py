import os
import shlex

from ..common.az import az

USER_CLI_IMAGE = "ghcr.io/hivtools/hint-user-cli:nm-125"


def user_cli(config, command_args):
    """Run the hint user CLI in a container instance connected to the database."""
    prefix = config["prefix"]
    resource_group = config["resourceGroup"]
    storage_account = config["storageAccountName"]

    storage_key = az(
        "storage",
        "account",
        "keys",
        "list",
        "--resource-group",
        resource_group,
        "--account-name",
        storage_account,
        "--query",
        "[0].value",
        "-o",
        "tsv",
        capture=True,
    )
    subnet_id = az(
        "network",
        "vnet",
        "subnet",
        "show",
        "--resource-group",
        resource_group,
        "--vnet-name",
        f"{prefix}-hint-nw",
        "--name",
        f"{prefix}-hint-db-migrate-subnet",
        "--query",
        "id",
        "-o",
        "tsv",
        capture=True,
    )

    cli_command = shlex.join(["/userCLI/bin/userCLI", *command_args])
    az(
        "container",
        "create",
        "--resource-group",
        resource_group,
        "--name",
        "hint-user-cli",
        "--image",
        USER_CLI_IMAGE,
        "--command-line",
        f"/bin/sh -c {shlex.quote(cli_command)}",
        "--os-type",
        "Linux",
        "--cpu",
        "0.25",
        "--memory",
        "0.5",
        "--environment-variables",
        f"DB_URL=jdbc:postgresql://{prefix}-hint-db.postgres.database.azure.com/hint",
        f"HINTR_URL=http://{prefix}-hintr",
        f"APPLICATION_URL={config['applicationUrl']}",
        "--secure-environment-variables",
        f"AVENIR_NM_EMAIL_PASSWORD={os.environ['AVENIR_NM_EMAIL_PASSWORD']}",
        f"AVENIR_NM_ISSUE_REPORT_URL={os.environ['AVENIR_NM_ISSUE_REPORT_URL']}",
        f"AVENIR_NM_DB_PASSWORD={os.environ['AVENIR_NM_DB_PASSWORD']}",
        "--restart-policy",
        "Never",
        "--azure-file-volume-share-name",
        "config-share",
        "--azure-file-volume-account-name",
        storage_account,
        "--azure-file-volume-account-key",
        storage_key,
        "--azure-file-volume-mount-path",
        "/etc/hint",
        "--subnet",
        subnet_id,
    )
