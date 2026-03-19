# Database Backups

TODO: Clean up this documentation! Make it way easier to manage!

The MongoDB commands `mongodump` and `mongorestore` can be used to create the database backup files and to restore the database using those files.

The `compose.yaml` file maps the `ATTACKWB_DB_BACKUP_PATH` directory (defaults to `./database-backup`) on the host to the `/dump` directory
in the container in order to ease access to the backup files and to make sure those files exist even if the container is deleted.
This directory is listed in the `.gitignore` file so the backup files will not be added to the git repo.

To access the command line inside the container, run this command from the host:

```shell
docker exec -it attack-workbench-database bash
```

## Creating a Database Backup

Create the backup as a compressed archive file:

```shell
# From inside the attack-workbench-database container
mongodump --db attack-workspace --gzip --archive=dump/workspace.archive.gz
```

This creates a file in `/dump` in the container (`$ATTACKWB_DB_BACKUP_PATH` on the host).

## Restoring the Database from the Backup

The backup file must be in `$ATTACKWB_DB_BACKUP_PATH` on the host.

Restoring from the compressed archive file:

```shell
# From inside the attack-workbench-database container
mongorestore --drop --gzip --archive=dump/workspace.archive.gz
```

This drops the collections from the database, recreates the collections, loads the backed up documents into those collections, and rebuilds the indexes.
