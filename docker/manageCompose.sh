
#!/usr/bin/env bash

set -Eeuo pipefail

# ==================================================
# Docker Worker Manager
# ==================================================

# --------------------------------------------------
# Configuration and paths
# --------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Convert paths for Windows-native applications.
# cygpath -m produces Windows paths with forward slashes.
to_native_path() {
    if [[ "$(uname -s)" == CYGWIN* ]]; then
        cygpath -m "$1"
    else
        printf '%s\n' "$1"
    fi
}

# Keep POSIX paths for Bash and Cygwin-native tools.
COMPOSE_FILE_POSIX="${SCRIPT_DIR}/docker-compose.yml"
CONFIG_XML_POSIX="${SCRIPT_DIR}/../src/repo/config.xml"
BUILD_SCRIPT="${SCRIPT_DIR}/../scripts/buildWorker.sh"

# Native paths for Windows executables (yq and Docker).
COMPOSE_FILE="$(to_native_path "$COMPOSE_FILE_POSIX")"

# --------------------------------------------------
# Prerequisite checks
# --------------------------------------------------
# Docker Compose initialization
# --------------------------------------------------

COMPOSE_TEMPLATE="${SCRIPT_DIR}/docker-compose.yml.template"
COMPOSE_FILE_POSIX="${SCRIPT_DIR}/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE_POSIX" ]]; then

    if [[ ! -f "$COMPOSE_TEMPLATE" ]]; then
        echo "ERROR: Neither docker-compose.yml nor docker-compose.yml.template exists."
        exit 1
    fi

    echo "docker-compose.yml not found."
    echo "Creating it from docker-compose.yml.template..."

    cp -p "$COMPOSE_TEMPLATE" "$COMPOSE_FILE_POSIX"

    echo "docker-compose.yml successfully created."

fi

check_requirements() {

    for cmd in yq svn docker xmlstarlet; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "ERROR: Required command '$cmd' not found."
            exit 1
        fi
    done

    if [[ "$(uname -s)" == CYGWIN* ]] &&
       ! command -v cygpath >/dev/null 2>&1; then
        echo "ERROR: cygpath not found."
        exit 1
    fi

    if ! yq --version 2>&1 | grep -q 'version v4'; then
        echo "ERROR: Mike Farah yq v4 is required."
        exit 1
    fi

    if [[ ! -r "$COMPOSE_FILE_POSIX" ]]; then
        echo "ERROR: Cannot read $COMPOSE_FILE_POSIX"
        exit 1
    fi

    if [[ ! -r "$CONFIG_XML_POSIX" ]]; then
        echo "ERROR: Cannot read $CONFIG_XML_POSIX"
        exit 1
    fi

    if [[ ! -x "$BUILD_SCRIPT" ]]; then
        echo "ERROR: buildWorker.sh is not executable."
        exit 1
    fi

    if ! xmlstarlet val "$CONFIG_XML_POSIX" >/dev/null 2>&1; then
        echo "ERROR: config.xml is not valid XML."
        exit 1
    fi

    if ! docker compose -f "$COMPOSE_FILE" config -q; then
        echo "ERROR: Invalid docker-compose.yml."
        exit 1
    fi
}

# --------------------------------------------------
# Backup configuration files
# --------------------------------------------------

backup_file() {

    local file="$1"
    local backup="${file}.$(date +%Y%m%d_%H%M%S).bak"

    cp -p "$file" "$backup"

    echo "Backup created: $backup"
}

# --------------------------------------------------
# Restore configuration files
# --------------------------------------------------

restore_configurations() {

    local compose_backup="$1"
    local xml_backup="$2"

    echo "Restoring configuration files..."

    cp -p "$compose_backup" "$COMPOSE_FILE_POSIX"
    cp -p "$xml_backup" "$CONFIG_XML_POSIX"

    echo "Configuration files restored."
}

# --------------------------------------------------
# Validate configurations
# --------------------------------------------------

