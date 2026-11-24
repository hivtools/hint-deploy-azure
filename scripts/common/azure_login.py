import subprocess

from .az import az, require_executable

TENANT_ID = "14b292c0-30d6-4933-b442-65f54ff20563"


def azure_login():
    logged_in = subprocess.run(
        [require_executable("az"), "account", "show"],
        capture_output=True,
        check=False,
    ).returncode == 0
    if logged_in:
        print("You are already logged in to Azure.")
        return
    print("You are not logged in to Azure. Logging in now...")
    az("login", "--tenant", TENANT_ID)
    print("Azure login successful.")
