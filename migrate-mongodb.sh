#!/bin/bash

# MongoDB Migration Script: 5.0 -> 8.0
# This script automates the migration process outlined in MIGRATION.md
# For ATT&CK Workbench deployment

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILES="-f compose.yaml -f compose.dev.yaml"
CONTAINER_NAME="attack-workbench-database"
BACKUP_DIR="./database-backup/migration-backup"
HEALTH_CHECK_TIMEOUT=300  # seconds

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

# Check if running in the correct directory
check_prerequisites() {
    log_step "Checking prerequisites"

    if [ ! -f "compose.yaml" ]; then
        log_error "compose.yaml not found. Please run this script from the attack-workbench-deployment directory."
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Check MongoDB version before starting migration
check_initial_version() {
    log_step "Verifying initial MongoDB version"

    # Check if containers are running
    if ! docker compose ps database | grep -q "Up"; then
        log_error "MongoDB container is not running."
        log_error "Please start your ATT&CK Workbench deployment first:"
        log_error "  docker compose -f compose.yaml -f compose.dev.yaml up -d"
        exit 1
    fi

    # Check the current MongoDB version
    INITIAL_VERSION=$(mongo_exec "db.version()" 2>/dev/null | grep -oP '^\d+' || echo "unknown")

    if [ "$INITIAL_VERSION" = "unknown" ]; then
        log_error "Unable to determine current MongoDB version."
        log_error "Please ensure the database container is running and healthy."
        exit 1
    fi

    log_info "Current MongoDB version: $INITIAL_VERSION.x"

    # Validate version is within acceptable range
    if [ "$INITIAL_VERSION" -lt "5" ]; then
        echo ""
        log_error "════════════════════════════════════════════════════════"
        log_error "  Migration cannot proceed"
        log_error "════════════════════════════════════════════════════════"
        echo ""
        log_error "This script is designed to migrate from MongoDB 5, 6, or 7 to MongoDB 8."
        log_error "Your current MongoDB version is: $INITIAL_VERSION.x"
        echo ""
        log_warn "Your MongoDB version is older than version 5."
        log_warn "Please upgrade to MongoDB 5 first before using this script."
        echo ""
        log_error "Migration aborted."
        exit 1
    elif [ "$INITIAL_VERSION" -ge "8" ]; then
        echo ""
        log_error "════════════════════════════════════════════════════════"
        log_error "  Migration not needed"
        log_error "════════════════════════════════════════════════════════"
        echo ""
        log_info "Your current MongoDB version is: $INITIAL_VERSION.x"
        log_info "You are already running MongoDB 8 or newer - no migration needed!"
        echo ""
        exit 0
    fi

    # Inform user about the migration path
    case $INITIAL_VERSION in
        5)
            log_info "MongoDB version 5 detected - will migrate 5 → 6 → 7 → 8"
            ;;
        6)
            log_warn "MongoDB version 6 detected - will resume migration 6 → 7 → 8"
            log_warn "Skipping MongoDB 5 → 6 upgrade"
            ;;
        7)
            log_warn "MongoDB version 7 detected - will resume migration 7 → 8"
            log_warn "Skipping MongoDB 5 → 6 → 7 upgrades"
            ;;
    esac
}

# Wait for database to be healthy
wait_for_healthy() {
    log_info "Waiting for database to be healthy..."

    local elapsed=0
    while [ $elapsed -lt $HEALTH_CHECK_TIMEOUT ]; do
        if docker compose ps database | grep -q "healthy"; then
            log_info "Database is healthy!"
            return 0
        fi

        if docker compose ps database | grep -q "unhealthy"; then
            log_error "Database is unhealthy!"
            return 1
        fi

        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done

    echo ""
    log_error "Timeout waiting for database to become healthy"
    return 1
}

# Execute MongoDB command
mongo_exec() {
    docker exec $CONTAINER_NAME mongosh --eval "$1"
}

# Verify MongoDB version
verify_version() {
    local expected_version=$1
    local actual_version=$(mongo_exec "db.version()" | grep -oP '^\d+')

    if [ "$actual_version" = "$expected_version" ]; then
        local full_version=$(mongo_exec "db.version()" | head -1)
        log_info "MongoDB version verified: $full_version (major version $actual_version)"
        return 0
    else
        log_error "Version mismatch! Expected: $expected_version, Got: $actual_version"
        return 1
    fi
}

# Verify feature compatibility version
verify_fcv() {
    local expected_fcv=$1
    local result=$(mongo_exec "db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })")

    if echo "$result" | grep -q "version: '$expected_fcv'"; then
        log_info "Feature compatibility version verified: $expected_fcv"
        return 0
    else
        log_error "Feature compatibility version mismatch! Expected: $expected_fcv"
        echo "$result"
        return 1
    fi
}

# Update MongoDB image version in compose.yaml
update_compose_version() {
    local new_version=$1
    log_info "Updating compose.yaml to use mongo:$new_version"

    # Create backup of compose.yaml
    cp compose.yaml compose.yaml.backup

    # Update the image version - match both "mongo:X" and "mongo:X.Y" patterns
    sed -i "s|image: mongo:[0-9]\+\(\.[0-9]\+\)\?|image: mongo:$new_version|g" compose.yaml

    # Verify the change
    if grep -q "image: mongo:$new_version" compose.yaml; then
        log_info "compose.yaml updated successfully"
    else
        log_error "Failed to update compose.yaml"
        mv compose.yaml.backup compose.yaml
        return 1
    fi
}

