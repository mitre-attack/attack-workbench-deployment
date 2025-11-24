#!/usr/bin/env bash

usage() {
  echo "Usage: $(basename "$0") [--instance-name <name>] [-h|--help]"
  echo
  echo "Options:"
  echo "  --accept-defaults       Run non-interactively using default selections"
  echo "  --dev-mode              Setup in developer mode (build from source)"
  echo "  --instance-name <name>  Name of the generated configuration"
  echo "  -h, --help              Show this help and exit"
  echo "  --taxi-server           Deploy with the TAXII server"

}

# Parse optional CLI arguments
ACCEPT_DEFAULTS=false
AUTO_ENABLE_TAXII=false
AUTO_DEV_MODE=false
AUTO_INSTANCE_NAME=""
AUTO_DATABASE_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --accept-defaults)
      ACCEPT_DEFAULTS=true
      shift
      ;;
    --dev-mode)
      AUTO_DEV_MODE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --instance-name)
      if [[ $# -lt 2 || "${2:-}" == -* ]]; then
        echo "Error: --instance-name requires a value." >&2
        echo ""
        usage
        exit 1
      fi
      AUTO_INSTANCE_NAME="$2"
      shift 2
      ;;
    --instance-name=*)
      AUTO_INSTANCE_NAME="${1#*=}"
      if [[ -z "$AUTO_INSTANCE_NAME" ]]; then
        echo "Error: --instance-name requires a value." >&2
        echo ""
        usage
        exit 1
      fi
      shift
      ;;
    --mongodb-connection)
      if [[ $# -lt 2 || "${2:-}" == -* ]]; then
        echo "Error: --mongodb-connection requires a value." >&2
        echo ""
        usage
        exit 1
      fi
      AUTO_DATABASE_URL="$2"
      shift 2
      ;;
    --mongodb-connection=*)
      AUTO_DATABASE_URL="${1#*=}"
      if [[ -z "$AUTO_DATABASE_URL" ]]; then
        echo "Error: --mongodb-connection requires a value." >&2
        echo ""
        usage
        exit 1
      fi
      shift
      ;;
    --taxii-server)
      AUTO_ENABLE_TAXII=true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      echo ""
      usage
      exit 1
      ;;
  esac
done

# ATT&CK Workbench Deployment Setup Script
# This script helps you quickly set up a custom ATT&CK Workbench instance
#
# SCRIPT ORGANIZATION:
#   1. Constants and Configuration
#   2. Color and Output Functions
#   3. Validation Functions
#   4. Helper Functions (prompts, file operations)
#   5. Instance Management Functions
#   6. Configuration Functions (database, environment, certificates)
#   7. Deployment Option Functions (TAXII, dev mode)
#   8. Compose Override Generation Functions
#   9. Output Functions (summary, instructions)
#  10. Main Execution Flow

#===============================================================================
# CONSTANTS
#===============================================================================

readonly DEPLOYMENT_REPO_URL="https://github.com/mitre-attack/attack-workbench-deployment.git"
readonly CTID_GITHUB_ORG="https://github.com/center-for-threat-informed-defense"
readonly MITRE_GITHUB_ORG="https://github.com/mitre-attack"

readonly REPO_FRONTEND="attack-workbench-frontend"
readonly REPO_REST_API="attack-workbench-rest-api"
readonly REPO_TAXII="attack-workbench-taxii-server"

readonly DB_URL_DOCKER="mongodb://mongodb/attack-workspace"
readonly DB_URL_LOCAL="mongodb://localhost:27017/attack-workspace"

#===============================================================================
# COLORS & OUTPUT FUNCTIONS
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
warning() { echo -e "${YELLOW}$1${NC}"; }
error() { echo -e "${RED}$1${NC}"; }

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