validate_configurations() {

    if ! docker compose -f "$COMPOSE_FILE" config -q; then
        echo "ERROR: Invalid Docker Compose configuration."
        return 1
    fi

    if ! xmlstarlet val "$CONFIG_XML_POSIX"; then
        echo "ERROR: Invalid XML configuration."
        return 1
    fi

    return 0
}

# --------------------------------------------------
# List workers
# --------------------------------------------------

list_workers() {

    echo
    echo "========== Existing workers =========="
    printf "%-12s %-15s %-35s %-20s\n" \
        "SERVICE" "WORKER ID" "IMAGE" "CONTAINER"

    local found=0
    local service image container workerid

    while IFS= read -r service; do

        [[ -z "$service" ]] && continue

        found=1

        image=$(yq -r \
            ".services.${service}.image // \"unknown\"" \
            "$COMPOSE_FILE")

        container=$(yq -r \
            ".services.${service}.container_name // \"unknown\"" \
            "$COMPOSE_FILE")

        workerid=$(yq -r \
            ".services.${service}.labels.\"worker-manager.worker-id\" // \"(legacy)\"" \
            "$COMPOSE_FILE")

        printf "%-12s %-15s %-35s %-20s\n" \
            "$service" "$workerid" "$image" "$container"

    done < <(
        yq -r '.services | keys | .[] |
            select(test("^worker[0-9]+$"))' "$COMPOSE_FILE"
    )

    if [[ "$found" -eq 0 ]]; then
        echo "No workers found."
    fi

    echo
}

# --------------------------------------------------
# Find next available Compose service name
# --------------------------------------------------

next_worker_service() {

    local number=1
    local services

    services=$(yq -r '.services | keys | .[]' "$COMPOSE_FILE")

    while grep -Fxq "worker${number}" <<< "$services"; do
        ((number+=1))
    done

    echo "worker${number}"
}

# --------------------------------------------------
# Resolve SVN HEAD
# --------------------------------------------------

resolve_svn_head() {

    local svnpath="$1"
    local svnuser="$2"
    local svnpassword="$3"

    local svn_args=(
        --non-interactive
        --no-auth-cache
    )

    if [[ -n "$svnuser" ]]; then
        svn_args+=(--username "$svnuser")
    fi

    if [[ -n "$svnpassword" ]]; then
        svn_args+=(--password "$svnpassword")
    fi

    svn info \
        --show-item revision \
        --revision HEAD \
        "${svn_args[@]}" \
        "$svnpath"
}

# --------------------------------------------------
# Register worker in config.xml
# --------------------------------------------------

register_worker() {

    local workerid="$1"
    local name="${workerid^}"
    local baseurl="http://${workerid}:8000"

    local count

    count=$(xmlstarlet sel \
        -t -v "count(//controller/worker[@id='$workerid'])" \
        "$CONFIG_XML_POSIX")

    if [[ "$count" != "0" ]]; then
        echo "ERROR: Worker $workerid is already registered."
        return 1
    fi

    if ! xmlstarlet ed -L \
        -s "(//controller)[1]" \
            -t elem -n worker -v "" \
        -i "(//controller/worker)[last()]" \
            -t attr -n id -v "$workerid" \
        -i "(//controller/worker)[last()]" \
            -t attr -n name -v "$name" \
        -s "(//controller/worker)[last()]" \
            -t elem -n base-url -v "$baseurl" \
        "$CONFIG_XML_POSIX"; then

        echo "ERROR: Could not register worker in config.xml."
        return 1
    fi

    echo "Worker $workerid registered in config.xml."
}

# --------------------------------------------------
# Unregister worker from config.xml
# --------------------------------------------------

unregister_worker() {

    local workerid="$1"

    local count

    count=$(xmlstarlet sel \
        -t -v "count(//controller/worker[@id='$workerid'])" \
        "$CONFIG_XML_POSIX")

    if [[ "$count" == "0" ]]; then
        echo "WARNING: Worker $workerid is not registered in config.xml."
        return 0
    fi

    if ! xmlstarlet ed -L \
        -d "//controller/worker[@id='$workerid']" \
        "$CONFIG_XML_POSIX"; then

        echo "ERROR: Could not unregister worker."
        return 1
    fi

    echo "Worker $workerid removed from config.xml."
}