# Step 0: Backup
backup_database() {
    log_step "Step 0: Creating backup"

    # Ensure the base backup directory exists
    docker exec $CONTAINER_NAME bash -c "mkdir -p /dump/$(basename $BACKUP_DIR)"

    # Timestamp and file paths
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="mongodb-backup-$TIMESTAMP.tar.gz"
    CONTAINER_BACKUP_PATH="/dump/migration-backup/$BACKUP_FILE"
    HOST_BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

    log_info "Locking database for backup..."
    mongo_exec "db.adminCommand({ fsync: 1, lock: true })"

    log_info "Creating backup inside container at $CONTAINER_BACKUP_PATH..."
    docker exec "$CONTAINER_NAME" bash -c "mkdir -p /dump/migration-backup && mongodump --gzip --archive=$CONTAINER_BACKUP_PATH"

    log_info "Unlocking database..."
    mongo_exec "db.fsyncUnlock()"

    if [ -f "$HOST_BACKUP_PATH" ]; then
        log_info "Backup successfully created: $HOST_BACKUP_PATH"
    else
        log_error "Backup creation failed — file not found on host!"
        exit 1
    fi
}

# Step 1: Set initial FCV to 5.0
set_initial_fcv() {
    log_step "Step 1: Setting featureCompatibilityVersion to 5.0"

    mongo_exec "db.adminCommand({ setFeatureCompatibilityVersion: '5.0' })"
    verify_fcv "5.0"
}

# Generic upgrade function
# Arguments: version (e.g., "6"), require_confirm ("true" or "false")
upgrade_mongodb() {
    local version=$1
    local require_confirm=$2
    local fcv="${version}.0"  # Automatically derive FCV (e.g., "6" -> "6.0")

    log_step "Upgrading to MongoDB $version"

    # Stop containers
    log_info "Stopping containers..."
    docker compose $COMPOSE_FILES down

    # Update compose.yaml
    update_compose_version "$version"

    # Start containers
    log_info "Starting containers with MongoDB $version..."
    docker compose $COMPOSE_FILES up -d --build

    # Wait for healthy status
    wait_for_healthy

    # Verify version
    verify_version "$version"

    # Set feature compatibility version
    log_info "Setting featureCompatibilityVersion to $fcv..."
    if [ "$require_confirm" = "true" ]; then
        mongo_exec "db.adminCommand({ setFeatureCompatibilityVersion: '$fcv', confirm: true })"
    else
        mongo_exec "db.adminCommand({ setFeatureCompatibilityVersion: '$fcv' })"
    fi

    # Verify FCV
    verify_fcv "$fcv"
}

# Final verification
verify_migration() {
    log_step "Verifying migration success"

    log_info "Checking MongoDB server status..."
    mongo_exec "db.serverStatus().version"

    log_info "Listing databases..."
    mongo_exec "db.adminCommand('listDatabases')"

    log_info "Checking document count in attack-workspace..."
    local doc_count=$(docker exec $CONTAINER_NAME mongosh attack-workspace --eval "db.attackObjects.countDocuments()" | tail -1)
    log_info "Found $doc_count attack objects"

    log_info "Checking all services..."
    docker compose ps

    log_info "Testing REST API health..."
    if curl -sf http://localhost:3000/api/health/ping > /dev/null 2>&1; then
        log_info "REST API is healthy!"
    else
        log_warn "REST API health check failed or not accessible"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   MongoDB Migration Script: 5/6/7 → 8                  ║"
    echo "║   ATT&CK Workbench Deployment                          ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    log_warn "This script will migrate your MongoDB instance to version 8.0"
    log_warn "Supports starting from MongoDB 5, 6, or 7"
    log_warn "Please ensure you have reviewed MIGRATION.md before proceeding"
    echo ""
    read -p "Do you want to continue? [y/N]: " -r
    echo ""

    # Convert to lowercase for comparison
    REPLY=$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')

    # Default to "no" if empty (user just hit enter)
    if [[ -z "$REPLY" ]]; then
        REPLY="n"
    fi

    # Accept y, yes for confirmation
    if [[ "$REPLY" =~ ^(y|yes)$ ]]; then
        log_info "Proceeding with migration..."
    else
        log_info "Migration cancelled by user"
        exit 0
    fi

    # Execute migration steps
    check_prerequisites
    check_initial_version
    backup_database

    # Set initial FCV only if starting from version 5
    if [ "$INITIAL_VERSION" = "5" ]; then
        set_initial_fcv
    else
        log_info "Skipping initial FCV setup (already on version $INITIAL_VERSION)"
    fi

    # Upgrade to 6 (if needed)
    if [ "$INITIAL_VERSION" -le "5" ]; then
        upgrade_mongodb "6" "false"
    else
        log_info "Skipping MongoDB 5 → 6 upgrade (already on version $INITIAL_VERSION)"
    fi

    # Upgrade to 7 (if needed, requires confirm)
    if [ "$INITIAL_VERSION" -le "6" ]; then
        upgrade_mongodb "7" "true"
    else
        log_info "Skipping MongoDB 6 → 7 upgrade (already on version $INITIAL_VERSION)"
    fi

    # Upgrade to 8 (always run if we got this far, requires confirm)
    if [ "$INITIAL_VERSION" -le "7" ]; then
        upgrade_mongodb "8" "true"
    else
        log_info "Already on MongoDB 8 - no upgrade needed"
    fi

    # Final verification
    verify_migration

    # Cleanup backup of compose.yaml
    if [ -f "compose.yaml.backup" ]; then
        rm compose.yaml.backup
    fi

    log_step "Migration Complete!"
    log_info "Your ATT&CK Workbench instance is now running on MongoDB 8.0"
    log_info "compose.yaml has been updated to use mongo:8"
    log_info "Backup location: $BACKUP_DIR"
    echo ""
}

# Run main function
main
