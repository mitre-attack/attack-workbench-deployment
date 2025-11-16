# Database Backups

The MongoDB commands `mongodump` and `mongorestore` can be used to create the database backup files and to restore the database using those files.

The `compose.yaml` file maps the `database-backup/` directory on the host to the `/dump` directory
in the container in order to ease access to the backup files and to make sure those files exist even if the container is deleted.
This directory is listed in the `.gitignore` file so the backup files will not be added to the git repo.

To access the command line inside the container, run this command from the host:

```shell
docker exec -it attack-workbench-database bash
```

## Single Archive File

These commands backup the data in a single compressed file.

### Creating a Database Backup

Create the backup as a compressed archive file:

```shell
# From inside the attack-workbench-database container
mongodump --db attack-workspace --gzip --archive=dump/workspace.archive.gz
```

This creates a file in `/dump` in the container (`database-backup/` on the host).

### Restoring the Database from the Backup

The backup file must be in `database-backup/` on the host.

Restoring from the compressed archive file:

```shell
# From inside the attack-workbench-database container
mongorestore --drop --gzip --archive=dump/workspace.archive.gz
```

This drops the collections from the database, recreates the collections, loads the backed up documents into those collections, and rebuilds the indexes.

## Multiple Files

These commands backup the data in multiple files (a file for each collection and index).

### Creating a Database Backup

Create the backup files:

```shell
# From inside the attack-workbench-database container
mongodump --db attack-workspace
```

This creates a set of files in `/dump/attack-workspace` in the container (`/database-backup/attack-workspace` on the host).

### Restoring the Database from the Backup Files

The backup files must be in `database-backup/attack-workspace` on the host.

Restoring from the backup files:

```shell
# From inside the attack-workbench-database container
mongorestore --drop dump/
```

This drops the collections from the database, recreates the collections, loads the backed up documents into those collections, and rebuilds the indexes.
