import json

from ..common.az import ROOT, DeployError, az

# Param files are shared between environments, they read HINT_ENV to pick
# their values from environments.json
PARAMS_DIR = ROOT / "params"

# stack -> (deployment stack name, environments.json key for its resource group)
STACKS = {
    "network": ("network-stack", "resourceGroup"),
    "storage": ("storage-stack", "resourceGroup"),
    "app_environment": ("environment-stack", "resourceGroup"),
    "containers": ("containers-stack", "resourceGroup"),
    "backup": ("backup-stack", "backupResourceGroup"),
    "observability": ("observability-stack", "observabilityResourceGroup"),
}

# Deployed at subscription scope, before any stack, since stacks need their
# resource group to exist already
RESOURCE_GROUPS = "resource_groups"

TARGETS = {
    "all": [
        RESOURCE_GROUPS,
        "network",
        "storage",
        "app_environment",
        "containers",
        "backup",
    ],
    "infrastructure": [RESOURCE_GROUPS, "network", "storage", "app_environment"],
    RESOURCE_GROUPS: [RESOURCE_GROUPS],
    **{stack: [stack] for stack in STACKS},
}


def params_file(stack):
    return str((PARAMS_DIR / f"{stack}.bicepparam").relative_to(ROOT))


def stack_enabled(stack, config):
    if stack == RESOURCE_GROUPS:
        return True
    # A null resource group in environments.json means the stack isn't used in that environment
    return config.get(STACKS[stack][1]) is not None


def stacks_for_target(target, config):
    stacks = TARGETS[target]
    if len(stacks) > 1:
        # Skip stacks this environment doesn't deploy, e.g. backup and observability for staging
        stacks = [stack for stack in stacks if stack_enabled(stack, config)]
    return stacks


def available_targets(config):
    """Targets this environment can deploy, mapped to the stacks they would run."""
    targets = {}
    for target in TARGETS:
        stacks = stacks_for_target(target, config)
        if all(stack_enabled(stack, config) for stack in stacks):
            targets[target] = stacks
    return targets


def deploy_resource_groups(config, debug=False):
    params = build_params(RESOURCE_GROUPS)
    print(f"Creating resource groups {', '.join(params['resourceGroupNames'])}")
    # A plain deployment rather than a stack: a subscription stack with deny
    # settings would put a deny assignment on each whole resource group
    az(
        "deployment",
        "sub",
        "create",
        *(["--verbose", "--debug"] if debug else []),
        "--name",
        f"{config['prefix']}-resource-groups",
        "--location",
        params["location"],
        "--template-file",
        f"bicep/{RESOURCE_GROUPS}.bicep",
        "--parameters",
        params_file(RESOURCE_GROUPS),
    )


def deploy_stack(stack, config, debug=False):
    if stack == RESOURCE_GROUPS:
        deploy_resource_groups(config, debug)
        return
    stack_name, resource_group_key = STACKS[stack]
    if not stack_enabled(stack, config):
        raise DeployError(
            f"Stack '{stack}' is not deployed for this environment (no '{resource_group_key}' set)"
        )
    resource_group = config[resource_group_key]

    print(f"Deploying {stack_name} to {resource_group}")
    az(
        "stack",
        "group",
        "create",
        *(["--verbose", "--debug"] if debug else []),
        "--name",
        stack_name,
        "--resource-group",
        resource_group,
        "--template-file",
        f"bicep/{stack}.bicep",
        "--parameters",
        params_file(stack),
        "--action-on-unmanage",
        "detachAll",
        "--deny-settings-mode",
        "denyDelete",
    )


def build_params(stack):
    output = az(
        "bicep", "build-params", "--file", params_file(stack), "--stdout", capture=True
    )
    parameters = json.loads(json.loads(output)["parametersJson"])["parameters"]
    return {name: param.get("value") for name, param in parameters.items()}
