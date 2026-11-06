import getpass
import json
import os
import urllib.error
import urllib.request

from .az import DeployError

AVENIR_AUTH_URL = "https://api.authadmin.avenirhealth.org/v1/api/roles/fetchuserskeys"


def check_av_access_token():
    token = os.environ.get("AVENIR_ACCESS_TOKEN")
    if not token:
        print("AVENIR_ACCESS_TOKEN is not set.")
        token = getpass.getpass("Please enter AVENIR_ACCESS_TOKEN: ")
        os.environ["AVENIR_ACCESS_TOKEN"] = token
    return token


def fetch_and_set_secret_env(*keys):
    """Fetch keys from the Avenir auth server and set them as environment variables."""
    token = check_av_access_token()

    request = urllib.request.Request(
        AVENIR_AUTH_URL,
        data=json.dumps({"keyAccessToken": token}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request) as response:
            content = json.load(response)
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        raise DeployError(f"Failed to fetch data from Avenir Auth server, HTTP status code: {e.code}\n{body}")
    except urllib.error.URLError as e:
        raise DeployError(f"Failed to connect to {AVENIR_AUTH_URL}: {e.reason}")
    except json.JSONDecodeError:
        raise DeployError("Failed to parse response from Avenir Auth server")

    values = {key["name"]: key["value"] for key in content.get("keys", []) if key["name"] in keys}
    missing = [key for key in keys if key not in values]
    if missing:
        raise DeployError(f"Required keys not found in the response: {', '.join(missing)}")

    os.environ.update(values)
    print("Environment read from Avenir Auth server")