# --------------------------------------------------
# Check worker ID uniqueness
# --------------------------------------------------

check_worker_id() {

    local workerid="$1"
    local existing

    # Check XML registrations.
    local count

    count=$(xmlstarlet sel \
        -t -v "count(//controller/worker[@id='$workerid'])" \
        "$CONFIG_XML_POSIX")

    if [[ "$count" != "0" ]]; then
        echo "ERROR: Worker ID '$workerid' already exists."
        return 1
    fi

    # Check worker labels and legacy container names.
    while IFS= read -r existing; do

        [[ -z "$existing" ]] && continue

        local id container

        id=$(yq -r \
            ".services.${existing}.labels.\"worker-manager.worker-id\" // \"\"" \
            "$COMPOSE_FILE")

        container=$(yq -r \
            ".services.${existing}.container_name // \"\"" \
            "$COMPOSE_FILE")

        if [[ "$id" == "$workerid" || "$container" == "$workerid" ]]; then
            echo "ERROR: Worker ID '$workerid' already exists."
            return 1
        fi

    done < <(
        yq -r '.services | keys | .[] |
            select(test("^worker[0-9]+$"))' "$COMPOSE_FILE"
    )

    return 0
}

# --------------------------------------------------
# Add worker
# --------------------------------------------------

add_worker() {

    echo
    echo "========== Add new worker =========="
    echo

    local workerid converterid svnpath svnrev
    local svnuser svnpassword
    local service image

    # Worker ID
    read -rp "Worker ID: " workerid

    if [[ ! "$workerid" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        echo "ERROR: Invalid worker ID."
        return 1
    fi

    if ! check_worker_id "$workerid"; then
        return 1
    fi

    # Converter ID
    read -rp "Converter ID: " converterid

    if [[ ! "$converterid" =~ ^[a-z0-9]+([._-][a-z0-9]+)*$ ]]; then
        echo "ERROR: Invalid converter ID."
        echo "Use lowercase letters, numbers, dots, underscores or hyphens."
        return 1
    fi

    # SVN parameters
    read -rp "SVN path: " svnpath

    if [[ -z "$svnpath" ]]; then
        echo "ERROR: SVN path is required."
        return 1
    fi

    read -rp "SVN revision (empty = HEAD): " svnrev
    read -rp "SVN username (optional): " svnuser

    svnpassword=""

    if [[ -n "$svnuser" ]]; then
        read -rsp "SVN password: " svnpassword
        echo
    fi

    # Resolve SVN HEAD
    if [[ -z "$svnrev" ]]; then

        echo
        echo "Resolving current SVN HEAD revision..."

        if ! svnrev=$(resolve_svn_head \
            "$svnpath" "$svnuser" "$svnpassword"); then

            echo "ERROR: Could not resolve SVN HEAD."
            return 1
        fi
    fi

    if [[ ! "$svnrev" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid SVN revision: $svnrev"
        return 1
    fi

    # Generate Docker image name
    image="transpectui_${converterid}:${svnrev}"

    # Generate Compose service name
    service=$(next_worker_service)

    echo
    echo "========== Worker configuration =========="
    echo "Compose service : $service"
    echo "Worker ID       : $workerid"
    echo "Converter ID    : $converterid"
    echo "SVN path        : $svnpath"
    echo "SVN revision    : $svnrev"
    echo "Docker image    : $image"
    echo "Container name  : $workerid"
    echo "Base URL        : http://${workerid}:8000"
    echo "=========================================="
    echo

    read -rp "Build and add this worker? (y/n): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 0
    fi

    # --------------------------------------------------
    # Build Docker image
    # --------------------------------------------------

    echo
    echo "Building Docker image..."

    # The first buildWorker.sh argument determines
    # the converter/image identifier.
    if ! bash "$BUILD_SCRIPT" \
        "$converterid" \
        "$svnpath" \
        "$svnrev" \
        "$svnuser" \
        "$svnpassword"; then

        echo "ERROR: Worker build failed."
        return 1
    fi

    # Verify expected image exists.
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        echo "ERROR: Expected Docker image was not created: $image"
        return 1
    fi

    echo "Docker image successfully built."

    # --------------------------------------------------
    # Backup configuration files
    # --------------------------------------------------

    local compose_backup xml_backup

    compose_backup="${COMPOSE_FILE_POSIX}.$(date +%Y%m%d_%H%M%S).bak"
    xml_backup="${CONFIG_XML_POSIX}.$(date +%Y%m%d_%H%M%S).bak"

    cp -p "$COMPOSE_FILE_POSIX" "$compose_backup"
    cp -p "$CONFIG_XML_POSIX" "$xml_backup"

    echo "Configuration backups created."

    # --------------------------------------------------
    # Update docker-compose.yml
    # --------------------------------------------------

    echo "Updating docker-compose.yml..."

    if ! SERVICE="$service" \
         WORKER_IMAGE="$image" \
         WORKER_ID="$workerid" \
         CONVERTER_ID="$converterid" \
         yq -i '
            .services[strenv(SERVICE)] = {
                "image": strenv(WORKER_IMAGE),
                "container_name": strenv(WORKER_ID),

                "labels": {
                    "worker-manager.worker-id": strenv(WORKER_ID),
                    "worker-manager.converter-id": strenv(CONVERTER_ID)
                },

                "volumes": [
                    "../data/" + strenv(WORKER_ID) + ":/opt/data",
                    "../scripts:/opt/scripts"
                ],

                "networks": {
                    "default": {
                        "aliases": [strenv(WORKER_ID)]
                    }
                },

                "logging": {
                    "driver": "json-file",
                    "options": {
                        "max-size": "5m"
                    }
                }
            }
        ' "$COMPOSE_FILE"; then

        echo "ERROR: Could not update docker-compose.yml."
        restore_configurations "$compose_backup" "$xml_backup"
        return 1
    fi

    # --------------------------------------------------
    # Register worker in TranspectUI
    # --------------------------------------------------

    if ! register_worker "$workerid"; then

        echo "ERROR: Worker registration failed."
        restore_configurations "$compose_backup" "$xml_backup"
        return 1
    fi

    # --------------------------------------------------
    # Validate both configuration files
    # --------------------------------------------------

    if ! validate_configurations; then

        echo "ERROR: Configuration validation failed."
        restore_configurations "$compose_backup" "$xml_backup"
        return 1
    fi

    echo
    echo "Worker successfully added to both configurations."

    # --------------------------------------------------
    # Start worker
    # --------------------------------------------------

    read -rp "Start the new worker now? (y/n): " start

    if [[ "$start" =~ ^[Yy]$ ]]; then

        if docker compose -f "$COMPOSE_FILE" up -d "$service"; then
            echo "Worker $workerid started successfully."
        else
            echo "ERROR: Could not start worker."
            echo "The configuration has been saved; worker remains stopped."
            return 1
        fi

    else
        echo "Worker configured but not started."
    fi

    echo
    echo "=========================================="
    echo "Worker addition completed."
    echo "Service : $service"
    echo "Worker  : $workerid"
    echo "Image   : $image"
    echo "=========================================="
}

# --------------------------------------------------
# Delete worker
# --------------------------------------------------

delete_worker() {

    echo
    echo "========== Delete worker =========="

    list_workers

    local service image workerid container converterid

    read -rp "Enter worker service name to delete: " service

    if [[ ! "$service" =~ ^worker[0-9]+$ ]] ||
       ! yq -e ".services.${service} != null" \
           "$COMPOSE_FILE" >/dev/null; then

        echo "ERROR: Worker does not exist."
        return 1
    fi

    image=$(yq -r \
        ".services.${service}.image // \"\"" "$COMPOSE_FILE")

    container=$(yq -r \
        ".services.${service}.container_name // \"\"" "$COMPOSE_FILE")

    workerid=$(yq -r \
        ".services.${service}.labels.\"worker-manager.worker-id\" // \"\"" \
        "$COMPOSE_FILE")

    converterid=$(yq -r \
        ".services.${service}.labels.\"worker-manager.converter-id\" // \"\"" \
        "$COMPOSE_FILE")

    # Legacy workers have no management labels.
    if [[ -z "$workerid" ]]; then
        echo
        echo "This is an existing worker without management labels."
        read -rp "Enter its TranspectUI worker ID: " workerid
    fi

    if [[ ! "$workerid" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        echo "ERROR: Invalid worker ID."
        return 1
    fi

    if [[ -z "$converterid" ]]; then
        converterid="${image#transpectui_}"
        converterid="${converterid%%:*}"
    fi

    echo
    echo "========== Selected worker =========="
    echo "Compose service : $service"
    echo "Worker ID       : $workerid"
    echo "Converter ID    : $converterid"
    echo "Docker image    : $image"
    echo "Container       : $container"
    echo "====================================="
    echo

    read -rp "Really delete this worker? (y/n): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 0
    fi

    # --------------------------------------------------
    # Backup configuration files
    # --------------------------------------------------

    local compose_backup xml_backup

    compose_backup="${COMPOSE_FILE_POSIX}.$(date +%Y%m%d_%H%M%S).bak"
    xml_backup="${CONFIG_XML_POSIX}.$(date +%Y%m%d_%H%M%S).bak"

    cp -p "$COMPOSE_FILE_POSIX" "$compose_backup"
    cp -p "$CONFIG_XML_POSIX" "$xml_backup"

    # --------------------------------------------------
    # Stop and remove worker container
    # --------------------------------------------------

    echo "Stopping worker..."

    if ! docker compose -f "$COMPOSE_FILE" stop "$service"; then
        echo "ERROR: Could not stop worker."
        return 1
    fi

    if ! docker compose -f "$COMPOSE_FILE" rm -f "$service"; then
        echo "ERROR: Could not remove worker container."
        return 1
    fi

    # --------------------------------------------------
    # Remove worker from config.xml
    # --------------------------------------------------

    if ! unregister_worker "$workerid"; then
        restore_configurations "$compose_backup" "$xml_backup"
        return 1
    fi

    # --------------------------------------------------
    # Remove worker from docker-compose.yml
    # --------------------------------------------------

    echo "Removing service from docker-compose.yml..."

    if ! yq -i "del(.services.${service})" "$COMPOSE_FILE"; then
        echo "ERROR: Could not update docker-compose.yml."
        restore_configurations "$compose_backup" "$xml_backup"
        return 1
    fi

    # --------------------------------------------------
    # Validate configurations
    # --------------------------------------------------

    if ! validate_configurations; then
        echo "ERROR: Configuration validation failed."
        restore_configurations "$compose_backup" "$xml_backup"
        return 1
    fi

    echo
    echo "Worker $workerid removed from both configurations."

    # --------------------------------------------------
    # Optionally remove Docker image
    # --------------------------------------------------

    read -rp "Also delete Docker image $image? (y/n): " remove_image

    if [[ "$remove_image" =~ ^[Yy]$ ]] && [[ -n "$image" ]]; then

        if ! docker image rm "$image"; then
            echo "WARNING: Docker image could not be removed."
            echo "It may still be used by another container or tag."
        fi
    fi

    echo
    echo "Worker deletion completed."
}

# --------------------------------------------------
# Main menu
# --------------------------------------------------

main_menu() {

    while true; do

        echo
        echo "====================================="
        echo "        Docker Worker Manager"
        echo "====================================="
        echo "  1) Add worker"
        echo "  2) Delete worker"
        echo "  3) List workers"
        echo "  4) Exit"
        echo "====================================="

        read -rp "Select option: " choice

        case "$choice" in
            1)
                add_worker
                ;;
            2)
                delete_worker
                ;;
            3)
                list_workers
                ;;
            4)
                echo "Goodbye."
                exit 0
                ;;
            *)
                echo "Invalid selection."
                ;;
        esac
    done
}

# ==================================================
# Start application
# ==================================================

check_requirements

main_menu
