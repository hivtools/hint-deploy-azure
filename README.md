# hint-deploy-azure

Deployment configuration for Naomi (hint) on Azure. Infrastructure is defined in [bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep). A small Python CLI ([main.py](main.py)) deploys it and runs maintenance tasks.

## Prerequisites

* Python 3 (the CLI uses only the standard library)
* [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`), with bicep (`az bicep install`)
* `docker`. Only `update-hintr` needs it, to look up image digests.
* An Avenir access token. Set it as `AVENIR_ACCESS_TOKEN`, or the CLI will ask for it. The CLI uses it to fetch secrets, such as the DB password, from the Avenir auth server.

If you aren't logged in to Azure, the CLI runs `az login` for you.

## Environments & Configuration

Environments are defined in [config/environments.json](config/environments.json):

| Environment  | Prefix | Resource group | URL                                 |
|--------------|--------|----------------|-------------------------------------|
| `production` | `nm`   | `nmHint-RG`    | https://naomi.unaids.org            |
| `staging`    | `nms`  | `nmsHint-RG`   | https://nms-naomi.azurewebsites.net |

Each environment sets its region, its storage account names, its compute sizes and the docker image tags to deploy:

* `hintImageTag`: the tag for `ghcr.io/hivtools/hint` **and** `ghcr.io/hivtools/hint-db-migrate`
* `hintrImageTag`: the tag for `ghcr.io/hivtools/hintr` and `ghcr.io/hivtools/hintr-worker`

Worker sizes and the countries routed to each queue are set in [config/workers.json](config/workers.json).

## Usage

Run with no arguments to be walked through the options interactively:

```
./main.py
```

Or pass the options directly:

```
./main.py --env <production|staging> <command> ...
```

`--help` lists the commands and options, and works on each command too:

```
./main.py --help
./main.py --env staging deploy --help
```

### Deploying stacks

```
./main.py --env staging deploy <target> [--debug]
```

| Target            | What it deploys                                                                                  |
|-------------------|--------------------------------------------------------------------------------------------------|
| `all`             | resource groups, network, storage, app_environment, containers, backup (if the env has it)       |
| `infrastructure`  | resource groups, network, storage, app_environment: the parts that rarely change                 |
| `resource_groups` | the resource groups (a subscription-scoped deployment)                                            |
| `network`         | the vnet and subnets                                                                             |
| `storage`         | Postgres, Redis, file shares, blob storage                                                       |
| `app_environment` | the Container Apps environment and the App Service plan                                           |
| `containers`      | the hint web app, hintr, the worker jobs, the active-jobs function app and the DB migration      |
| `backup`          | backup vaults (production only)                                                                  |
| `observability`   | log analytics (production only)                                                                  |

Every stack except resource groups is deployed as an Azure deployment stack with `denyDelete`, so resources can't be deleted by hand while the stack manages them. `--debug` passes `--verbose --debug` through to `az`.

### Updating a deployment

Pick the step that matches what changed.

**Bicep or config changes** (`params/`, `bicep/`, `config/`): redeploy the affected stack, usually `containers`:

```
./main.py --env production deploy containers
```

**A new hintr image on the same tag** (e.g. a new build of `main`): `deploy containers` won't pick it up, because the bicep hasn't changed. Run:

```
./main.py --env production update-hintr
```

This looks up the current digest of the configured hintr and hintr-worker tags and points the hintr container app and every worker job at that digest.

**A new hint image on the same tag**: `update-hintr` does not touch the hint web app. Restart the web app and it pulls the image for its tag again:

```
az webapp restart -g nmHint-RG -n nm-naomi        # production
az webapp restart -g nmsHint-RG -n nms-naomi      # staging
```

**A different tag** (e.g. a release or a branch): change `hintImageTag` or `hintrImageTag` for the environment in [config/environments.json](config/environments.json), then run `deploy containers`. See the note on `hint-db-migrate` below.

### Deploying a hint branch to staging

**Quick option: point the web app straight at the image.** Nothing in this repo needs to change.

```
az webapp config container set -g nmsHint-RG -n nms-naomi \
    --container-image-name ghcr.io/hivtools/hint:<branch-name>
```

The web app restarts with the new image. To pick up a later push to the same branch, run `az webapp restart -g nmsHint-RG -n nms-naomi`. The next `deploy containers` (or `deploy all`) on staging sets the image back to `hintImageTag`.

**Persistent option: change the config.** Set `staging.hintImageTag` to the branch name in [config/environments.json](config/environments.json), then run:

```
./main.py --env staging deploy containers
```

> [!WARNING]
> `hintImageTag` is also used as the tag for `ghcr.io/hivtools/hint-db-migrate`, which is built from the separate [hint-db](https://github.com/hivtools/hint-db) repo. If hint-db has no branch with the same name, the image doesn't exist and the DB migration container group fails, which fails the deployment. Use the quick option above unless the branch also needs DB migrations. If it does, push a branch with the same name to hint-db so its image is built.

### User CLI

Runs the hint user CLI in a container instance connected to the environment's database. Use it to create users, check that a user exists, or remove users.

```
./main.py --env production user-cli add-user test.user@example.com password
./main.py --env production user-cli user-exists test.user@example.com
./main.py --env production user-cli remove-user test.user@example.com
```

Interactive mode (`./main.py`) asks for the password without echoing it, so it stays out of your shell history.

## Debugging

To get a shell in the running hintr container app:

```
az containerapp exec -g nmHint-RG -n nm-hintr --command R      # production
az containerapp exec -g nmsHint-RG -n nms-hintr --command R    # staging
```

If the container app scales down to 0 you will be disconnected. For a long debugging session, raise its minimum replicas to 1 for a while.

To stream the hint web app logs:

```
az webapp log tail -g nmsHint-RG -n nms-naomi
```

## TODO

* `deploy containers` doesn't redeploy when an image is updated on the same tag, only when the config changes. `update-hintr` works around this for hintr, but hint has to be restarted by hand.
* `hint-db-migrate` shares `hintImageTag` with hint. A separate tag would make branch deploys simpler.

