# hint-azure

Repo for Naomi/hint azure deployment configuration. Configuration is via [bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep).

## Usage

To deploy or update run

```
./start 
```

### User CLI

This repo also contains a script that will run the the user CLI in a container instance connecting to the running database. Use this to create users, update password etc.

### Usage

```
./user-cli add-user test.user@example.com password
./user-cli user-exists test.user@example.com
./user-cli remove-user test.user@example.com
```

## TODO

This just uses one big block of configuration I'd like to
1. Split this up into more re-usable chunks (see network file for an example)
2. Set up parameters so we could easily deploy a dev/production instance with chosen docker image tags and resources/scaling rules
3. This won't redeploy if the docker container has been updated, only if the config itself has changed. How can I control this better?