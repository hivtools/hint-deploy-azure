import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class DeployError(Exception):
    pass


def require_executable(name):
    path = shutil.which(name)
    if path is None:
        raise DeployError(f"'{name}' not found on PATH")
    return path


def az(*args, capture=False):
    result = subprocess.run(
        [require_executable("az"), *args],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else None