# Validate that a required command is available
# Usage: require_command "git" "Please install git"
require_command() {
    local command="$1"
    local message="$2"

    if ! command -v "$command" &> /dev/null; then
        error "$command is not installed or not in PATH"
        if [[ -n "$message" ]]; then
            echo "  $message"
        fi
        return 1
    fi
    return 0
}

# Validate that a file exists
# Usage: require_file "/path/to/file" "File description"
require_file() {
    local file_path="$1"
    local description="$2"

    if [[ ! -f "$file_path" ]]; then
        error "${description:-File} not found: $file_path"
        return 1
    fi
    return 0
}

# Validate that a directory exists
# Usage: require_directory "/path/to/dir" "Directory description"
require_directory() {
    local dir_path="$1"
    local description="$2"

    if [[ ! -d "$dir_path" ]]; then
        error "${description:-Directory} not found: $dir_path"
        return 1
    fi
    return 0
}

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

# Prompt for yes/no answer with validation
# Usage: prompt_yes_no "Question?" "Y"
# Args: $1=question, $2=default (Y/N)
prompt_yes_no() {
    # If defaults are automatically accepted, use the provided default and skip prompting
    if $ACCEPT_DEFAULTS; then
        PROMPT_YES_NO_RESULT="${2:-N}"
        return
    fi

    local question="$1"
    local default="$2"
    PROMPT_YES_NO_RESULT=""

    while true; do
        read -p "$question [y/N] " -r answer
        answer=${answer:-$default}

        if [[ $answer =~ ^[YyNn]$ ]]; then
            PROMPT_YES_NO_RESULT="$answer"
            break
        else
            error "Invalid option. Please enter 'y' for yes or 'n' for no."
        fi
    done
}

