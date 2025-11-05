# Migrating from MongoDB 5 to 8

This document outlines the process for migrating the ATT&CK Workbench from MongoDB 5 to MongoDB 8.

**IMPORTANT:** This process has been tested for a single-node deployment.
If you are running a multi-node replica set, you will need to adapt these instructions.

**NOTE:** This guide uses major version tags (e.g., `mongo:6`, `mongo:7`, `mongo:8`) rather than minor versions (e.g., `mongo:6.0`). Docker will automatically pull the latest patch version within each major version, which is recommended for security updates.

## Prerequisites

* Docker and Docker Compose must be installed.
* You must have a running instance of the ATT&CK Workbench with MongoDB 5.

## Automated Migration

For convenience, an automated migration script is provided:

```bash
./migrate-mongodb.sh
```

This script performs all the steps outlined below automatically. The script supports:

* **Full migration**: MongoDB 5 → 6 → 7 → 8
* **Resume migration**: If you're already on MongoDB 6 or 7, the script will resume from that point
* **Automatic detection**: The script detects your current version and only runs necessary upgrades

Continue reading for manual migration steps.

## Manual Migration Steps

### Step 0: Backup Your Data

**CRITICAL:** Before starting the migration, create a backup of your MongoDB data.

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ fsync: 1, lock: true })"
docker exec attack-workbench-database mongodump --out=/dump/pre-migration-backup
docker exec attack-workbench-database mongosh --eval "db.fsyncUnlock()"
```

The backup will be stored in `./database-backup/pre-migration-backup/` on your host system.

### Step 1: Set the `featureCompatibilityVersion` to `5.0`

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ setFeatureCompatibilityVersion: '5.0' })"
```

Verify the version was set successfully:

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })"
```

### Step 2: Stop the containers

```bash
docker compose -f compose.yaml -f compose.dev.yaml down
```

### Step 3: Upgrade to MongoDB 6

Update the `image` field in the `database` service in `compose.yaml` from `mongo:5` to `mongo:6`:

```yaml
  database:
    container_name: attack-workbench-database
    image: mongo:6  # <-- Change this line only
    ports:
      - "${ATTACKWB_DB_PORT:-27017}:${ATTACKWB_DB_PORT:-27017}"
    volumes:
      - workspace-data:/data/db
      - ./database-backup:/dump
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 5
```

### Step 4: Start the containers

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d --build
```

Wait for the database to be healthy (this may take 30-60 seconds):

```bash
docker compose ps database
```

Wait until the status shows `healthy` before proceeding.

### Step 5: Verify MongoDB version and set `featureCompatibilityVersion` to `6.0`

Verify MongoDB 6.0 is running:

```bash
docker exec attack-workbench-database mongosh --eval "db.version()"
```

Set the feature compatibility version:

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ setFeatureCompatibilityVersion: '6.0' })"
```

Verify the version was set successfully:

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })"
```

### Step 6: Stop the containers

```bash
docker compose -f compose.yaml -f compose.dev.yaml down
```

### Step 7: Upgrade to MongoDB 7

Update the `image` field in the `database` service in `compose.yaml` from `mongo:6` to `mongo:7`:

```yaml
  database:
    container_name: attack-workbench-database
    image: mongo:7  # <-- Change this line only
    ports:
      - "${ATTACKWB_DB_PORT:-27017}:${ATTACKWB_DB_PORT:-27017}"
    volumes:
      - workspace-data:/data/db
      - ./database-backup:/dump
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 5
```

### Step 8: Start the containers

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d --build
```

Wait for the database to be healthy:

```bash
docker compose ps database
```

### Step 9: Verify MongoDB version and set `featureCompatibilityVersion` to `7.0`

Verify MongoDB 7.0 is running:

```bash
docker exec attack-workbench-database mongosh --eval "db.version()"
```

Set the feature compatibility version (note: MongoDB 7.0+ requires `confirm: true`):

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ setFeatureCompatibilityVersion: '7.0', confirm: true })"
```

Verify the version was set successfully:

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })"
```

### Step 10: Stop the containers

```bash
docker compose -f compose.yaml -f compose.dev.yaml down
```

### Step 11: Upgrade to MongoDB 8

Update the `image` field in the `database` service in `compose.yaml` from `mongo:7` to `mongo:8`:

```yaml
  database:
    container_name: attack-workbench-database
    image: mongo:8  # <-- Change this line only
    ports:
      - "${ATTACKWB_DB_PORT:-27017}:${ATTACKWB_DB_PORT:-27017}"
    volumes:
      - workspace-data:/data/db
      - ./database-backup:/dump
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 5
```

### Step 12: Start the containers

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d --build
```

Wait for the database to be healthy:

```bash
docker compose ps database
```

### Step 13: Verify MongoDB version and set `featureCompatibilityVersion` to `8.0`

Verify MongoDB 8.0 is running:

```bash
docker exec attack-workbench-database mongosh --eval "db.version()"
```

Set the feature compatibility version:

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ setFeatureCompatibilityVersion: '8.0', confirm: true })"
```

Verify the version was set successfully:

```bash
docker exec attack-workbench-database mongosh --eval "db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })"
```

## Migration Complete

Your ATT&CK Workbench instance is now running on MongoDB 8.0.

## Troubleshooting

### If the migration fails at any step

1. Check the MongoDB logs:

   ```bash
   docker compose logs database
   ```

2. Restore from backup (replace `<step>` with the step where you failed):

   ```bash
   docker compose down
   docker volume rm attack-workbench-deployment_workspace-data
   docker volume create attack-workbench-deployment_workspace-data
   docker compose up -d database
   # Wait for database to be healthy
   docker exec attack-workbench-database mongorestore /dump/pre-migration-backup
   ```

3. Start over from Step 1 or seek assistance.

### Verifying the health of your database after migration

```bash
# Check server status
docker exec attack-workbench-database mongosh --eval "db.serverStatus()"

# Check if all collections are accessible
docker exec attack-workbench-database mongosh --eval "db.adminCommand('listDatabases')"
```
