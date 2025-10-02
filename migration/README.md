# Data migration

Contains migration plan from on-prem onto the cloud. There are a few bits of data we need to move:

1. Redis data - we have an rdb and aof
2. Postgres database
3. Files

## How it will work

1. Azure managed redis can restore from a blob store, so we need to upload an rdb into a blob store and resotre from this
2. Postgres is more fiddly as this is in a vnet. We need to
3. Files should be straightforward, we just need to copy these into the relevant areas

## Plan

1. Back up the current production using privateer
1. Install azure CLI onto server and authenticate
    ```
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    az login --tenant 14b292c0-30d6-4933-b442-65f54ff20563
    ```
1. Take the front-end of the app down
    ```
    docker stop hint-hint hint-hintr-api-* hint-hintr-worker-*
    ```
1. Dump redis database to rdb
    ```
    docker exec -it hint-redis redis-cli SAVE
    ```
1. Copy the rdb out of the container and copy it onto azure
    ```
    docker cp hint-redis:/dump.rdb redis-dump.rdb
    az storage blob upload \
      --account-name naomibackupstorage \
      --container-name data-migration \
      --name redis-dump.rdb \
      --file ./redis-dump.rdb
    ```
1. Manually restore redis from this uploaded blob (or find some command to do it)
1. Dump the postgres database
   ```
   docker exec -it hint-db pg_dump -U postgres -c hint > db_dump.sql
   ```
1. Copy the postgres dump into blob store using az copy
   ```
   az storage file upload \
      --account-name naomibackupstorage \
      --share-name migration-share \
      --path db_dump.sql \
      --source ./db_dump.sql
   ```
1. Run a container to restore the dump into postgres
   ```
   az container create \
     --name pg-restore \
     --resource-group nmHint-RG \
     --image postgres:17 \
     --cpu 2 --memory 4 \
     --restart-policy Never \
     --azure-file-volume-account-name naomibackupstorage \
     --azure-file-volume-account-key "<account key>" \
     --azure-file-volume-share-name migration-share \
     --azure-file-volume-mount-path /mnt \
     --vnet nm-hint-nw \
     --subnet nm-hint-db-migrate-subnet \
     --os-type Linux \
     --environment-variables PGPASSWORD=<postgres password> \
     --command-line "psql -h nm-hint-db.postgres.database.azure.com --port 5432 -d hint -U hintuser -f /mnt/db_dump.sql"
   ```
1. Check logs
   ```
   az container logs --name pg-restore --resource-group nmHint-RG
   ```
1. Start screen session
   `screen`
1. Install azcopy (change the ubuntu version if we need see `cat /etc/lsb-release`)
   ```
   curl -sSL -O https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
   sudo dpkg -i packages-microsoft-prod.deb
   rm packages-microsoft-prod.deb
   sudo apt-get update
   sudo apt-get install azcopy
   ```
1. Create a new SAS token for uploading files
1. Run az copy to copy files into file share, remove any output files.
   Find the local path to docker files for the uploads and results volume. And time it.
   ```
   time azcopy copy "local/path/*" \
     "https://naomiappstorage.file.core.windows.net/uploads-share/?<sas token>" \
     --from-to LocalFileSMB \
     --recursive=true
   time azcopy copy "local/path/*" \
     "https://naomiappstorage.file.core.windows.net/results-share/?<sas token>" \
     --from-to LocalFileSMB \
     --recursive=true \
     --include-pattern="*.rds;*.qs;*.duckdb"
   ```