# Prompt for menu selection with validation
# Usage: prompt_menu "default_index" "option1" "option2" "option3"
# Args: $1=default index (1-based), remaining args are menu options
prompt_menu() {
    # If defaults are automatically accepted, use the default index and skip prompting
    if $ACCEPT_DEFAULTS; then
        PROMPT_MENU_RESULT="${1}"
        return
    fi

    local default_index="$1"
    shift
    local -a options=("$@")
    local num_options=${#options[@]}

    PROMPT_MENU_RESULT=""
    while true; do
        for i in "${!options[@]}"; do
            echo "$((i + 1))) ${options[$i]}"
        done
        echo ""
        read -p "Select option 1-$num_options: [1] " -r choice
        choice=${choice:-$default_index}

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$num_options" ]; then
            PROMPT_MENU_RESULT="$choice"
            break
        else
            error "Invalid option. Please select 1-$num_options."
            echo ""
        fi
    done

    echo ""
}

# Prompt for non-empty string with validation
# Usage: prompt_non_empty "Question"
prompt_non_empty() {
    local question="$1"
    PROMPT_NON_EMPTY_RESULT=""

    while true; do
        read -p "$question " PROMPT_NON_EMPTY_RESULT
        if [[ -n "$PROMPT_NON_EMPTY_RESULT" ]]; then
            break
        else
            error "Input cannot be empty"
        fi
    done
}

# Update or add a key=value in an env file
# Usage: update_env_file "/path/to/.env" "KEY" "value"
update_env_file() {
    local env_file="$1"
    local key="$2"
    local value="$3"

    if grep -q "^${key}=" "$env_file"; then
        local tmp
        tmp="$(mktemp /tmp/env.XXXXXX)"
        sed "s|^${key}=.*|${key}=${value}|" "$env_file" > "$tmp" && mv "$tmp" "$env_file"
    elif grep -q "^#${key}=" "$env_file"; then
        local tmp
        tmp="$(mktemp /tmp/env.XXXXXX)"
        sed "s|^#${key}=.*|${key}=${value}|" "$env_file" > "$tmp" && mv "$tmp" "$env_file"
    else
        echo "${key}=${value}" >> "$env_file"
    fi
}

# Check if a repository exists in parent directory
# Usage: check_repo_exists "/parent/dir" "repo-name"
check_repo_exists() {
    local parent_dir="$1"
    local repo_name="$2"

    [[ -d "$parent_dir/$repo_name" ]]
}

# Get GitHub URL for a repository
# Usage: get_repo_url "repo-name"
get_repo_url() {
    local repo_name="$1"

    if [[ "$repo_name" == "$REPO_TAXII" ]]; then
        echo "$MITRE_GITHUB_ORG/$repo_name.git"
    else
        echo "$CTID_GITHUB_ORG/$repo_name.git"
    fi
}

#===============================================================================
# INSTANCE MANAGEMENT FUNCTIONS
#===============================================================================

# Prompt for and validate instance name
get_instance_name() {
    local default_instance_name="my-workbench"

    # If instance name was provided via cli, use the cli value and skip prompting
    if [[ -n "${AUTO_INSTANCE_NAME-}" ]]; then
        GET_INSTANCE_NAME_NAME_REF="${AUTO_INSTANCE_NAME}"
        return
    fi

    # If defaults are automatically accepted, use the default name and skip prompting
    if $ACCEPT_DEFAULTS; then
        GET_INSTANCE_NAME_NAME_REF="${default_instance_name}"
        return
    fi

    read -p "Enter instance name [my-workbench]: " GET_INSTANCE_NAME_NAME_REF
    GET_INSTANCE_NAME_NAME_REF=${GET_INSTANCE_NAME_NAME_REF:-$default_instance_name}

    # Validate instance name
    if [[ ! "$GET_INSTANCE_NAME_NAME_REF" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Instance name can only contain letters, numbers, hyphens, and underscores"
        exit 1
    fi
}

# Check if instance exists and handle overwrite
handle_existing_instance() {
    local instance_dir="$1"
    local instance_name="$2"

    if [[ ! -d "$instance_dir" ]]; then
        return 0
    fi

    warning "Instance '$instance_name' already exists at $instance_dir"
    echo ""

    prompt_yes_no "Would you like to overwrite it?" "N"
    local overwrite="$PROMPT_YES_NO_RESULT"

    if [[ ! $overwrite =~ ^[Yy]$ ]]; then
        error "Aborted"
        exit 1
    fi

    warning "Removing existing instance directory..."
    rm -rf "$instance_dir"
    echo ""
}

# Create instance directory and copy template files
create_instance() {
    local instance_dir="$1"
    local deployment_dir="$2"
    local source_dir="$deployment_dir/docker/example-setup"

    info "Creating instance directory: $instance_dir"
    echo ""
    mkdir -p "$instance_dir"

    info "Copying template files..."
    # Copy all files except compose templates (they're handled by this script)
    find "$source_dir" -maxdepth 1 \
        ! -name "compose.dev.yaml" \
        ! -name "compose.certs.yaml" \
        ! -name "compose.taxii.yaml" \
        ! -path "$source_dir" \
        -exec cp -r {} "$instance_dir/" \;
    success "Template files copied"
    echo ""
}

#===============================================================================
# CONFIGURATION FUNCTIONS
#===============================================================================

# Configure database connection and return the selected DATABASE_URL
configure_database() {
    CONFIGURE_DATABASE_DB_URL_REF=""

    # echo ""
    info "Configure MongoDB connection:"
    echo ""

    # If instance name was provided via cli, use the cli value and skip prompting
    if [[ -n "${AUTO_DATABASE_URL-}" ]]; then
        CONFIGURE_DATABASE_DB_URL_REF="${AUTO_DATABASE_URL}"
        info "Using custom connection: $CONFIGURE_DATABASE_DB_URL_REF"
        return
    fi

    prompt_menu 1 \
        "Docker setup ($DB_URL_DOCKER)" \
        "Local MongoDB ($DB_URL_LOCAL)" \
        "Custom connection string"
    local db_choice="$PROMPT_MENU_RESULT"

    case $db_choice in
        1)
            CONFIGURE_DATABASE_DB_URL_REF="$DB_URL_DOCKER"
            info "Using Docker setup: $CONFIGURE_DATABASE_DB_URL_REF"
            ;;
        2)
            CONFIGURE_DATABASE_DB_URL_REF="$DB_URL_LOCAL"
            info "Using local MongoDB: $CONFIGURE_DATABASE_DB_URL_REF"
            ;;
        3)
            echo ""
            prompt_non_empty "Enter MongoDB connection string:"
            CONFIGURE_DATABASE_DB_URL_REF="$PROMPT_NON_EMPTY_RESULT"
            info "Using custom connection: $CONFIGURE_DATABASE_DB_URL_REF"
            ;;
    esac
    echo ""
}

