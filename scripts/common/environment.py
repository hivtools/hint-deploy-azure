import json
import os

from .az import ROOT, DeployError

ENVIRONMENTS_FILE = ROOT / "config" / "environments.json"


def environment_names():
    return list(json.loads(ENVIRONMENTS_FILE.read_text()))


def set_env(name):
    """Load the config for an environment and set HINT_ENV for the bicepparam files."""
    environments = json.loads(ENVIRONMENTS_FILE.read_text())
    if name not in environments:
        raise DeployError(
            f"Unknown environment '{name}', expected one of: {', '.join(environments)}"
        )
    config = environments[name]
    os.environ["HINT_ENV"] = name
    return config
