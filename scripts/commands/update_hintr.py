import json
import subprocess

from ..common.az import ROOT, az, require_executable
from .deploy import build_params

WORKERS_FILE = ROOT / "config" / "workers.json"


def image_digest(image):
    output = subprocess.run(
        [require_executable("docker"), "manifest", "inspect", image],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout
    return json.loads(output)["manifests"][0]["digest"]


def update_hintr(config):
    """Point hintr and the worker jobs at the latest image digest for their tag."""
    resource_group = config["resourceGroup"]
    params = build_params("containers")

    hintr_image = params["hintrImage"]
    hintr_repo, hintr_tag = hintr_image.rsplit(":", 1)
    hintr_digest = image_digest(hintr_image)
    print("Updating hintr app")
    az(
        "containerapp",
        "update",
        "-n",
        params["hintrName"],
        "-g",
        resource_group,
        "--image",
        f"{hintr_repo}@{hintr_digest}",
        "--tags",
        f"IMAGE_TAG={hintr_tag}",
        f"IMAGE_SHA={hintr_digest}",
        "-o",
        "none",
    )
    print("Complete")

    worker_image = params["hintrWorkerImage"]
    worker_repo, _ = worker_image.rsplit(":", 1)
    worker_digest = image_digest(worker_image)
    workers = json.loads(WORKERS_FILE.read_text())["workers"]
    for worker in workers:
        job_name = f"{config['prefix']}-hintr-{worker}-job"
        print(f"Updating {job_name}")
        az(
            "containerapp",
            "job",
            "update",
            "-n",
            job_name,
            "-g",
            resource_group,
            "--image",
            f"{worker_repo}@{worker_digest}",
            "-o",
            "none",
        )
        print("Complete")