# Set up all environment files for the instance
setup_environment_files() {
    local database_url="$1"

    info "Setting up environment files..."

    # Main .env file
    if [[ -f "$INSTANCE_DIR/template.env" ]]; then
        mv "$INSTANCE_DIR/template.env" "$INSTANCE_DIR/.env"
        success "Created $INSTANCE_DIR/.env"
    fi

    # REST API .env file
    if [[ -f "$INSTANCE_DIR/configs/rest-api/template.env" ]]; then
        local rest_api_env="$INSTANCE_DIR/configs/rest-api/.env"
        mv "$INSTANCE_DIR/configs/rest-api/template.env" "$rest_api_env"
        update_env_file "$rest_api_env" "DATABASE_URL" "$database_url"
        success "Created $rest_api_env with DATABASE_URL configured"
    fi

    # TAXII .env file (optional)
    if [[ -f "$INSTANCE_DIR/configs/taxii/config/template.env" ]]; then
        mv "$INSTANCE_DIR/configs/taxii/config/template.env" "$INSTANCE_DIR/configs/taxii/config/dev.env"
        success "Created $INSTANCE_DIR/configs/taxii/config/dev.env"
    fi
    
    echo ""
}

# Configure custom SSL certificates for REST API
configure_custom_certificates() {
    CONFIGURE_CUSTOM_CERTIFICATES_HOST_CERTS_REF=""
    CONFIGURE_CUSTOM_CERTIFICATES_CERTS_FILENAME_REF=""

    # echo ""
    info "Custom SSL certificates allow the REST API to trust additional CA certificates."
    info "This is useful when behind a firewall that performs SSL inspection."
    echo ""

    read -p "Enter host certificates path [./certs]: " user_certs_path
    CONFIGURE_CUSTOM_CERTIFICATES_HOST_CERTS_REF=${user_certs_path:-./certs}

    read -p "Enter certificate filename [custom-certs.pem]: " user_certs_filename
    CONFIGURE_CUSTOM_CERTIFICATES_CERTS_FILENAME_REF=${user_certs_filename:-custom-certs.pem}

    echo ""
    info "Using certificates from: $CONFIGURE_CUSTOM_CERTIFICATES_HOST_CERTS_REF/$CONFIGURE_CUSTOM_CERTIFICATES_CERTS_FILENAME_REF"
    # echo ""

    # Add custom cert configuration to .env
    local env_file="$INSTANCE_DIR/.env"
    update_env_file "$env_file" "HOST_CERTS_PATH" "$CONFIGURE_CUSTOM_CERTIFICATES_HOST_CERTS_REF"
    update_env_file "$env_file" "CERTS_FILENAME" "$CONFIGURE_CUSTOM_CERTIFICATES_CERTS_FILENAME_REF"
    success "Added certificate configuration to $env_file"
    echo ""
}

#===============================================================================
# DEPLOYMENT OPTION FUNCTIONS
#===============================================================================

# Add TAXII service to compose.yaml by inserting before the volumes section
add_taxii_to_compose() {
    local compose_file="$INSTANCE_DIR/compose.yaml"
    local taxii_template="$DEPLOYMENT_DIR/docker/example-setup/compose.taxii.yaml"
    local temp_file="$INSTANCE_DIR/compose.yaml.tmp"

    info "Adding TAXII server to compose.yaml..."

    # Insert TAXII service before the "volumes:" section
    sed '/^volumes:/,$d' "$compose_file" > "$temp_file"
    # Extract only the service definition, skipping the "services:" header
    sed -n '/^services:/,${/^services:/!p;}' "$taxii_template" >> "$temp_file"
    echo "" >> "$temp_file"
    sed -n '/^volumes:/,$p' "$compose_file" >> "$temp_file"
    mv "$temp_file" "$compose_file"

    success "TAXII server added to compose.yaml"
    echo ""
}

# Verify all required source repositories exist for developer mode
verify_dev_mode_repos() {
    local parent_dir="$1"
    local enable_taxii="$2"
    local -a missing_repos=()

    if ! check_repo_exists "$parent_dir" "$REPO_FRONTEND"; then
        missing_repos+=("$REPO_FRONTEND")
    fi

    if ! check_repo_exists "$parent_dir" "$REPO_REST_API"; then
        missing_repos+=("$REPO_REST_API")
    fi

    if [[ $enable_taxii =~ ^[Yy]$ ]] && ! check_repo_exists "$parent_dir" "$REPO_TAXII"; then
        missing_repos+=("$REPO_TAXII")
    fi

    if [[ ${#missing_repos[@]} -gt 0 ]]; then
        warning "Missing required repositories:"
        for repo in "${missing_repos[@]}"; do
            echo "  - $repo"
        done
        echo ""
        warning "Please clone the missing repositories to:"
        echo "  $parent_dir/"
        echo ""
        echo "Clone commands:"
        for repo in "${missing_repos[@]}"; do
            echo "  git clone $(get_repo_url "$repo") $parent_dir/$repo"
        done
    else
        success "All required repositories found!"
    fi
    echo ""
}

# Display expected directory structure for developer mode
show_dev_mode_structure() {
    local deployment_dir="$1"
    local enable_taxii="$2"

    # echo ""
    info "Developer mode requires source repositories to be cloned as siblings to the deployment repository."
    echo ""
    echo "Expected directory structure:"
    echo "  $(dirname "$deployment_dir")/"
    echo "    ├── attack-workbench-deployment/"
    echo "    ├── $REPO_FRONTEND/"
    echo "    ├── $REPO_REST_API/"
    if [[ $enable_taxii =~ ^[Yy]$ ]]; then
        echo "    └── $REPO_TAXII/"
    fi
    echo ""
}

#===============================================================================
# COMPOSE OVERRIDE GENERATION FUNCTIONS
#===============================================================================

# Generate the frontend service override configuration for dev mode
generate_frontend_override() {
    cat << EOF

  frontend:
    image: $REPO_FRONTEND
    build: ../../../$REPO_FRONTEND
    develop:
      watch:
        # Sync source files for hot-reload
        - action: sync
          path: ../../../$REPO_FRONTEND/src
          target: /app/src
          ignore:
            - node_modules/
        # Rebuild on package.json changes
        - action: rebuild
          path: ../../../$REPO_FRONTEND/package.json
EOF
}

# Generate the rest-api service override configuration for dev mode
generate_rest_api_dev_override() {
    cat << EOF

  rest-api:
    image: $REPO_REST_API
    build: ../../../$REPO_REST_API
EOF

    # Add custom cert volumes if enabled
    if [[ $ENABLE_CUSTOM_CERTS =~ ^[Yy]$ ]]; then
        cat << 'EOF'
    volumes:
      - ${HOST_CERTS_PATH:-./certs}:/usr/src/app/certs
    environment:
      - NODE_EXTRA_CA_CERTS=./certs/${CERTS_FILENAME:-custom-certs.pem}
EOF
    fi

    # Add develop watch configuration
    cat << EOF
    develop:
      watch:
        # Sync app source files
        - action: sync
          path: ../../../$REPO_REST_API/app
          target: /usr/src/app/app
          ignore:
            - node_modules/
        # Restart on config changes
        - action: sync+restart
          path: ../../../$REPO_REST_API/resources
          target: /usr/src/app/resources
        # Rebuild on package.json changes
        - action: rebuild
          path: ../../../$REPO_REST_API/package.json
EOF
}

# Generate the rest-api service override for production mode with custom certs
generate_rest_api_certs_override() {
    cat << 'EOF'

  rest-api:
    volumes:
      - ${HOST_CERTS_PATH:-./certs}:/usr/src/app/certs
    environment:
      - NODE_EXTRA_CA_CERTS=./certs/${CERTS_FILENAME:-custom-certs.pem}
EOF
}

# Generate the TAXII service override configuration for dev mode
generate_taxii_override() {
    cat << EOF

  taxii:
    image: $REPO_TAXII
    build: ../../../$REPO_TAXII
    develop:
      watch:
        # Sync source files
        - action: sync
          path: ../../../$REPO_TAXII/taxii
          target: /app/taxii
          ignore:
            - node_modules/
        # Sync config files and restart
        - action: sync+restart
          path: ../../../$REPO_TAXII/config
          target: /app/config
        # Rebuild on package.json changes
        - action: rebuild
          path: ../../../$REPO_TAXII/package.json
EOF
}

# Generate the complete compose.override.yaml file
generate_compose_override() {
    local override_file="$1"

    # Write header
    cat > "$override_file" << 'EOF'
# This file was generated by setup-workbench.sh
# It will be automatically merged with compose.yaml when running docker compose commands

services:
EOF

    # Add service configurations based on mode
    if [[ $DEV_MODE =~ ^[Yy]$ ]]; then
        generate_frontend_override >> "$override_file"
        generate_rest_api_dev_override >> "$override_file"

        if [[ $ENABLE_TAXII =~ ^[Yy]$ ]]; then
            generate_taxii_override >> "$override_file"
        fi
    else
        # Production mode - only add rest-api if custom certs are enabled
        if [[ $ENABLE_CUSTOM_CERTS =~ ^[Yy]$ ]]; then
            generate_rest_api_certs_override >> "$override_file"
        fi
    fi

    # Add newline at end
    echo "" >> "$override_file"
}

#===============================================================================
# OUTPUT FUNCTIONS
#===============================================================================

# Display configuration summary
show_configuration_summary() {
    local instance_dir="$1"
    local override_file="$2"
    local dev_mode="$3"
    local enable_taxii="$4"
    local enable_custom_certs="$5"

    info "Configuration files:"
    echo "  Main:       $instance_dir/.env"
    echo "  Compose:    $instance_dir/compose.yaml"
    if [[ $dev_mode =~ ^[Yy]$ ]] || [[ $enable_custom_certs =~ ^[Yy]$ ]]; then
        echo "  + Override: $override_file"
    fi
    echo "  REST API:   $instance_dir/configs/rest-api/.env"
    echo "  REST API:   $instance_dir/configs/rest-api/rest-api-service-config.json"
    if [[ $enable_taxii =~ ^[Yy]$ ]]; then
        echo "  TAXII:      $instance_dir/configs/taxii/config/.env"
    fi
    echo ""
}

# Display custom SSL certificate information
show_certificate_info() {
    local instance_dir="$1"
    local host_certs_path="$2"
    local certs_filename="$3"

    info "Custom SSL certificates:"
    echo "  Path:     $host_certs_path"
    echo "  Filename: $certs_filename"
    echo ""
    warning "Make sure to place your certificate file at:"
    if [[ "$host_certs_path" = ./* ]] || [[ "$host_certs_path" = ../* ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        echo "  $instance_dir/$host_certs_path/$certs_filename"
    else
        echo "  $host_certs_path/$certs_filename"
    fi
    echo ""
}

# Display deployment instructions
show_deployment_instructions() {
    local instance_dir="$1"
    local deployment_dir="$2"
    local dev_mode="$3"

    info "To deploy your instance:"
    echo "  cd $instance_dir"
    if [[ $dev_mode =~ ^[Yy]$ ]]; then
        echo "  docker compose up -d --build"
        echo ""
        info "For hot-reloading in developer mode, use watch:"
        echo "  docker compose watch"
    else
        echo "  docker compose up -d"
    fi
    echo ""

    info "After deployment, access your Workbench at:"
    echo "  http://localhost"
    echo ""

    info "For more information, see:"
    echo "  Configuration: $deployment_dir/docs/configuration.md"
    echo "  Deployment:    $deployment_dir/docs/deployment.md"
    echo ""
}

#===============================================================================
# BANNER
#===============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   ATT&CK Workbench Deployment Setup                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

#===============================================================================
# LOCATE DEPLOYMENT REPOSITORY
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR=""

# Check if we're already in the deployment repo
if [[ -f "$SCRIPT_DIR/example-setup/compose.yaml" ]]; then
    DEPLOYMENT_DIR="$(dirname $SCRIPT_DIR)"
    info "Running from deployment repository: $DEPLOYMENT_DIR"
elif [[ -d "$SCRIPT_DIR/attack-workbench-deployment" ]]; then
    DEPLOYMENT_DIR="$SCRIPT_DIR/attack-workbench-deployment"
    info "Found deployment repository: $DEPLOYMENT_DIR"
elif [[ -f "./docker/example-setup/compose.yaml" ]]; then
    DEPLOYMENT_DIR="$(pwd)"
    info "Running from current directory: $DEPLOYMENT_DIR"
else
    # Not in the repo - need to clone or find it
    warning "Not in the attack-workbench-deployment repository"

    # Check if git is available
    if ! command -v git &> /dev/null; then
        error "Git is not installed. Please install git or manually clone the repository."
        exit 1
    fi

    echo ""
    prompt_yes_no "Would you like to clone the repository?" "Y"
    CLONE_REPO="$PROMPT_YES_NO_RESULT"

    if [[ $CLONE_REPO =~ ^[Yy]$ ]]; then
        info "Cloning repository from $DEPLOYMENT_REPO_URL..."

        CLONE_DIR="./attack-workbench-deployment"
        if [[ -d "$CLONE_DIR" ]]; then
            error "Directory $CLONE_DIR already exists"
            exit 1
        fi

        git clone "$DEPLOYMENT_REPO_URL" "$CLONE_DIR"
        DEPLOYMENT_DIR="$(cd "$CLONE_DIR" && pwd)"
        success "Repository cloned to $DEPLOYMENT_DIR"
    else
        error "Cannot proceed without the deployment repository"
        exit 1
    fi
fi
echo ""

cd "$DEPLOYMENT_DIR"

#===============================================================================
# PREREQUISITE CHECKS
#===============================================================================

# Check for Docker (warn but don't fail - user might not deploy immediately)
if ! require_command "docker" "Please install Docker to deploy the Workbench. Visit: https://docs.docker.com/get-docker/"; then
    warning "Docker is not installed - you will need it to deploy the Workbench"
fi

# Check for Docker Compose (warn but don't fail)
if ! docker compose version &> /dev/null 2>&1; then
    warning "Docker Compose is not available"
    echo "  Please install Docker Compose (usually included with Docker Desktop)"
fi


#===============================================================================
# MAIN EXECUTION FLOW
#===============================================================================

#---------------------------------------
# Instance Setup
#---------------------------------------

# echo ""
info "Setting up your Workbench instance..."
echo ""

get_instance_name
INSTANCE_NAME="$GET_INSTANCE_NAME_NAME_REF"
INSTANCE_DIR="$DEPLOYMENT_DIR/instances/$INSTANCE_NAME"

handle_existing_instance "$INSTANCE_DIR" "$INSTANCE_NAME"
create_instance "$INSTANCE_DIR" "$DEPLOYMENT_DIR"

#---------------------------------------
# Deployment Options
#---------------------------------------

# echo ""
info "Configuring deployment options..."
echo ""

if $AUTO_ENABLE_TAXII; then
    ENABLE_TAXII="y"
else
    prompt_yes_no "Do you want to deploy with the TAXII server?" "N"
    ENABLE_TAXII="$PROMPT_YES_NO_RESULT"
    echo ""
fi

if [[ ! $ENABLE_TAXII =~ ^[Yy]$ ]]; then
    # Remove TAXII configs if not needed
    if [[ -d "$INSTANCE_DIR/configs/taxii" ]]; then
        rm -rf "$INSTANCE_DIR/configs/taxii"
    fi
fi

#---------------------------------------
# Environment Configuration
#---------------------------------------

configure_database
DATABASE_URL="$CONFIGURE_DATABASE_DB_URL_REF"
setup_environment_files "$DATABASE_URL"

if [[ $ENABLE_TAXII =~ ^[Yy]$ ]]; then
    add_taxii_to_compose
fi

# echo ""
success "Instance '$INSTANCE_NAME' created successfully!"
echo ""

#---------------------------------------
# Additional Options
#---------------------------------------

if $AUTO_DEV_MODE; then
    DEV_MODE="y"
else
    prompt_yes_no "Do you want to set up in developer mode (build from source)?" "N"
    DEV_MODE="$PROMPT_YES_NO_RESULT"
fi

prompt_yes_no "Do you want to configure custom SSL certificates for the REST API?" "N"
ENABLE_CUSTOM_CERTS="$PROMPT_YES_NO_RESULT"

HOST_CERTS_PATH="./certs"
CERTS_FILENAME="custom-certs.pem"

echo ""
if [[ $ENABLE_CUSTOM_CERTS =~ ^[Yy]$ ]]; then
    configure_custom_certificates
    HOST_CERTS_PATH="$CONFIGURE_CUSTOM_CERTIFICATES_HOST_CERTS_REF"
    CERTS_FILENAME="$CONFIGURE_CUSTOM_CERTIFICATES_CERTS_FILENAME_REF"
fi

#---------------------------------------
# Developer Mode Setup
#---------------------------------------

if [[ $DEV_MODE =~ ^[Yy]$ ]]; then
    show_dev_mode_structure "$DEPLOYMENT_DIR" "$ENABLE_TAXII"
    PARENT_DIR="$(dirname "$DEPLOYMENT_DIR")"
    verify_dev_mode_repos "$PARENT_DIR" "$ENABLE_TAXII"
fi

#---------------------------------------
# Generate Compose Override
#---------------------------------------

OVERRIDE_FILE="$INSTANCE_DIR/compose.override.yaml"

if [[ $DEV_MODE =~ ^[Yy]$ ]] || [[ $ENABLE_CUSTOM_CERTS =~ ^[Yy]$ ]]; then
    info "Generating compose.override.yaml..."
    generate_compose_override "$OVERRIDE_FILE"
    success "Created $OVERRIDE_FILE"
    echo ""
fi

#---------------------------------------
# Summary
#---------------------------------------

show_configuration_summary "$INSTANCE_DIR" "$OVERRIDE_FILE" "$DEV_MODE" "$ENABLE_TAXII" "$ENABLE_CUSTOM_CERTS"

if [[ $ENABLE_CUSTOM_CERTS =~ ^[Yy]$ ]]; then
    show_certificate_info "$INSTANCE_DIR" "$HOST_CERTS_PATH" "$CERTS_FILENAME"
fi

show_deployment_instructions "$INSTANCE_DIR" "$DEPLOYMENT_DIR" "$DEV_MODE"
