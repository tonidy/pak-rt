#!/bin/bash

# RT (Rukun Tetangga) Container Runtime
# Educational container runtime implementation using Linux namespaces and cgroups
# Author: Container Learning Project
# Version: 1.0

set -euo pipefail

# =============================================================================
# CONFIGURATION VARIABLES AND CONSTANTS
# =============================================================================

# Script metadata
readonly SCRIPT_NAME="RT Container Runtime"
readonly SCRIPT_VERSION="1.0"
readonly SCRIPT_AUTHOR="Container Learning Project"

# Detect operating system
DETECTED_OS=$(uname -s)
readonly DETECTED_OS

# Detect cgroup version
detect_cgroup_version() {
    if [[ "$DETECTED_OS" == "Darwin" ]]; then
        echo "none"
    elif mount | grep -q "cgroup2.*cgroup2"; then
        echo "v2"
    elif [[ -d "/sys/fs/cgroup/memory" ]] && [[ -f "/sys/fs/cgroup/memory/memory.limit_in_bytes" ]]; then
        echo "v1"
    else
        echo "unknown"
    fi
}

CGROUP_VERSION=$(detect_cgroup_version)
readonly CGROUP_VERSION

# System paths and directories (will be set based on rootless mode and OS)
CONTAINERS_DIR="/tmp/containers"
BUSYBOX_PATH="/tmp/containers/busybox"

# Set cgroup root and mode based on OS and cgroup version
if [[ "$DETECTED_OS" == "Darwin" ]]; then
    readonly CGROUP_ROOT=""  # macOS doesn't have cgroups
    readonly MACOS_MODE=true
    readonly CGROUP_V2_MODE=false
else
    readonly CGROUP_ROOT="/sys/fs/cgroup"
    readonly MACOS_MODE=false
    if [[ "$CGROUP_VERSION" == "v2" ]]; then
        readonly CGROUP_V2_MODE=true
    else
        readonly CGROUP_V2_MODE=false
    fi
fi

# Network configuration
readonly CONTAINER_NETWORK="10.0.0.0/24"
readonly CONTAINER_IP_START="10.0.0.2"

# Default resource limits
readonly DEFAULT_MEMORY_MB=512
readonly DEFAULT_CPU_PERCENT=50

# Colors for educational output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'

# Logging levels
readonly LOG_ERROR=1
readonly LOG_WARN=2
readonly LOG_INFO=3
readonly LOG_DEBUG=4

# Default log level
LOG_LEVEL=${LOG_LEVEL:-3}

# Educational and monitoring features
VERBOSE_MODE=${VERBOSE_MODE:-false}
DEBUG_MODE=${DEBUG_MODE:-false}
MONITORING_ENABLED=${MONITORING_ENABLED:-false}

# Rootless mode support
ROOTLESS_MODE=${ROOTLESS_MODE:-false}

# Initialize paths based on rootless mode
init_paths() {
    if [[ "$ROOTLESS_MODE" == "true" ]]; then
        CONTAINERS_DIR="$HOME/.local/share/rt-containers"
        BUSYBOX_PATH="$CONTAINERS_DIR/busybox"
    fi
}

# Check OS compatibility and show appropriate warnings
check_os_compatibility() {
    log_debug "Checking OS compatibility" \
              "Seperti RT memeriksa apakah sistem mendukung operasi yang diperlukan"

    if [[ "$MACOS_MODE" == "true" ]]; then
        log_warn "Running on macOS - container features will be limited" \
                 "Berjalan di macOS - fitur container akan terbatas"
        log_info "macOS limitations:" \
                 "Keterbatasan macOS:"
        echo "   • No cgroups support (resource limits disabled)"
        echo "   • No Linux namespaces (limited isolation)"
        echo "   • Network features may not work as expected"
        echo "   • This is primarily for educational purposes"
        echo ""
        log_info "For full container functionality, use Linux or Docker Desktop" \
                 "Untuk fungsi container penuh, gunakan Linux atau Docker Desktop"
        return 1
    fi

    return 0
}

# Monitoring intervals (seconds)
readonly RESOURCE_MONITOR_INTERVAL=2
readonly NETWORK_MONITOR_INTERVAL=5

# =============================================================================
# CLI INTERFACE AND COMMAND PARSING
# =============================================================================

# Parse command line arguments for create-container command
parse_create_container_args() {
    local container_name=""
    local memory_mb="$DEFAULT_MEMORY_MB"
    local cpu_percent="$DEFAULT_CPU_PERCENT"
    
    # First argument should be container name
    if [[ -n "$1" && ! "$1" =~ ^-- ]]; then
        container_name="$1"
        shift
    fi
    
    # Parse optional parameters
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ram=*)
                memory_mb="${1#*=}"
                shift
                ;;
            --cpu=*)
                cpu_percent="${1#*=}"
                shift
                ;;
            --memory=*)
                memory_mb="${1#*=}"
                shift
                ;;
            *)
                log_error "Unknown parameter: $1" "Seperti RT menerima permintaan yang tidak dimengerti"
                return 1
                ;;
        esac
    done
    
    # Export parsed values for use by calling function
    export PARSED_CONTAINER_NAME="$container_name"
    export PARSED_MEMORY_MB="$memory_mb"
    export PARSED_CPU_PERCENT="$cpu_percent"
    
    return 0
}

# Validate parsed arguments
validate_create_container_args() {
    if [[ -z "$PARSED_CONTAINER_NAME" ]]; then
        log_error "Container name is required" "Seperti rumah harus punya nama untuk didaftarkan RT"
        echo "Usage: $0 create-container <name> [--ram=MB] [--cpu=PERCENT]"
        return 1
    fi
    
    if ! validate_container_name "$PARSED_CONTAINER_NAME"; then
        return 1
    fi
    
    if ! validate_memory_limit "$PARSED_MEMORY_MB"; then
        return 1
    fi
    
    if ! validate_cpu_percentage "$PARSED_CPU_PERCENT"; then
        return 1
    fi
    
    return 0
}

# =============================================================================
# UTILITY FUNCTIONS - LOGGING WITH RT ANALOGY
# =============================================================================

# Log function with RT (Rukun Tetangga) housing analogy
log() {
    local level=$1
    local message=$2
    local analogy=${3:-""}
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ $level -le $LOG_LEVEL ]]; then
        case $level in
            $LOG_ERROR)
                echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} [$timestamp] 🚨 $message" >&2
                [[ -n "$analogy" ]] && echo -e "${COLOR_RED}        📝 Analogi: $analogy${COLOR_RESET}" >&2
                ;;
            $LOG_WARN)
                echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET}  [$timestamp] ⚠️  $message" >&2
                [[ -n "$analogy" ]] && echo -e "${COLOR_YELLOW}        📝 Analogi: $analogy${COLOR_RESET}" >&2
                ;;
            $LOG_INFO)
                echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET}  [$timestamp] ℹ️  $message"
                [[ -n "$analogy" ]] && echo -e "${COLOR_GREEN}        📝 Analogi: $analogy${COLOR_RESET}"
                ;;
            $LOG_DEBUG)
                echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} [$timestamp] 🔍 $message"
                [[ -n "$analogy" ]] && echo -e "${COLOR_CYAN}        📝 Analogi: $analogy${COLOR_RESET}"
                ;;
        esac
    fi
}

# Convenience logging functions with RT analogies
log_error() {
    log $LOG_ERROR "$1" "${2:-Seperti ada masalah di kompleks perumahan yang perlu segera ditangani RT}"
}

log_warn() {
    log $LOG_WARN "$1" "${2:-Seperti ada hal yang perlu diperhatikan RT untuk kelancaran kompleks}"
}

log_info() {
    log $LOG_INFO "$1" "${2:-Seperti pengumuman RT untuk warga kompleks}"
}

log_debug() {
    log $LOG_DEBUG "$1" "${2:-Seperti catatan detail RT untuk monitoring kompleks}"
}

# Educational step-by-step logging
log_step() {
    local step_number=$1
    local step_description=$2
    local analogy=${3:-""}
    
    echo -e "\n${COLOR_BLUE}📋 Step $step_number: $step_description${COLOR_RESET}"
    [[ -n "$analogy" ]] && echo -e "${COLOR_BLUE}   🏘️  Analogi: $analogy${COLOR_RESET}"
    
    # Add verbose details if enabled
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "${COLOR_CYAN}   🔍 Verbose: Executing step with detailed monitoring...${COLOR_RESET}"
        sleep 0.5  # Brief pause for educational effect
    fi
}

# Verbose educational logging with detailed explanations
log_verbose() {
    local message=$1
    local technical_detail=${2:-""}
    local analogy=${3:-""}
    
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "${COLOR_PURPLE}[VERBOSE]${COLOR_RESET} 📚 $message"
        [[ -n "$technical_detail" ]] && echo -e "${COLOR_PURPLE}          🔧 Technical: $technical_detail${COLOR_RESET}"
        [[ -n "$analogy" ]] && echo -e "${COLOR_PURPLE}          🏘️  Analogi: $analogy${COLOR_RESET}"
    fi
}

# Debug logging with system details
log_debug_detail() {
    local component=$1
    local detail=$2
    local system_info=${3:-""}
    
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} 🔍 [$component] $detail"
        [[ -n "$system_info" ]] && echo -e "${COLOR_CYAN}        📊 System: $system_info${COLOR_RESET}"
    fi
}

# Success message with celebration
log_success() {
    local message=$1
    local analogy=${2:-"Seperti RT berhasil menyelesaikan tugas untuk warga kompleks"}
    
    echo -e "\n${COLOR_GREEN}✅ SUCCESS: $message${COLOR_RESET}"
    echo -e "${COLOR_GREEN}   🎉 Analogi: $analogy${COLOR_RESET}\n"
}

# =============================================================================
# ROOTLESS MODE SUPPORT FUNCTIONS
# =============================================================================

# Check if rootless mode is supported on this system
check_rootless_support() {
    log_debug "Checking rootless container support" \
              "Seperti RT memeriksa apakah bisa bekerja tanpa wewenang penuh"

    local support_issues=()

    # Check if user namespaces are enabled
    if [[ ! -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
        support_issues+=("user_namespaces_not_available")
    else
        local userns_enabled=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "0")
        if [[ "$userns_enabled" != "1" ]]; then
            support_issues+=("user_namespaces_disabled")
        fi
    fi

    # Check if newuidmap and newgidmap are available
    if ! command -v newuidmap &> /dev/null; then
        support_issues+=("newuidmap_missing")
    fi

    if ! command -v newgidmap &> /dev/null; then
        support_issues+=("newgidmap_missing")
    fi

    # Check if user has subuid/subgid mappings
    local current_user=$(id -un)
    if [[ -f /etc/subuid ]] && ! grep -q "^$current_user:" /etc/subuid; then
        support_issues+=("subuid_mapping_missing")
    fi

    if [[ -f /etc/subgid ]] && ! grep -q "^$current_user:" /etc/subgid; then
        support_issues+=("subgid_mapping_missing")
    fi

    if [[ ${#support_issues[@]} -gt 0 ]]; then
        log_warn "Rootless mode support issues detected: ${support_issues[*]}" \
                 "Ditemukan masalah untuk mode tanpa wewenang penuh"
        return 1
    fi

    log_success "Rootless mode is supported on this system" \
                "Sistem mendukung mode tanpa wewenang penuh"
    return 0
}

# Setup rootless environment
setup_rootless_environment() {
    log_info "Setting up rootless container environment" \
             "Seperti RT menyiapkan lingkungan kerja dengan wewenang terbatas"

    # Create directories with user permissions in rootless mode
    if [[ "$ROOTLESS_MODE" == "true" ]]; then
        create_directory "$CONTAINERS_DIR" 755
        create_directory "$(dirname "$BUSYBOX_PATH")" 755

        log_info "Rootless containers directory: $CONTAINERS_DIR" \
                 "Direktori rumah mode terbatas: $CONTAINERS_DIR"
    fi

    return 0
}

# Check if cgroups v2 is available for rootless
check_rootless_cgroups() {
    if [[ "$ROOTLESS_MODE" != "true" ]]; then
        return 0
    fi

    # In rootless mode, we can only use cgroups v2 with systemd user session
    if [[ -d "/sys/fs/cgroup/user.slice/user-$(id -u).slice" ]]; then
        log_info "Rootless cgroups available via systemd user session" \
                 "Pembatasan resource tersedia melalui sesi user"
        return 0
    else
        log_warn "Rootless cgroups not available - resource limits will be disabled" \
                 "Pembatasan resource tidak tersedia dalam mode terbatas"
        return 1
    fi
}

# =============================================================================
# COMPREHENSIVE ERROR HANDLING AND RECOVERY SYSTEM
# =============================================================================

# Error tracking and recovery state
# Note: Using simple variables instead of associative arrays for macOS compatibility
ERROR_CONTEXT_DATA=""
ROLLBACK_STACK_DATA=""
RECOVERY_ACTIONS_DATA=""
CURRENT_OPERATION=""
OPERATION_START_TIME=""

# Error categories for better handling
readonly ERROR_PERMISSION=1
readonly ERROR_RESOURCE=2
readonly ERROR_NETWORK=3
readonly ERROR_FILESYSTEM=4
readonly ERROR_PROCESS=5
readonly ERROR_VALIDATION=6
readonly ERROR_DEPENDENCY=7

# Recovery state tracking
RECOVERY_IN_PROGRESS=false
PARTIAL_CLEANUP_NEEDED=false

# Helper function to extract data from error context string
get_error_context_value() {
    local key=$1
    local default_value=${2:-""}

    if [[ -n "$ERROR_CONTEXT_DATA" ]]; then
        local value=$(echo "$ERROR_CONTEXT_DATA" | grep -o "$key:[^|]*" | cut -d: -f2- || echo "$default_value")
        echo "$value"
    else
        echo "$default_value"
    fi
}

# Initialize error handling system
init_error_handling() {
    log_debug "Initializing comprehensive error handling system" \
              "Seperti RT yang menyiapkan sistem penanganan darurat untuk kompleks"

    # Clear any previous error state
    ERROR_CONTEXT_DATA=""
    ROLLBACK_STACK_DATA=""
    RECOVERY_ACTIONS_DATA=""
    RECOVERY_IN_PROGRESS=false
    PARTIAL_CLEANUP_NEEDED=false

    # Set up enhanced signal handlers
    setup_enhanced_signal_handlers

    return 0
}

# Enhanced signal handlers with recovery
setup_enhanced_signal_handlers() {
    trap 'handle_script_exit $?' EXIT
    trap 'handle_interrupt_signal SIGINT' INT
    trap 'handle_terminate_signal SIGTERM' TERM
    trap 'handle_error_signal $? $LINENO' ERR
}

# Handle script exit with comprehensive cleanup
handle_script_exit() {
    local exit_code=$1
    
    if [[ $exit_code -ne 0 && "$RECOVERY_IN_PROGRESS" != "true" ]]; then
        log_error "Script exiting with error code $exit_code" \
                  "Seperti RT mengalami masalah dalam menjalankan tugas"
        
        # Perform emergency cleanup if needed
        if [[ "$PARTIAL_CLEANUP_NEEDED" == "true" ]]; then
            log_warn "Performing emergency cleanup due to partial failure" \
                     "Seperti RT melakukan pembersihan darurat setelah masalah"
            perform_emergency_cleanup
        fi
        
        # Show troubleshooting hints
        show_error_troubleshooting "$exit_code"
    fi
    
    exit $exit_code
}

# Handle interrupt signal (Ctrl+C)
handle_interrupt_signal() {
    local signal=$1
    log_warn "Received $signal, initiating graceful shutdown..." \
             "Seperti RT menerima instruksi untuk menghentikan operasi dengan aman"
    
    # Set recovery flag to prevent recursive cleanup
    RECOVERY_IN_PROGRESS=true
    
    # Perform current operation cleanup
    if [[ -n "$CURRENT_OPERATION" ]]; then
        log_info "Cleaning up current operation: $CURRENT_OPERATION" \
                 "Seperti RT membersihkan pekerjaan yang sedang berlangsung"
        cleanup_current_operation
    fi
    
    exit 130
}

# Handle terminate signal
handle_terminate_signal() {
    local signal=$1
    log_warn "Received $signal, performing immediate cleanup..." \
             "Seperti RT menerima perintah darurat untuk berhenti segera"
    
    RECOVERY_IN_PROGRESS=true
    perform_emergency_cleanup
    exit 143
}

# Handle error signal with context
handle_error_signal() {
    local exit_code=$1
    local line_number=$2

    if [[ "$RECOVERY_IN_PROGRESS" != "true" ]]; then
        log_error "Error occurred at line $line_number with exit code $exit_code" \
                  "Seperti RT menemukan masalah pada langkah tertentu"

        # Add error context using simple string format
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        ERROR_CONTEXT_DATA="line:$line_number|exit_code:$exit_code|operation:$CURRENT_OPERATION|timestamp:$timestamp"

        # Mark for cleanup
        PARTIAL_CLEANUP_NEEDED=true
    fi
}

# Set current operation context for better error reporting
set_operation_context() {
    local operation=$1
    local details=${2:-""}

    CURRENT_OPERATION="$operation"
    OPERATION_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    log_debug "Starting operation: $operation" \
              "Seperti RT memulai tugas: $operation"

    # Store error context in simple variables for compatibility
    ERROR_CONTEXT_DATA="operation:$operation|details:$details|start_time:$OPERATION_START_TIME"
}

# Clear operation context when completed successfully
clear_operation_context() {
    local operation=$1
    
    if [[ "$CURRENT_OPERATION" == "$operation" ]]; then
        log_debug "Completed operation: $operation" \
                  "Seperti RT berhasil menyelesaikan tugas: $operation"
        CURRENT_OPERATION=""
        OPERATION_START_TIME=""
    fi
}

# Add rollback action to stack
add_rollback_action() {
    local action_id=$1
    local action_command=$2
    local description=${3:-"Rollback action"}

    # Store rollback actions in simple string format
    if [[ -n "$ROLLBACK_STACK_DATA" ]]; then
        ROLLBACK_STACK_DATA="$ROLLBACK_STACK_DATA|$action_id:$action_command"
        RECOVERY_ACTIONS_DATA="$RECOVERY_ACTIONS_DATA|$action_id:$description"
    else
        ROLLBACK_STACK_DATA="$action_id:$action_command"
        RECOVERY_ACTIONS_DATA="$action_id:$description"
    fi

    log_debug "Added rollback action: $action_id" \
              "Seperti RT mencatat langkah pembatalan: $description"
}

# Execute rollback actions in reverse order
execute_rollback() {
    local operation=${1:-"unknown"}

    if [[ -z "$ROLLBACK_STACK_DATA" ]]; then
        log_info "No rollback actions needed for operation: $operation" \
                 "Tidak ada langkah pembatalan yang diperlukan"
        return 0
    fi

    log_warn "Executing rollback for operation: $operation" \
             "Seperti RT membatalkan perubahan yang sudah dilakukan"

    RECOVERY_IN_PROGRESS=true

    # Execute rollback actions in reverse order
    local rollback_count=0
    local IFS='|'
    local rollback_actions=($ROLLBACK_STACK_DATA)
    local recovery_descriptions=($RECOVERY_ACTIONS_DATA)

    # Process in reverse order
    for ((i=${#rollback_actions[@]}-1; i>=0; i--)); do
        local action_entry="${rollback_actions[i]}"
        local desc_entry="${recovery_descriptions[i]}"

        local action_id="${action_entry%%:*}"
        local action_command="${action_entry#*:}"
        local description="${desc_entry#*:}"

        log_info "Rollback step $((++rollback_count)): $description" \
                 "Seperti RT membatalkan: $description"

        if eval "$action_command" 2>/dev/null; then
            log_debug "Rollback action succeeded: $action_id"
        else
            log_warn "Rollback action failed: $action_id" \
                     "Gagal membatalkan: $description"
        fi
    done

    # Clear rollback data
    ROLLBACK_STACK_DATA=""
    RECOVERY_ACTIONS_DATA=""

    RECOVERY_IN_PROGRESS=false
    log_success "Rollback completed for operation: $operation" \
                "RT berhasil membatalkan perubahan yang bermasalah"
}

# Cleanup current operation
cleanup_current_operation() {
    if [[ -n "$CURRENT_OPERATION" ]]; then
        case "$CURRENT_OPERATION" in
            "create_container")
                cleanup_partial_container_creation
                ;;
            "delete_container")
                cleanup_partial_container_deletion
                ;;
            "setup_network")
                cleanup_partial_network_setup
                ;;
            "setup_cgroup")
                cleanup_partial_cgroup_setup
                ;;
            "setup_namespace")
                cleanup_partial_namespace_setup
                ;;
            *)
                log_warn "Unknown operation for cleanup: $CURRENT_OPERATION" \
                         "Operasi tidak dikenal untuk pembersihan"
                ;;
        esac
    fi
}

# Emergency cleanup for critical failures
perform_emergency_cleanup() {
    log_warn "Performing emergency cleanup..." \
             "Seperti RT melakukan pembersihan darurat kompleks"
    
    RECOVERY_IN_PROGRESS=true
    
    # Clean up any partial container states
    cleanup_all_partial_states
    
    # Clean up orphaned network interfaces
    cleanup_orphaned_network_interfaces
    
    # Clean up orphaned cgroups
    cleanup_orphaned_cgroups
    
    # Clean up orphaned namespaces
    cleanup_orphaned_namespaces
    
    RECOVERY_IN_PROGRESS=false
    log_info "Emergency cleanup completed" \
             "Pembersihan darurat selesai"
}

# Detect and recover from corrupted state
detect_and_recover_corrupted_state() {
    local container_name=${1:-""}
    
    log_info "Checking for corrupted container state..." \
             "Seperti RT memeriksa kondisi rumah yang bermasalah"
    
    local corruption_found=false
    
    if [[ -n "$container_name" ]]; then
        # Check specific container
        if check_container_corruption "$container_name"; then
            corruption_found=true
            recover_corrupted_container "$container_name"
        fi
    else
        # Check all containers
        if [[ -d "$CONTAINERS_DIR" ]]; then
            for container_dir in "$CONTAINERS_DIR"/*; do
                if [[ -d "$container_dir" && "$(basename "$container_dir")" != "busybox" ]]; then
                    local name=$(basename "$container_dir")
                    if check_container_corruption "$name"; then
                        corruption_found=true
                        recover_corrupted_container "$name"
                    fi
                fi
            done
        fi
    fi
    
    if [[ "$corruption_found" == "false" ]]; then
        log_success "No corrupted state detected" \
                    "Semua rumah dalam kondisi baik"
    fi
    
    return 0
}

# Check if container state is corrupted
check_container_corruption() {
    local container_name=$1
    local container_dir="$CONTAINERS_DIR/$container_name"
    
    # Check if container directory exists but is incomplete
    if [[ ! -d "$container_dir" ]]; then
        return 1  # Not corrupted, just doesn't exist
    fi
    
    local corruption_issues=()
    
    # Check for missing essential files
    if [[ ! -f "$container_dir/config.json" ]]; then
        corruption_issues+=("missing_config")
    fi
    
    # Check for orphaned PID file with dead process
    if [[ -f "$container_dir/container.pid" ]]; then
        local pid=$(cat "$container_dir/container.pid" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
            corruption_issues+=("orphaned_pid")
        fi
    fi
    
    # Check for missing rootfs
    if [[ ! -d "$container_dir/rootfs" ]]; then
        corruption_issues+=("missing_rootfs")
    fi
    
    # Check for orphaned cgroups
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    if [[ -d "$memory_cgroup" ]] && [[ ! -f "$container_dir/container.pid" ]]; then
        corruption_issues+=("orphaned_cgroup")
    fi
    
    # Check for orphaned network namespace
    if ip netns list 2>/dev/null | grep -q "container-$container_name"; then
        if [[ ! -f "$container_dir/container.pid" ]]; then
            corruption_issues+=("orphaned_netns")
        fi
    fi
    
    if [[ ${#corruption_issues[@]} -gt 0 ]]; then
        log_warn "Container corruption detected for '$container_name': ${corruption_issues[*]}" \
                 "Ditemukan masalah pada rumah '$container_name'"
        return 0  # Corruption found
    fi
    
    return 1  # No corruption
}

# Recover corrupted container state
recover_corrupted_container() {
    local container_name=$1
    local container_dir="$CONTAINERS_DIR/$container_name"
    
    log_info "Recovering corrupted container: $container_name" \
             "Seperti RT memperbaiki rumah yang bermasalah: $container_name"
    
    set_operation_context "recover_container" "$container_name"
    
    # Clean up orphaned PID file
    if [[ -f "$container_dir/container.pid" ]]; then
        local pid=$(cat "$container_dir/container.pid" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
            log_info "Removing orphaned PID file" \
                     "Menghapus catatan proses yang sudah mati"
            rm -f "$container_dir/container.pid"
        fi
    fi
    
    # Clean up orphaned cgroups
    cleanup_container_cgroups "$container_name" 2>/dev/null || true
    
    # Clean up orphaned network namespace
    cleanup_container_network "$container_name" 2>/dev/null || true
    
    # Recreate missing config if possible
    if [[ ! -f "$container_dir/config.json" ]] && [[ -d "$container_dir" ]]; then
        log_info "Recreating missing config file" \
                 "Membuat ulang berkas konfigurasi yang hilang"
        create_default_container_config "$container_name"
    fi
    
    # Recreate missing rootfs structure
    if [[ ! -d "$container_dir/rootfs" ]]; then
        log_info "Recreating missing rootfs structure" \
                 "Membuat ulang struktur sistem file yang hilang"
        create_directory "$container_dir/rootfs"
        setup_busybox "$container_name" 2>/dev/null || true
    fi
    
    clear_operation_context "recover_container"
    
    log_success "Container recovery completed: $container_name" \
                "Pemulihan rumah selesai: $container_name"
}

# Create default config for corrupted container
create_default_container_config() {
    local container_name=$1
    local config_file="$CONTAINERS_DIR/$container_name/config.json"
    
    cat > "$config_file" << EOF
{
  "name": "$container_name",
  "created": "$(date -Iseconds)",
  "status": "stopped",
  "resources": {
    "memory_mb": $DEFAULT_MEMORY_MB,
    "cpu_percentage": $DEFAULT_CPU_PERCENT
  },
  "network": {
    "ip_address": "",
    "veth_host": "",
    "veth_container": ""
  },
  "namespaces": {
    "pid": "",
    "net": "",
    "mnt": "",
    "uts": "",
    "ipc": "",
    "user": ""
  },
  "cgroups": {
    "memory": "$CGROUP_ROOT/memory/container-$container_name",
    "cpu": "$CGROUP_ROOT/cpu/container-$container_name"
  },
  "pid": 0,
  "recovered": true,
  "recovery_timestamp": "$(date -Iseconds)"
}
EOF
}

# Enhanced error reporting with troubleshooting hints
show_error_troubleshooting() {
    local exit_code=$1
    
    echo -e "\n${COLOR_RED}🚨 ERROR TROUBLESHOOTING GUIDE${COLOR_RESET}"
    echo -e "${COLOR_RED}===============================${COLOR_RESET}\n"
    
    case $exit_code in
        1)
            echo -e "${COLOR_YELLOW}📋 General Error (Exit Code 1):${COLOR_RESET}"
            echo -e "   • Check command syntax and parameters"
            echo -e "   • Verify container names and resource limits"
            echo -e "   • Review log messages above for specific details"
            ;;
        2)
            echo -e "${COLOR_YELLOW}📋 Permission Error (Exit Code 2):${COLOR_RESET}"
            echo -e "   • Run script with sudo: sudo $0 [command]"
            echo -e "   • Check file permissions in $CONTAINERS_DIR"
            echo -e "   • Verify cgroup permissions in $CGROUP_ROOT"
            ;;
        126)
            echo -e "${COLOR_YELLOW}📋 Command Not Executable (Exit Code 126):${COLOR_RESET}"
            echo -e "   • Check if script has execute permissions"
            echo -e "   • Verify busybox binary at $BUSYBOX_PATH"
            echo -e "   • Run: chmod +x $0"
            ;;
        127)
            echo -e "${COLOR_YELLOW}📋 Command Not Found (Exit Code 127):${COLOR_RESET}"
            echo -e "   • Install missing dependencies: unshare, nsenter, ip"
            echo -e "   • Check PATH environment variable"
            echo -e "   • Run dependency check: $0 debug system"
            ;;
        130)
            echo -e "${COLOR_YELLOW}📋 Interrupted by User (Exit Code 130):${COLOR_RESET}"
            echo -e "   • Operation was cancelled by Ctrl+C"
            echo -e "   • Check for partial container states"
            echo -e "   • Run cleanup if needed: $0 cleanup-all"
            ;;
        *)
            echo -e "${COLOR_YELLOW}📋 Unknown Error (Exit Code $exit_code):${COLOR_RESET}"
            echo -e "   • Check system logs: journalctl -xe"
            echo -e "   • Run debug mode: $0 debug all"
            echo -e "   • Check available resources: df -h, free -h"
            ;;
    esac
    
    echo -e "\n${COLOR_CYAN}🔍 DIAGNOSTIC COMMANDS:${COLOR_RESET}"
    echo -e "   • System info: $0 debug system"
    echo -e "   • Container status: $0 debug containers"
    echo -e "   • Network status: $0 debug network"
    echo -e "   • Recovery check: $0 recover-state"
    
    echo -e "\n${COLOR_PURPLE}🏘️  ANALOGI RT:${COLOR_RESET}"
    echo -e "   Seperti RT yang memberikan panduan mengatasi masalah kompleks"
    echo -e "   berdasarkan jenis masalah yang terjadi di perumahan\n"
}

# Validate system state before operations
validate_system_state() {
    local operation=${1:-"general"}
    
    log_debug "Validating system state for operation: $operation" \
              "Seperti RT memeriksa kondisi kompleks sebelum melakukan tugas"
    
    local validation_errors=()
    
    # Check basic requirements
    if [[ $EUID -ne 0 && "$ROOTLESS_MODE" != "true" ]]; then
        validation_errors+=("insufficient_privileges")
    fi
    
    # Check disk space
    local available_space=$(df "$CONTAINERS_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    if [[ $available_space -lt 100000 ]]; then  # Less than 100MB
        validation_errors+=("insufficient_disk_space")
    fi
    
    # Check memory
    local available_memory=$(free | grep '^Mem:' | awk '{print $7}' 2>/dev/null || echo "0")
    if [[ $available_memory -lt 100000 ]]; then  # Less than 100MB
        validation_errors+=("insufficient_memory")
    fi
    
    # Check cgroup availability
    if [[ ! -d "$CGROUP_ROOT" ]]; then
        validation_errors+=("cgroups_unavailable")
    fi
    
    # Operation-specific validations
    case "$operation" in
        "create_container")
            if [[ ! -x "$BUSYBOX_PATH" ]]; then
                validation_errors+=("busybox_unavailable")
            fi
            ;;
        "network_setup")
            if ! command -v ip &> /dev/null; then
                validation_errors+=("ip_command_unavailable")
            fi
            ;;
    esac
    
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "System validation failed: ${validation_errors[*]}" \
                  "Seperti RT menemukan masalah yang harus diperbaiki sebelum melanjutkan"
        return 1
    fi
    
    log_debug "System validation passed for operation: $operation" \
              "Sistem siap untuk operasi: $operation"
    return 0
}

# =============================================================================
# SECURITY FEATURES AND PRIVILEGE MANAGEMENT
# =============================================================================

# Input sanitization functions
sanitize_container_name() {
    local input=$1
    
    # Remove any potentially dangerous characters
    local sanitized=$(echo "$input" | tr -cd '[:alnum:]_-')
    
    # Ensure it doesn't start with special characters
    sanitized=$(echo "$sanitized" | sed 's/^[-_]*//')
    
    # Limit length to prevent buffer overflow attacks
    if [[ ${#sanitized} -gt 50 ]]; then
        sanitized=${sanitized:0:50}
    fi
    
    echo "$sanitized"
}

# Sanitize numeric input (memory, CPU)
sanitize_numeric_input() {
    local input=$1
    local max_value=${2:-999999}
    
    # Remove any non-numeric characters
    local sanitized=$(echo "$input" | tr -cd '[:digit:]')
    
    # Ensure it's not empty
    if [[ -z "$sanitized" ]]; then
        sanitized="0"
    fi
    
    # Limit to reasonable maximum
    if [[ $sanitized -gt $max_value ]]; then
        sanitized=$max_value
    fi
    
    echo "$sanitized"
}

# Sanitize file paths to prevent directory traversal
sanitize_file_path() {
    local input=$1
    local base_dir=${2:-"$CONTAINERS_DIR"}
    
    # Remove any directory traversal attempts
    local sanitized=$(echo "$input" | sed 's/\.\.//g' | sed 's/\/\+/\//g')
    
    # Remove leading slashes to prevent absolute path injection
    sanitized=$(echo "$sanitized" | sed 's/^\/*//')
    
    # Ensure path stays within base directory
    local full_path="$base_dir/$sanitized"
    local canonical_base=$(readlink -f "$base_dir" 2>/dev/null || echo "$base_dir")
    local canonical_path=$(readlink -f "$full_path" 2>/dev/null || echo "$full_path")
    
    # Check if canonical path starts with canonical base
    if [[ "$canonical_path" != "$canonical_base"* ]]; then
        log_error "Path traversal attempt detected: $input" \
                  "Seperti ada yang mencoba mengakses area terlarang di kompleks"
        return 1
    fi
    
    echo "$sanitized"
}

# Enhanced privilege checking with detailed validation
check_enhanced_privileges() {
    local operation=${1:-"general"}

    log_debug "Checking enhanced privileges for operation: $operation" \
              "Seperti RT memeriksa wewenang untuk tugas: $operation"

    # Check if running as root (skip in rootless mode)
    if [[ $EUID -ne 0 && "$ROOTLESS_MODE" != "true" ]]; then
        log_error "Root privileges required for $operation" \
                  "Seperti RT memerlukan wewenang khusus untuk: $operation"
        return 1
    fi

    # Skip capability checks in rootless mode
    if [[ "$ROOTLESS_MODE" == "true" ]]; then
        log_debug "Skipping capability checks in rootless mode" \
                  "Melewati pemeriksaan kapabilitas dalam mode rootless"
        return 0
    fi

    # If running as root, log success and continue
    if [[ $EUID -eq 0 ]]; then
        log_debug "Running with root privileges for operation: $operation" \
                  "Berjalan dengan wewenang root untuk operasi: $operation"
    fi

    # Check specific capabilities based on operation
    case "$operation" in
        "namespace_operations")
            if ! check_capability "CAP_SYS_ADMIN"; then
                log_error "CAP_SYS_ADMIN capability required for namespace operations" \
                          "Diperlukan izin khusus untuk mengelola namespace"
                log_info "Try running with: sudo $0 or enable rootless mode with ROOTLESS_MODE=true" \
                         "Coba jalankan dengan: sudo $0 atau aktifkan mode rootless"
                return 1
            fi
            ;;
        "network_operations")
            if ! check_capability "CAP_NET_ADMIN"; then
                log_error "CAP_NET_ADMIN capability required for network operations" \
                          "Diperlukan izin khusus untuk mengelola jaringan"
                log_info "Try running with: sudo $0 or enable rootless mode with ROOTLESS_MODE=true" \
                         "Coba jalankan dengan: sudo $0 atau aktifkan mode rootless"
                return 1
            fi
            ;;
        "cgroup_operations")
            if [[ ! -w "$CGROUP_ROOT" ]]; then
                log_error "Write access to cgroup filesystem required" \
                          "Diperlukan akses tulis ke sistem cgroup"
                log_info "Try running with: sudo $0" \
                         "Coba jalankan dengan: sudo $0"
                return 1
            fi
            ;;
    esac

    return 0
}

# Check specific Linux capabilities
check_capability() {
    local capability=$1

    # In rootless mode, skip capability checks
    if [[ "$ROOTLESS_MODE" == "true" ]]; then
        log_debug "Skipping capability check in rootless mode: $capability" \
                  "Melewati pemeriksaan kapabilitas dalam mode rootless"
        return 0
    fi

    # If running as root, assume capabilities are available
    if [[ $EUID -eq 0 ]]; then
        log_debug "Running as root, assuming capability available: $capability" \
                  "Berjalan sebagai root, menganggap kapabilitas tersedia"
        return 0
    fi

    # Check if capability is available (simplified check)
    if command -v capsh &> /dev/null; then
        if capsh --print | grep -q "$capability"; then
            return 0
        else
            log_debug "Capability not found via capsh: $capability" \
                      "Kapabilitas tidak ditemukan melalui capsh"
            return 1
        fi
    else
        # Fallback: assume capability is available if running as root
        log_debug "capsh not available, using root check for capability: $capability" \
                  "capsh tidak tersedia, menggunakan pemeriksaan root"
        [[ $EUID -eq 0 ]]
    fi
}

# Secure temporary file handling
create_secure_temp_file() {
    local prefix=${1:-"rt_container"}
    local suffix=${2:-".tmp"}
    
    # Create secure temporary file with restricted permissions
    local temp_file=$(mktemp -t "${prefix}_XXXXXX${suffix}")
    
    if [[ -z "$temp_file" || ! -f "$temp_file" ]]; then
        log_error "Failed to create secure temporary file" \
                  "Gagal membuat file sementara yang aman"
        return 1
    fi
    
    # Set restrictive permissions (owner read/write only)
    chmod 600 "$temp_file"
    
    # Add to cleanup list
    add_rollback_action "cleanup_temp_file_$temp_file" "rm -f '$temp_file'" "Remove temporary file"
    
    log_debug "Created secure temporary file: $temp_file" \
              "Membuat file sementara yang aman: $temp_file"
    
    echo "$temp_file"
}

# Secure temporary directory handling
create_secure_temp_dir() {
    local prefix=${1:-"rt_container"}
    
    # Create secure temporary directory with restricted permissions
    local temp_dir=$(mktemp -d -t "${prefix}_XXXXXX")
    
    if [[ -z "$temp_dir" || ! -d "$temp_dir" ]]; then
        log_error "Failed to create secure temporary directory" \
                  "Gagal membuat direktori sementara yang aman"
        return 1
    fi
    
    # Set restrictive permissions (owner access only)
    chmod 700 "$temp_dir"
    
    # Add to cleanup list
    add_rollback_action "cleanup_temp_dir_$temp_dir" "rm -rf '$temp_dir'" "Remove temporary directory"
    
    log_debug "Created secure temporary directory: $temp_dir" \
              "Membuat direktori sementara yang aman: $temp_dir"
    
    echo "$temp_dir"
}

# Container isolation verification
verify_container_isolation() {
    local container_name=$1
    local container_dir="$CONTAINERS_DIR/$container_name"
    
    log_info "Verifying container isolation for: $container_name" \
             "Seperti RT memeriksa isolasi rumah: $container_name"
    
    local isolation_issues=()
    
    # Check PID namespace isolation
    if ! verify_pid_namespace_isolation "$container_name"; then
        isolation_issues+=("pid_namespace")
    fi
    
    # Check mount namespace isolation
    if ! verify_mount_namespace_isolation "$container_name"; then
        isolation_issues+=("mount_namespace")
    fi
    
    # Check network namespace isolation
    if ! verify_network_namespace_isolation "$container_name"; then
        isolation_issues+=("network_namespace")
    fi
    
    # Check cgroup isolation
    if ! verify_cgroup_isolation "$container_name"; then
        isolation_issues+=("cgroup_isolation")
    fi
    
    # Check filesystem isolation
    if ! verify_filesystem_isolation "$container_name"; then
        isolation_issues+=("filesystem_isolation")
    fi
    
    if [[ ${#isolation_issues[@]} -gt 0 ]]; then
        log_error "Container isolation issues detected: ${isolation_issues[*]}" \
                  "Ditemukan masalah isolasi pada rumah: $container_name"
        return 1
    fi
    
    log_success "Container isolation verified successfully" \
                "Isolasi rumah terkonfirmasi aman: $container_name"
    return 0
}

# Verify PID namespace isolation
verify_pid_namespace_isolation() {
    local container_name=$1
    local pid_file="$CONTAINERS_DIR/$container_name/container.pid"
    
    if [[ ! -f "$pid_file" ]]; then
        return 1  # Container not running
    fi
    
    local container_pid=$(cat "$pid_file" 2>/dev/null || echo "")
    if [[ -z "$container_pid" ]] || ! kill -0 "$container_pid" 2>/dev/null; then
        return 1  # Invalid or dead PID
    fi
    
    # Check if container process is in different PID namespace
    local host_pid_ns=$(readlink /proc/self/ns/pid 2>/dev/null || echo "")
    local container_pid_ns=$(readlink "/proc/$container_pid/ns/pid" 2>/dev/null || echo "")
    
    if [[ -n "$host_pid_ns" && -n "$container_pid_ns" && "$host_pid_ns" != "$container_pid_ns" ]]; then
        log_debug "PID namespace isolation verified" \
                  "Isolasi nomor proses rumah terkonfirmasi"
        return 0
    fi
    
    return 1
}

# Verify mount namespace isolation
verify_mount_namespace_isolation() {
    local container_name=$1
    local pid_file="$CONTAINERS_DIR/$container_name/container.pid"
    
    if [[ ! -f "$pid_file" ]]; then
        return 1
    fi
    
    local container_pid=$(cat "$pid_file" 2>/dev/null || echo "")
    if [[ -z "$container_pid" ]] || ! kill -0 "$container_pid" 2>/dev/null; then
        return 1
    fi
    
    # Check if container process is in different mount namespace
    local host_mnt_ns=$(readlink /proc/self/ns/mnt 2>/dev/null || echo "")
    local container_mnt_ns=$(readlink "/proc/$container_pid/ns/mnt" 2>/dev/null || echo "")
    
    if [[ -n "$host_mnt_ns" && -n "$container_mnt_ns" && "$host_mnt_ns" != "$container_mnt_ns" ]]; then
        log_debug "Mount namespace isolation verified" \
                  "Isolasi sistem file rumah terkonfirmasi"
        return 0
    fi
    
    return 1
}

# Verify network namespace isolation
verify_network_namespace_isolation() {
    local container_name=$1
    
    # Check if network namespace exists
    if ip netns list 2>/dev/null | grep -q "container-$container_name"; then
        log_debug "Network namespace isolation verified" \
                  "Isolasi jaringan rumah terkonfirmasi"
        return 0
    fi
    
    return 1
}

# Verify cgroup isolation
verify_cgroup_isolation() {
    local container_name=$1
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    # Check if cgroups exist and have proper limits
    if [[ -d "$memory_cgroup" && -d "$cpu_cgroup" ]]; then
        # Verify memory limit is set
        if [[ -f "$memory_cgroup/memory.limit_in_bytes" ]]; then
            local memory_limit=$(cat "$memory_cgroup/memory.limit_in_bytes" 2>/dev/null || echo "0")
            if [[ $memory_limit -gt 0 && $memory_limit -lt 9223372036854775807 ]]; then  # Not unlimited
                log_debug "Cgroup isolation verified" \
                          "Isolasi resource rumah terkonfirmasi"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Verify filesystem isolation
verify_filesystem_isolation() {
    local container_name=$1
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    
    # Check if container has isolated rootfs
    if [[ -d "$container_rootfs" ]]; then
        # Verify essential directories exist and are properly isolated
        local essential_dirs=("bin" "proc" "sys" "tmp")
        for dir in "${essential_dirs[@]}"; do
            if [[ ! -d "$container_rootfs/$dir" ]]; then
                return 1
            fi
        done
        
        log_debug "Filesystem isolation verified" \
                  "Isolasi sistem file rumah terkonfirmasi"
        return 0
    fi
    
    return 1
}

# Security audit functions
perform_security_audit() {
    local scope=${1:-"all"}  # all, container, system
    local container_name=${2:-""}
    
    log_info "Performing security audit (scope: $scope)" \
             "Seperti RT melakukan audit keamanan kompleks"
    
    local audit_results=()
    local security_issues=()
    
    case "$scope" in
        "all")
            audit_results+=($(audit_system_security))
            audit_results+=($(audit_all_containers_security))
            ;;
        "container")
            if [[ -n "$container_name" ]]; then
                audit_results+=($(audit_container_security "$container_name"))
            else
                log_error "Container name required for container audit" \
                          "Nama rumah diperlukan untuk audit rumah"
                return 1
            fi
            ;;
        "system")
            audit_results+=($(audit_system_security))
            ;;
        *)
            log_error "Invalid audit scope: $scope" \
                      "Ruang lingkup audit tidak valid"
            return 1
            ;;
    esac
    
    # Process audit results
    for result in "${audit_results[@]}"; do
        if [[ "$result" =~ ^ISSUE: ]]; then
            security_issues+=("${result#ISSUE: }")
        fi
    done
    
    # Report results
    if [[ ${#security_issues[@]} -eq 0 ]]; then
        log_success "Security audit completed - no issues found" \
                    "Audit keamanan selesai - kompleks aman"
    else
        log_warn "Security audit found ${#security_issues[@]} issues:" \
                 "Audit keamanan menemukan ${#security_issues[@]} masalah:"
        for issue in "${security_issues[@]}"; do
            log_warn "  - $issue"
        done
    fi
    
    return 0
}

# Audit system-level security
audit_system_security() {
    local issues=()
    
    # Check if running with appropriate privileges
    if [[ $EUID -ne 0 ]]; then
        issues+=("ISSUE: Not running with root privileges")
    fi
    
    # Check cgroup availability and permissions
    if [[ ! -d "$CGROUP_ROOT" ]]; then
        issues+=("ISSUE: Cgroup filesystem not available")
    elif [[ ! -w "$CGROUP_ROOT" ]]; then
        issues+=("ISSUE: No write access to cgroup filesystem")
    fi
    
    # Check containers directory security
    if [[ -d "$CONTAINERS_DIR" ]]; then
        local dir_perms=$(stat -c "%a" "$CONTAINERS_DIR" 2>/dev/null || echo "000")
        if [[ "$dir_perms" != "755" && "$dir_perms" != "700" ]]; then
            issues+=("ISSUE: Containers directory has insecure permissions: $dir_perms")
        fi
    fi
    
    # Check for world-writable files in containers directory
    if [[ -d "$CONTAINERS_DIR" ]]; then
        local world_writable=$(find "$CONTAINERS_DIR" -type f -perm -002 2>/dev/null | wc -l)
        if [[ $world_writable -gt 0 ]]; then
            issues+=("ISSUE: Found $world_writable world-writable files in containers directory")
        fi
    fi
    
    # Check busybox binary security
    if [[ -f "$BUSYBOX_PATH" ]]; then
        local busybox_perms=$(stat -c "%a" "$BUSYBOX_PATH" 2>/dev/null || echo "000")
        if [[ "$busybox_perms" != "755" ]]; then
            issues+=("ISSUE: Busybox binary has incorrect permissions: $busybox_perms")
        fi
        
        # Check if busybox is owned by root
        local busybox_owner=$(stat -c "%U" "$BUSYBOX_PATH" 2>/dev/null || echo "unknown")
        if [[ "$busybox_owner" != "root" ]]; then
            issues+=("ISSUE: Busybox binary not owned by root: $busybox_owner")
        fi
    fi
    
    printf '%s\n' "${issues[@]}"
}

# Audit all containers security
audit_all_containers_security() {
    local issues=()
    
    if [[ ! -d "$CONTAINERS_DIR" ]]; then
        return 0
    fi
    
    for container_dir in "$CONTAINERS_DIR"/*; do
        if [[ -d "$container_dir" && "$(basename "$container_dir")" != "busybox" ]]; then
            local container_name=$(basename "$container_dir")
            local container_issues=($(audit_container_security "$container_name"))
            issues+=("${container_issues[@]}")
        fi
    done
    
    printf '%s\n' "${issues[@]}"
}

# Audit specific container security
audit_container_security() {
    local container_name=$1
    local container_dir="$CONTAINERS_DIR/$container_name"
    local issues=()
    
    if [[ ! -d "$container_dir" ]]; then
        issues+=("ISSUE: Container directory does not exist: $container_name")
        printf '%s\n' "${issues[@]}"
        return 0
    fi
    
    # Check container directory permissions
    local dir_perms=$(stat -c "%a" "$container_dir" 2>/dev/null || echo "000")
    if [[ "$dir_perms" != "755" && "$dir_perms" != "700" ]]; then
        issues+=("ISSUE: Container $container_name directory has insecure permissions: $dir_perms")
    fi
    
    # Check config file security
    local config_file="$container_dir/config.json"
    if [[ -f "$config_file" ]]; then
        local config_perms=$(stat -c "%a" "$config_file" 2>/dev/null || echo "000")
        if [[ "$config_perms" != "644" && "$config_perms" != "600" ]]; then
            issues+=("ISSUE: Container $container_name config file has insecure permissions: $config_perms")
        fi
    fi
    
    # Check for isolation if container is running
    if container_is_running "$container_name"; then
        if ! verify_container_isolation "$container_name" 2>/dev/null; then
            issues+=("ISSUE: Container $container_name isolation verification failed")
        fi
    fi
    
    # Check for orphaned resources
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    if [[ -d "$memory_cgroup" || -d "$cpu_cgroup" ]] && ! container_is_running "$container_name"; then
        issues+=("ISSUE: Container $container_name has orphaned cgroups")
    fi
    
    if ip netns list 2>/dev/null | grep -q "container-$container_name" && ! container_is_running "$container_name"; then
        issues+=("ISSUE: Container $container_name has orphaned network namespace")
    fi
    
    printf '%s\n' "${issues[@]}"
}

# Security command handler
cmd_security_audit() {
    local scope=${1:-"all"}
    local container_name=${2:-""}
    
    log_info "Starting security audit..." \
             "Seperti RT memulai inspeksi keamanan kompleks"
    
    init_error_handling
    set_operation_context "security_audit" "$scope"
    
    if ! perform_security_audit "$scope" "$container_name"; then
        log_error "Security audit failed" \
                  "Audit keamanan gagal"
        clear_operation_context "security_audit"
        return 1
    fi
    
    clear_operation_context "security_audit"
    log_success "Security audit completed" \
                "Audit keamanan selesai"
    
    return 0
}

# =============================================================================
# INPUT VALIDATION AND ERROR HANDLING UTILITIES
# =============================================================================

# Validate container name with enhanced security
validate_container_name() {
    local name=$1
    
    if [[ -z "$name" ]]; then
        log_error "Container name cannot be empty" "Seperti rumah harus punya nama/nomor untuk identifikasi RT"
        return 1
    fi
    
    # Sanitize input first
    local sanitized_name=$(sanitize_container_name "$name")
    
    # Check if sanitization changed the input (potential security issue)
    if [[ "$name" != "$sanitized_name" ]]; then
        log_error "Container name contains invalid characters (sanitized: '$sanitized_name')" \
                  "Nama rumah mengandung karakter tidak valid"
        return 1
    fi
    
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        log_error "Container name must start with alphanumeric and contain only letters, numbers, hyphens, and underscores" \
                  "Seperti nama rumah harus mengikuti aturan penamaan kompleks RT"
        return 1
    fi
    
    if [[ ${#name} -gt 50 ]]; then
        log_error "Container name too long (max 50 characters)" "Seperti nama rumah tidak boleh terlalu panjang untuk kemudahan RT"
        return 1
    fi
    
    # Additional security checks
    local forbidden_names=("root" "admin" "system" "kernel" "init" "proc" "sys" "dev" "tmp" "var" "etc" "bin" "sbin" "usr" "lib" "lib64")
    for forbidden in "${forbidden_names[@]}"; do
        if [[ "$name" == "$forbidden" ]]; then
            log_error "Container name '$name' is reserved and cannot be used" \
                      "Nama rumah '$name' adalah nama khusus yang tidak boleh digunakan"
            return 1
        fi
    done
    
    return 0
}

# Validate memory limit with sanitization
validate_memory_limit() {
    local memory_mb=$1
    
    # Sanitize numeric input first
    local sanitized_memory=$(sanitize_numeric_input "$memory_mb" 8192)
    
    # Check if sanitization changed the input
    if [[ "$memory_mb" != "$sanitized_memory" ]]; then
        log_error "Memory limit contains invalid characters (sanitized: '$sanitized_memory')" \
                  "Batas memori mengandung karakter tidak valid"
        return 1
    fi
    
    if [[ ! "$memory_mb" =~ ^[0-9]+$ ]]; then
        log_error "Memory limit must be a positive integer (MB)" "Seperti pembatasan listrik rumah harus berupa angka yang jelas"
        return 1
    fi
    
    if [[ $memory_mb -lt 64 ]]; then
        log_error "Memory limit too low (minimum 64MB)" "Seperti alokasi listrik rumah minimal harus cukup untuk kebutuhan dasar"
        return 1
    fi
    
    if [[ $memory_mb -gt 8192 ]]; then
        log_error "Memory limit too high (maximum 8GB)" "Seperti alokasi listrik rumah tidak boleh berlebihan untuk keadilan kompleks"
        return 1
    fi
    
    return 0
}

# Validate CPU percentage with sanitization
validate_cpu_percentage() {
    local cpu_percent=$1
    
    # Sanitize numeric input first
    local sanitized_cpu=$(sanitize_numeric_input "$cpu_percent" 100)
    
    # Check if sanitization changed the input
    if [[ "$cpu_percent" != "$sanitized_cpu" ]]; then
        log_error "CPU percentage contains invalid characters (sanitized: '$sanitized_cpu')" \
                  "Persentase CPU mengandung karakter tidak valid"
        return 1
    fi
    
    if [[ ! "$cpu_percent" =~ ^[0-9]+$ ]]; then
        log_error "CPU percentage must be a positive integer" "Seperti pembagian waktu kerja harus berupa persentase yang jelas"
        return 1
    fi
    
    if [[ $cpu_percent -lt 1 ]]; then
        log_error "CPU percentage too low (minimum 1%)" "Seperti alokasi waktu kerja minimal harus ada untuk aktivitas rumah"
        return 1
    fi
    
    if [[ $cpu_percent -gt 100 ]]; then
        log_error "CPU percentage too high (maximum 100%)" "Seperti alokasi waktu kerja tidak boleh melebihi 100% kapasitas"
        return 1
    fi
    
    return 0
}

# Check if running as root or with sufficient privileges (legacy function)
check_privileges() {
    # Check if rootless mode is enabled
    if [[ "$ROOTLESS_MODE" == "true" ]]; then
        log_info "Running in rootless mode - some features may be limited" \
                 "Seperti RT yang bekerja dengan wewenang terbatas"
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges for namespace and cgroup operations" \
                  "Seperti RT memerlukan wewenang khusus untuk mengatur kompleks perumahan"
        log_info "Please run with: sudo $0 $* OR set ROOTLESS_MODE=true for limited functionality"

        # Check specific cgroup permissions to provide better error messages
        if [[ -d "$CGROUP_ROOT" ]]; then
            if [[ ! -w "$CGROUP_ROOT" ]]; then
                log_error "No write access to cgroup filesystem: $CGROUP_ROOT" \
                          "Tidak ada akses tulis ke filesystem cgroup: $CGROUP_ROOT"
                log_info "This is the most likely cause of 'Permission denied' errors when setting resource limits" \
                         "Ini adalah penyebab paling mungkin dari error 'Permission denied' saat mengatur batas resource"
            fi

            # Check specific cgroup subsystems
            for subsystem in memory cpu; do
                if [[ -d "$CGROUP_ROOT/$subsystem" ]] && [[ ! -w "$CGROUP_ROOT/$subsystem" ]]; then
                    log_error "No write access to $subsystem cgroup: $CGROUP_ROOT/$subsystem" \
                              "Tidak ada akses tulis ke cgroup $subsystem: $CGROUP_ROOT/$subsystem"
                fi
            done
        else
            log_error "Cgroup filesystem not found at: $CGROUP_ROOT" \
                      "Filesystem cgroup tidak ditemukan di: $CGROUP_ROOT"
            log_info "Make sure cgroups are enabled and mounted on your system" \
                     "Pastikan cgroups diaktifkan dan di-mount pada sistem Anda"
        fi

        exit 1
    fi

    # Perform enhanced privilege checking for critical operations
    check_enhanced_privileges "general" || exit 1
}

# Provide specific troubleshooting advice for cgroup permission issues
show_cgroup_permission_help() {
    echo ""
    log_info "🔧 TROUBLESHOOTING CGROUP PERMISSION ISSUES:" \
             "🔧 MENGATASI MASALAH IZIN CGROUP:"
    echo ""
    log_info "1. Run with sudo (recommended):" \
             "1. Jalankan dengan sudo (direkomendasikan):"
    log_info "   sudo $0 [command]" \
             "   sudo $0 [command]"
    echo ""
    log_info "2. Check if cgroups are properly mounted:" \
             "2. Periksa apakah cgroups sudah di-mount dengan benar:"
    log_info "   mount | grep cgroup" \
             "   mount | grep cgroup"
    echo ""
    log_info "3. Check cgroup permissions:" \
             "3. Periksa izin cgroup:"
    log_info "   ls -la $CGROUP_ROOT" \
             "   ls -la $CGROUP_ROOT"
    echo ""
    log_info "4. For Ubuntu/Debian systems, try:" \
             "4. Untuk sistem Ubuntu/Debian, coba:"
    log_info "   sudo mount -t cgroup -o memory,cpu cgroup /sys/fs/cgroup" \
             "   sudo mount -t cgroup -o memory,cpu cgroup /sys/fs/cgroup"
    echo ""
    log_info "5. Alternative: Use rootless mode (limited functionality):" \
             "5. Alternatif: Gunakan mode rootless (fungsi terbatas):"
    log_info "   ROOTLESS_MODE=true $0 [command]" \
             "   ROOTLESS_MODE=true $0 [command]"
    echo ""
}

# Check if required commands are available
check_dependencies() {
    local missing_deps=()
    local required_commands=("unshare" "nsenter" "ip" "mount" "umount")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}" \
                  "Seperti RT memerlukan peralatan lengkap untuk mengelola kompleks"
        log_info "Please install missing dependencies and try again"
        exit 1
    fi
}

# Cleanup function for graceful exit
cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with error code $exit_code" \
                  "Seperti RT mengalami masalah dalam menjalankan tugas"
        log_info "Check the error messages above for troubleshooting"
    fi
    
    exit $exit_code
}

# Set up signal handlers for graceful cleanup
setup_signal_handlers() {
    trap cleanup_on_exit EXIT
    trap 'log_warn "Received SIGINT, cleaning up..."; exit 130' INT
    trap 'log_warn "Received SIGTERM, cleaning up..."; exit 143' TERM
}

# Validate if container exists
container_exists() {
    local name=$1
    [[ -d "$CONTAINERS_DIR/$name" ]]
}

# Validate if container is running
container_is_running() {
    local name=$1
    local pid_file="$CONTAINERS_DIR/$name/container.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        kill -0 "$pid" 2>/dev/null
    else
        return 1
    fi
}

# Create directory with proper permissions
create_directory() {
    local dir_path=$1
    local permissions=${2:-755}
    
    if [[ ! -d "$dir_path" ]]; then
        log_debug "Creating directory: $dir_path" "Seperti RT membuat folder baru untuk organisasi kompleks"
        mkdir -p "$dir_path"
        chmod "$permissions" "$dir_path"
    fi
}

# =============================================================================
# PARTIAL FAILURE CLEANUP FUNCTIONS
# =============================================================================

# Cleanup partial container creation
cleanup_partial_container_creation() {
    local container_name=$(get_error_context_value "details" "unknown")

    if [[ "$container_name" == "unknown" ]]; then
        log_warn "Cannot cleanup partial container creation - container name unknown" \
                 "Tidak dapat membersihkan pembuatan rumah yang gagal - nama tidak diketahui"
        return 1
    fi
    
    log_info "Cleaning up partial container creation: $container_name" \
             "Membersihkan pembuatan rumah yang gagal: $container_name"
    
    # Remove container directory if it exists
    local container_dir="$CONTAINERS_DIR/$container_name"
    if [[ -d "$container_dir" ]]; then
        log_debug "Removing container directory: $container_dir"
        rm -rf "$container_dir" 2>/dev/null || true
    fi
    
    # Clean up cgroups
    cleanup_container_cgroups "$container_name" 2>/dev/null || true
    
    # Clean up network
    cleanup_container_network "$container_name" 2>/dev/null || true
    
    # Clean up namespaces
    cleanup_container_namespaces "$container_name" 2>/dev/null || true
    
    log_success "Partial container creation cleanup completed: $container_name" \
                "Pembersihan pembuatan rumah yang gagal selesai: $container_name"
}

# Cleanup partial container deletion
cleanup_partial_container_deletion() {
    local container_name=$(get_error_context_value "details" "unknown")

    log_info "Cleaning up partial container deletion: $container_name" \
             "Membersihkan penghapusan rumah yang tidak selesai: $container_name"
    
    # Force cleanup of any remaining resources
    cleanup_container_cgroups "$container_name" 2>/dev/null || true
    cleanup_container_network "$container_name" 2>/dev/null || true
    cleanup_container_namespaces "$container_name" 2>/dev/null || true
    
    # Remove any remaining files
    local container_dir="$CONTAINERS_DIR/$container_name"
    if [[ -d "$container_dir" ]]; then
        rm -rf "$container_dir" 2>/dev/null || true
    fi
    
    log_success "Partial container deletion cleanup completed: $container_name" \
                "Pembersihan penghapusan rumah yang tidak selesai: $container_name"
}

# Cleanup partial network setup
cleanup_partial_network_setup() {
    local container_name=$(get_error_context_value "details" "unknown")

    log_info "Cleaning up partial network setup: $container_name" \
             "Membersihkan pemasangan jaringan yang gagal: $container_name"
    
    # Remove network namespace
    if ip netns list 2>/dev/null | grep -q "container-$container_name"; then
        log_debug "Removing network namespace: container-$container_name"
        ip netns delete "container-$container_name" 2>/dev/null || true
    fi
    
    # Remove veth pairs using consistent naming
    local veth_names=($(generate_veth_names "$container_name"))
    local veth_host="${veth_names[0]}"
    local veth_container="${veth_names[1]}"
    
    if ip link show "$veth_host" &>/dev/null; then
        log_debug "Removing veth pair: $veth_host"
        ip link delete "$veth_host" 2>/dev/null || true
    fi
    
    if ip link show "$veth_container" &>/dev/null; then
        log_debug "Removing veth pair: $veth_container"
        ip link delete "$veth_container" 2>/dev/null || true
    fi
    
    log_success "Partial network setup cleanup completed: $container_name" \
                "Pembersihan pemasangan jaringan yang gagal selesai: $container_name"
}

# Cleanup partial cgroup setup
cleanup_partial_cgroup_setup() {
    local container_name=$(get_error_context_value "details" "unknown")

    log_info "Cleaning up partial cgroup setup: $container_name" \
             "Membersihkan pengaturan resource yang gagal: $container_name"
    
    cleanup_container_cgroups "$container_name"
    
    log_success "Partial cgroup setup cleanup completed: $container_name" \
                "Pembersihan pengaturan resource yang gagal selesai: $container_name"
}

# Cleanup partial namespace setup
cleanup_partial_namespace_setup() {
    local container_name=$(get_error_context_value "details" "unknown")

    log_info "Cleaning up partial namespace setup: $container_name" \
             "Membersihkan pengaturan namespace yang gagal: $container_name"
    
    cleanup_container_namespaces "$container_name"
    
    log_success "Partial namespace setup cleanup completed: $container_name" \
                "Pembersihan pengaturan namespace yang gagal selesai: $container_name"
}

# Cleanup all partial states
cleanup_all_partial_states() {
    log_info "Cleaning up all partial container states..." \
             "Membersihkan semua rumah yang dalam kondisi tidak lengkap..."
    
    if [[ ! -d "$CONTAINERS_DIR" ]]; then
        return 0
    fi
    
    local cleanup_count=0
    for container_dir in "$CONTAINERS_DIR"/*; do
        if [[ -d "$container_dir" && "$(basename "$container_dir")" != "busybox" ]]; then
            local container_name=$(basename "$container_dir")
            
            # Check if container is in partial state
            if check_container_corruption "$container_name"; then
                log_info "Cleaning up partial state for: $container_name" \
                         "Membersihkan kondisi tidak lengkap untuk: $container_name"
                
                cleanup_container_cgroups "$container_name" 2>/dev/null || true
                cleanup_container_network "$container_name" 2>/dev/null || true
                cleanup_container_namespaces "$container_name" 2>/dev/null || true
                
                cleanup_count=$((cleanup_count + 1))
            fi
        fi
    done
    
    log_success "Cleaned up $cleanup_count partial container states" \
                "Berhasil membersihkan $cleanup_count rumah yang tidak lengkap"
}

# Cleanup orphaned network interfaces
cleanup_orphaned_network_interfaces() {
    log_info "Cleaning up orphaned network interfaces..." \
             "Membersihkan sambungan jaringan yang terlantar..."
    
    local cleanup_count=0
    
    # Clean up orphaned veth pairs
    if command -v ip &> /dev/null; then
        # Find veth pairs that match our naming pattern but have no corresponding container
        ip link show type veth 2>/dev/null | grep -E "veth-(host|cont)-" | while read -r line; do
            local veth_name=$(echo "$line" | awk '{print $2}' | sed 's/@.*//' | sed 's/://')
            local container_name=""
            
            if [[ "$veth_name" =~ veth-host-(.*) ]]; then
                container_name="${BASH_REMATCH[1]}"
            elif [[ "$veth_name" =~ veth-cont-(.*) ]]; then
                container_name="${BASH_REMATCH[1]}"
            fi
            
            if [[ -n "$container_name" ]] && [[ ! -d "$CONTAINERS_DIR/$container_name" ]]; then
                log_debug "Removing orphaned veth interface: $veth_name"
                ip link delete "$veth_name" 2>/dev/null || true
                cleanup_count=$((cleanup_count + 1))
            fi
        done
        
        # Clean up orphaned network namespaces
        ip netns list 2>/dev/null | grep "container-" | while read -r ns_name; do
            local container_name="${ns_name#container-}"
            if [[ ! -d "$CONTAINERS_DIR/$container_name" ]]; then
                log_debug "Removing orphaned network namespace: $ns_name"
                ip netns delete "$ns_name" 2>/dev/null || true
                cleanup_count=$((cleanup_count + 1))
            fi
        done
    fi
    
    log_success "Cleaned up orphaned network interfaces" \
                "Berhasil membersihkan sambungan jaringan yang terlantar"
}

# Cleanup orphaned cgroups
cleanup_orphaned_cgroups() {
    log_info "Cleaning up orphaned cgroups..." \
             "Membersihkan pengaturan resource yang terlantar..."
    
    local cleanup_count=0
    
    # Clean up memory cgroups
    if [[ -d "$CGROUP_ROOT/memory" ]]; then
        for cgroup_dir in "$CGROUP_ROOT/memory"/container-*; do
            if [[ -d "$cgroup_dir" ]]; then
                local container_name=$(basename "$cgroup_dir" | sed 's/container-//')
                if [[ ! -d "$CONTAINERS_DIR/$container_name" ]]; then
                    log_debug "Removing orphaned memory cgroup: $cgroup_dir"
                    rmdir "$cgroup_dir" 2>/dev/null || true
                    cleanup_count=$((cleanup_count + 1))
                fi
            fi
        done
    fi
    
    # Clean up CPU cgroups
    if [[ -d "$CGROUP_ROOT/cpu" ]]; then
        for cgroup_dir in "$CGROUP_ROOT/cpu"/container-*; do
            if [[ -d "$cgroup_dir" ]]; then
                local container_name=$(basename "$cgroup_dir" | sed 's/container-//')
                if [[ ! -d "$CONTAINERS_DIR/$container_name" ]]; then
                    log_debug "Removing orphaned CPU cgroup: $cgroup_dir"
                    rmdir "$cgroup_dir" 2>/dev/null || true
                    cleanup_count=$((cleanup_count + 1))
                fi
            fi
        done
    fi
    
    log_success "Cleaned up orphaned cgroups" \
                "Berhasil membersihkan pengaturan resource yang terlantar"
}

# Cleanup orphaned namespaces
cleanup_orphaned_namespaces() {
    log_info "Cleaning up orphaned namespaces..." \
             "Membersihkan namespace yang terlantar..."
    
    # Most namespace cleanup is handled by process termination
    # But we can clean up any namespace-related files
    
    if [[ -d "$CONTAINERS_DIR" ]]; then
        for container_dir in "$CONTAINERS_DIR"/*; do
            if [[ -d "$container_dir/namespaces" ]]; then
                local container_name=$(basename "$container_dir")
                
                # If container has no PID file, clean up namespace configs
                if [[ ! -f "$container_dir/container.pid" ]]; then
                    log_debug "Cleaning up namespace configs for: $container_name"
                    rm -rf "$container_dir/namespaces" 2>/dev/null || true
                fi
            fi
        done
    fi
    
    log_success "Cleaned up orphaned namespaces" \
                "Berhasil membersihkan namespace yang terlantar"
}

# Enhanced container cgroup cleanup
cleanup_container_cgroups() {
    local container_name=$1
    
    log_debug "Cleaning up cgroups for container: $container_name" \
              "Membersihkan pengaturan resource untuk rumah: $container_name"
    
    # Memory cgroup cleanup
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    if [[ -d "$memory_cgroup" ]]; then
        # Kill any remaining processes in the cgroup
        if [[ -f "$memory_cgroup/cgroup.procs" ]]; then
            while read -r pid; do
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    log_debug "Killing process in memory cgroup: $pid"
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 0.1
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            done < "$memory_cgroup/cgroup.procs" 2>/dev/null || true
        fi
        
        # Remove the cgroup
        rmdir "$memory_cgroup" 2>/dev/null || true
    fi
    
    # CPU cgroup cleanup
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    if [[ -d "$cpu_cgroup" ]]; then
        # Kill any remaining processes in the cgroup
        if [[ -f "$cpu_cgroup/cgroup.procs" ]]; then
            while read -r pid; do
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    log_debug "Killing process in CPU cgroup: $pid"
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 0.1
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            done < "$cpu_cgroup/cgroup.procs" 2>/dev/null || true
        fi
        
        # Remove the cgroup
        rmdir "$cpu_cgroup" 2>/dev/null || true
    fi
}

# Enhanced container network cleanup
cleanup_container_network() {
    local container_name=$1
    
    log_debug "Cleaning up network for container: $container_name" \
              "Membersihkan jaringan untuk rumah: $container_name"
    
    # Remove network namespace
    local netns_name="container-$container_name"
    if ip netns list 2>/dev/null | grep -q "$netns_name"; then
        log_debug "Removing network namespace: $netns_name"
        ip netns delete "$netns_name" 2>/dev/null || true
    fi
    
    # Remove veth pairs using consistent naming
    local veth_names=($(generate_veth_names "$container_name"))
    local veth_host="${veth_names[0]}"
    local veth_container="${veth_names[1]}"
    
    if ip link show "$veth_host" &>/dev/null; then
        log_debug "Removing veth pair: $veth_host"
        ip link delete "$veth_host" 2>/dev/null || true
    fi
    
    if ip link show "$veth_container" &>/dev/null; then
        log_debug "Removing veth pair: $veth_container"
        ip link delete "$veth_container" 2>/dev/null || true
    fi
}

# Enhanced container namespace cleanup
cleanup_container_namespaces() {
    local container_name=$1
    local container_dir="$CONTAINERS_DIR/$container_name"
    
    log_debug "Cleaning up namespaces for container: $container_name" \
              "Membersihkan namespace untuk rumah: $container_name"
    
    # Kill container process if still running
    if [[ -f "$container_dir/container.pid" ]]; then
        local pid=$(cat "$container_dir/container.pid" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_debug "Killing container process: $pid"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            kill -KILL "$pid" 2>/dev/null || true
        fi
        rm -f "$container_dir/container.pid"
    fi
    
    # Clean up namespace configuration files
    if [[ -d "$container_dir/namespaces" ]]; then
        rm -rf "$container_dir/namespaces" 2>/dev/null || true
    fi
    
    # Unmount any remaining mounts
    if [[ -d "$container_dir/rootfs" ]]; then
        # Unmount in reverse order
        local mount_points=("/proc" "/sys" "/dev/pts" "/dev")
        for mount_point in "${mount_points[@]}"; do
            local full_path="$container_dir/rootfs$mount_point"
            if mountpoint -q "$full_path" 2>/dev/null; then
                log_debug "Unmounting: $full_path"
                umount "$full_path" 2>/dev/null || true
            fi
        done
    fi
}

# =============================================================================
# BUSYBOX MANAGEMENT SYSTEM
# =============================================================================

# Busybox configuration
readonly BUSYBOX_VERSION="system"
readonly BUSYBOX_CHECKSUM="skip"  # Use system verification instead

# Test basic busybox functionality
test_busybox_basic_functionality() {
    if [[ ! -x "$BUSYBOX_PATH" ]]; then
        return 1
    fi
    
    # Test basic commands
    if ! "$BUSYBOX_PATH" echo "test" &>/dev/null; then
        return 1
    fi
    
    if ! "$BUSYBOX_PATH" sh -c "echo 'shell test'" &>/dev/null; then
        return 1
    fi
    
    return 0
}

# Download busybox static binary from official source
# Setup busybox from system or create minimal alternative
setup_busybox_binary() {
    log_step 1 "Setting up busybox binary" \
              "Seperti RT menyiapkan peralatan dasar untuk setiap rumah di kompleks"
    
    local busybox_dir=$(dirname "$BUSYBOX_PATH")
    create_directory "$busybox_dir"
    
    # Check if busybox already exists and is functional
    if [[ -f "$BUSYBOX_PATH" ]] && [[ -x "$BUSYBOX_PATH" ]] && test_busybox_basic_functionality; then
        log_info "Busybox already exists and is functional" \
                 "Seperti peralatan rumah sudah tersedia dan dalam kondisi baik"
        return 0
    fi
    
    # Try to find system busybox first
    local system_busybox=""
    if command -v busybox &> /dev/null; then
        system_busybox=$(command -v busybox)
        log_info "Found system busybox at: $system_busybox" \
                 "Seperti menemukan peralatan standar yang sudah tersedia di kompleks"
        
        # Copy system busybox to our location
        if cp "$system_busybox" "$BUSYBOX_PATH"; then
            chmod +x "$BUSYBOX_PATH"
            
            if test_busybox_basic_functionality; then
                log_success "System busybox copied and verified successfully" \
                            "Peralatan sistem berhasil disalin dan siap digunakan"
                return 0
            fi
        fi
    fi
    
    # If system busybox not available, create minimal shell alternative
    log_info "System busybox not available, creating minimal shell alternative" \
             "Seperti RT membuat solusi darurat ketika peralatan standar tidak tersedia"
    
    create_minimal_busybox_alternative
    return $?
}

# Create minimal busybox alternative using system tools
create_minimal_busybox_alternative() {
    log_info "Creating minimal busybox alternative" \
             "Seperti RT membuat peralatan darurat dari bahan yang tersedia"
    
    # Create a shell script that acts like busybox
    cat > "$BUSYBOX_PATH" << 'EOF'
#!/bin/bash
# Minimal busybox alternative for RT Container Runtime
# This script provides basic functionality when real busybox is not available

COMMAND="$1"
shift

case "$COMMAND" in
    "sh"|"ash"|"bash"|"")
        exec /bin/bash "$@"
        ;;
    "ls")
        exec /bin/ls "$@"
        ;;
    "cat")
        exec /bin/cat "$@"
        ;;
    "echo")
        exec /bin/echo "$@"
        ;;
    "ps")
        exec /bin/ps "$@"
        ;;
    "sleep")
        exec /bin/sleep "$@"
        ;;
    "id")
        exec /usr/bin/id "$@"
        ;;
    "whoami")
        exec /usr/bin/whoami "$@"
        ;;
    "pwd")
        exec /bin/pwd "$@"
        ;;
    "mkdir")
        exec /bin/mkdir "$@"
        ;;
    "rm")
        exec /bin/rm "$@"
        ;;
    "cp")
        exec /bin/cp "$@"
        ;;
    "mv")
        exec /bin/mv "$@"
        ;;
    "chmod")
        exec /bin/chmod "$@"
        ;;
    "mount")
        exec /bin/mount "$@"
        ;;
    "umount")
        exec /bin/umount "$@"
        ;;
    "grep")
        exec /bin/grep "$@"
        ;;
    "sed")
        exec /bin/sed "$@"
        ;;
    "awk")
        exec /usr/bin/awk "$@"
        ;;
    "head")
        exec /usr/bin/head "$@"
        ;;
    "tail")
        exec /usr/bin/tail "$@"
        ;;
    "sort")
        exec /usr/bin/sort "$@"
        ;;
    "uniq")
        exec /usr/bin/uniq "$@"
        ;;
    "wc")
        exec /usr/bin/wc "$@"
        ;;
    "find")
        exec /usr/bin/find "$@"
        ;;
    "which")
        exec /usr/bin/which "$@"
        ;;
    "--help"|"help")
        echo "Minimal busybox alternative for RT Container Runtime"
        echo "Available commands: sh, ls, cat, echo, ps, sleep, id, whoami, pwd"
        echo "                   mkdir, rm, cp, mv, chmod, mount, umount"
        echo "                   grep, sed, awk, head, tail, sort, uniq, wc, find, which"
        ;;
    *)
        echo "busybox: $COMMAND: command not found"
        echo "Try 'busybox --help' for available commands"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BUSYBOX_PATH"
    
    if test_busybox_basic_functionality; then
        log_success "Minimal busybox alternative created successfully" \
                    "Peralatan darurat RT berhasil dibuat dan siap digunakan"
        return 0
    else
        log_error "Failed to create functional busybox alternative" \
                  "Gagal membuat peralatan darurat yang berfungsi"
        return 1
    fi
}

# Verify busybox binary functionality (skip checksum for system/alternative busybox)
verify_busybox_functionality() {
    log_step 2 "Verifying busybox functionality" \
              "Seperti RT memeriksa apakah peralatan rumah berfungsi dengan baik"
    
    if [[ ! -f "$BUSYBOX_PATH" ]]; then
        log_error "Busybox binary not found at $BUSYBOX_PATH" \
                  "Seperti peralatan rumah tidak ditemukan di gudang RT"
        return 1
    fi
    
    if [[ ! -x "$BUSYBOX_PATH" ]]; then
        log_error "Busybox binary is not executable" \
                  "Seperti peralatan rumah tidak bisa digunakan"
        return 1
    fi
    
    # Test basic functionality instead of checksum
    if test_busybox_basic_functionality; then
        log_success "Busybox functionality verification passed" \
                    "Peralatan rumah terbukti berfungsi dan aman untuk digunakan"
        return 0
    else
        log_error "Busybox functionality verification failed!" \
                  "Peralatan rumah tidak berfungsi dengan baik"
1
    fi
}
# Setup busybox with symlinks for common commands
setup_busybox() {
    local container_name=$1
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    
    log_step 3 "Setting up busybox for container: $container_name" \
              "Seperti RT yang menyiapkan peralatan lengkap untuk rumah baru"
    
    # Create container rootfs structure
    create_directory "$container_rootfs/bin"
    create_directory "$container_rootfs/sbin"
    create_directory "$container_rootfs/usr/bin"
    create_directory "$container_rootfs/usr/sbin"
    create_directory "$container_rootfs/proc"
    create_directory "$container_rootfs/sys"
    create_directory "$container_rootfs/dev"
    create_directory "$container_rootfs/tmp"
    create_directory "$container_rootfs/var"
    create_directory "$container_rootfs/etc"
    
    # Copy busybox to container
    local container_busybox="$container_rootfs/bin/busybox"
    cp "$BUSYBOX_PATH" "$container_busybox"
    chmod +x "$container_busybox"
    
    log_info "Creating busybox symlinks for common commands" \
             "Seperti RT yang menyiapkan shortcut peralatan untuk kemudahan warga"
    
    # Create symlinks for common commands
    local common_commands=(
        "sh" "ash" "bash" "ls" "cat" "echo" "grep" "sed" "awk"
        "ps" "top" "kill" "sleep" "date" "whoami" "id" "pwd"
        "mkdir" "rmdir" "rm" "cp" "mv" "ln" "chmod" "chown"
        "mount" "umount" "df" "du" "free" "uptime" "uname"
        "ping" "wget" "nc" "netstat" "ifconfig" "route"
        "vi" "less" "more" "head" "tail" "sort" "uniq" "wc"
        "tar" "gzip" "gunzip" "find" "which" "env" "su"
    )
    
    for cmd in "${common_commands[@]}"; do
        local symlink_path="$container_rootfs/bin/$cmd"
        if [[ ! -e "$symlink_path" ]]; then
            ln -sf "/bin/busybox" "$symlink_path"
            log_debug "Created symlink: $cmd -> /bin/busybox"
        fi
    done
    
    # Create essential system files
    echo "root:x:0:0:root:/root:/bin/sh" > "$container_rootfs/etc/passwd"
    echo "root:x:0:" > "$container_rootfs/etc/group"
    echo "127.0.0.1 localhost" > "$container_rootfs/etc/hosts"
    echo "nameserver 8.8.8.8" > "$container_rootfs/etc/resolv.conf"
    
    log_success "Busybox setup completed for container: $container_name" \
                "Peralatan rumah lengkap dan siap untuk ditempati warga"
    
    return 0
}

# Test busybox functionality
test_busybox_functionality() {
    log_step 4 "Testing busybox functionality" \
              "Seperti RT yang menguji semua peralatan rumah sebelum diserahkan ke warga"

    # Test 1: Check if busybox exists and is executable
    if [[ ! -x "$BUSYBOX_PATH" ]]; then
        log_error "Busybox is not executable" \
                  "Seperti peralatan rumah yang tidak bisa digunakan"
        return 1
    fi

    # Test 2: Check busybox version/help
    local version_output
    if ! version_output=$("$BUSYBOX_PATH" --help 2>&1 | head -1); then
        log_error "Failed to get busybox version" \
                  "Seperti tidak bisa mengecek spesifikasi peralatan rumah"
        return 1
    fi

    log_info "Busybox info: $version_output" \
             "Seperti mengecek spesifikasi peralatan yang tersedia"

    # Test 3: Test basic commands with actual functionality instead of --help
    local test_commands=("echo" "ls" "cat" "ps" "sh")

    for cmd in "${test_commands[@]}"; do
        case "$cmd" in
            "echo")
                if ! "$BUSYBOX_PATH" echo "test" &>/dev/null; then
                    log_warn "Command '$cmd' not working in busybox" \
                             "Seperti ada peralatan yang tidak berfungsi"
                else
                    log_debug "Command '$cmd' available and working"
                fi
                ;;
            "ls")
                if ! "$BUSYBOX_PATH" ls /tmp &>/dev/null; then
                    log_warn "Command '$cmd' not working in busybox" \
                             "Seperti ada peralatan yang tidak berfungsi"
                else
                    log_debug "Command '$cmd' available and working"
                fi
                ;;
            "cat")
                if ! echo "test" | "$BUSYBOX_PATH" cat &>/dev/null; then
                    log_warn "Command '$cmd' not working in busybox" \
                             "Seperti ada peralatan yang tidak berfungsi"
                else
                    log_debug "Command '$cmd' available and working"
                fi
                ;;
            "ps")
                if ! "$BUSYBOX_PATH" ps &>/dev/null; then
                    log_warn "Command '$cmd' not working in busybox" \
                             "Seperti ada peralatan yang tidak berfungsi"
                else
                    log_debug "Command '$cmd' available and working"
                fi
                ;;
            "sh")
                if ! echo "echo test" | "$BUSYBOX_PATH" sh &>/dev/null; then
                    log_warn "Command '$cmd' not working in busybox" \
                             "Seperti ada peralatan yang tidak berfungsi"
                else
                    log_debug "Command '$cmd' available and working"
                fi
                ;;
        esac
    done

    # Test 4: Test shell functionality
    local test_script='echo "Hello from busybox shell"'
    if ! echo "$test_script" | "$BUSYBOX_PATH" sh &>/dev/null; then
        log_error "Busybox shell test failed" \
                  "Seperti sistem komunikasi rumah tidak berfungsi"
        return 1
    fi

    log_success "All busybox functionality tests passed" \
                "Semua peralatan rumah telah diuji dan berfungsi dengan baik"

    return 0
}

# =============================================================================
# EDUCATIONAL FEATURES AND MONITORING SYSTEM
# =============================================================================

# Real-time resource monitoring with housing analogies
monitor_container_resources() {
    local container_name=$1
    local duration=${2:-30}  # Default 30 seconds
    
    if [[ ! -d "$CONTAINERS_DIR/$container_name" ]]; then
        log_error "Container '$container_name' not found" \
                  "Seperti rumah yang tidak terdaftar di RT"
        return 1
    fi
    
    log_info "Starting resource monitoring for container: $container_name" \
             "Seperti RT mulai memantau penggunaan listrik dan air rumah"
    
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    echo -e "\n${COLOR_GREEN}🏠 Resource Monitor - Container: $container_name${COLOR_RESET}"
    echo -e "${COLOR_GREEN}📊 Monitoring Duration: ${duration}s (seperti membaca meteran listrik dan air)${COLOR_RESET}"
    echo -e "${COLOR_GREEN}⏰ Started at: $(date)${COLOR_RESET}\n"
    
    # Header for monitoring table
    printf "%-8s %-12s %-12s %-12s %-15s\n" "Time" "Memory(MB)" "Memory%" "CPU%" "Status"
    printf "%-8s %-12s %-12s %-12s %-15s\n" "----" "----------" "--------" "-----" "------"
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local current_time=$(date +%H:%M:%S)
        local memory_usage="N/A"
        local memory_percent="N/A"
        local cpu_percent="N/A"
        local status="Unknown"
        
        # Get memory usage
        if [[ -f "$memory_cgroup/memory.usage_in_bytes" ]] && [[ -f "$memory_cgroup/memory.limit_in_bytes" ]]; then
            local memory_bytes=$(cat "$memory_cgroup/memory.usage_in_bytes" 2>/dev/null || echo "0")
            local memory_limit=$(cat "$memory_cgroup/memory.limit_in_bytes" 2>/dev/null || echo "1")
            memory_usage=$((memory_bytes / 1024 / 1024))
            memory_percent=$(( (memory_bytes * 100) / memory_limit ))
        fi
        
        # Get CPU usage (simplified)
        if [[ -f "$cpu_cgroup/cpuacct.usage" ]]; then
            cpu_percent="Active"
        fi
        
        # Check container status
        if container_is_running "$container_name"; then
            status="🟢 Running"
        else
            status="🔴 Stopped"
        fi
        
        printf "%-8s %-12s %-12s %-12s %-15s\n" \
               "$current_time" "$memory_usage" "$memory_percent%" "$cpu_percent" "$status"
        
        # Add educational commentary periodically
        if [[ $(($(date +%s) % 10)) -eq 0 ]]; then
            echo -e "${COLOR_YELLOW}   💡 Seperti RT mengecek meteran listrik: Memory ${memory_usage}MB dari limit${COLOR_RESET}"
        fi
        
        sleep $RESOURCE_MONITOR_INTERVAL
    done
    
    echo -e "\n${COLOR_GREEN}✅ Resource monitoring completed${COLOR_RESET}"
    echo -e "${COLOR_GREEN}📝 Seperti RT selesai mencatat penggunaan utilitas bulanan${COLOR_RESET}\n"
}

# Network topology display - "Peta kompleks perumahan"
show_network_topology() {
    log_info "Displaying network topology" \
             "Seperti RT menunjukkan peta kompleks perumahan dan sambungan telepon"
    
    echo -e "\n${COLOR_CYAN}🗺️  PETA KOMPLEKS PERUMAHAN RT (Network Topology)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}=================================================${COLOR_RESET}\n"
    
    # Show host network information
    echo -e "${COLOR_BLUE}🏛️  KANTOR RW (Host Network)${COLOR_RESET}"
    echo -e "${COLOR_BLUE}├── 🌐 Internet Gateway: $(ip route | grep default | awk '{print $3}' 2>/dev/null || echo 'N/A')${COLOR_RESET}"
    echo -e "${COLOR_BLUE}├── 📡 Host IP: $(hostname -I | awk '{print $1}' 2>/dev/null || echo 'N/A')${COLOR_RESET}"
    echo -e "${COLOR_BLUE}└── 🔧 Network Interface: $(ip route | grep default | awk '{print $5}' 2>/dev/null || echo 'N/A')${COLOR_RESET}"
    
    echo -e "\n${COLOR_GREEN}🏘️  KOMPLEKS PERUMAHAN (Container Network)${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── 📞 Jaringan Telepon Internal: $CONTAINER_NETWORK${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── 🏢 Kantor RT (Network Namespace Manager)${COLOR_RESET}"
    
    # List all containers and their network information
    local container_count=0
    if [[ -d "$CONTAINERS_DIR" ]]; then
        for container_dir in "$CONTAINERS_DIR"/*; do
            if [[ -d "$container_dir" && "$(basename "$container_dir")" != "busybox" ]]; then
                local container_name=$(basename "$container_dir")
                container_count=$((container_count + 1))
                
                echo -e "${COLOR_GREEN}├── 🏠 Rumah: $container_name${COLOR_RESET}"
                
                # Get container network info
                local config_file="$container_dir/config.json"
                if [[ -f "$config_file" ]]; then
                    local ip_address=$(grep -o '"ip_address":"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f4 || echo "N/A")
                    local veth_host=$(grep -o '"veth_host":"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f4 || echo "N/A")
                    local veth_container=$(grep -o '"veth_container":"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f4 || echo "N/A")
                    
                    echo -e "${COLOR_GREEN}│   ├── 📞 Nomor Telepon: $ip_address${COLOR_RESET}"
                    echo -e "${COLOR_GREEN}│   ├── 🔌 Kabel ke RT: $veth_host${COLOR_RESET}"
                    echo -e "${COLOR_GREEN}│   └── 🔌 Kabel di Rumah: $veth_container${COLOR_RESET}"
                    
                    # Check if container is running and can communicate
                    if container_is_running "$container_name"; then
                        echo -e "${COLOR_GREEN}│       └── 🟢 Status: Aktif (bisa menerima telepon)${COLOR_RESET}"
                    else
                        echo -e "${COLOR_GREEN}│       └── 🔴 Status: Tidak Aktif (telepon mati)${COLOR_RESET}"
                    fi
                else
                    echo -e "${COLOR_GREEN}│   └── ❓ Info tidak tersedia${COLOR_RESET}"
                fi
            fi
        done
    fi
    
    if [[ $container_count -eq 0 ]]; then
        echo -e "${COLOR_GREEN}└── 🏚️  Belum ada rumah yang dibangun${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}└── 📊 Total Rumah: $container_count${COLOR_RESET}"
    fi
    
    # Show network namespace information
    echo -e "\n${COLOR_PURPLE}🔍 DETAIL TEKNIS JARINGAN${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}=========================${COLOR_RESET}"
    
    # List network namespaces
    if command -v ip &> /dev/null; then
        echo -e "${COLOR_PURPLE}📡 Network Namespaces:${COLOR_RESET}"
        if ip netns list 2>/dev/null | grep -q .; then
            ip netns list 2>/dev/null | while read -r ns; do
                echo -e "${COLOR_PURPLE}   └── $ns${COLOR_RESET}"
            done
        else
            echo -e "${COLOR_PURPLE}   └── Tidak ada namespace terdeteksi${COLOR_RESET}"
        fi
        
        # Show veth pairs
        echo -e "\n${COLOR_PURPLE}🔗 Virtual Ethernet Pairs (Kabel Telepon):${COLOR_RESET}"
        if ip link show type veth 2>/dev/null | grep -q .; then
            ip link show type veth 2>/dev/null | grep -E "^[0-9]+:" | while read -r line; do
                local veth_name=$(echo "$line" | awk '{print $2}' | sed 's/@.*//' | sed 's/://')
                echo -e "${COLOR_PURPLE}   └── $veth_name${COLOR_RESET}"
            done
        else
            echo -e "${COLOR_PURPLE}   └── Tidak ada veth pairs terdeteksi${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_PURPLE}⚠️  Command 'ip' tidak tersedia untuk detail teknis${COLOR_RESET}"
    fi
    
    echo -e "\n${COLOR_CYAN}📝 Legenda Peta Kompleks:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}🏛️  = Kantor RW (Host System)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}🏢 = Kantor RT (Network Manager)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}🏠 = Rumah Warga (Container)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}📞 = Nomor Telepon (IP Address)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}🔌 = Kabel Telepon (veth pair)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}🟢 = Rumah Aktif / 🔴 = Rumah Tidak Aktif${COLOR_RESET}\n"
}

# Interactive help system with examples
show_interactive_help() {
    local topic=${1:-"main"}
    
    case "$topic" in
        "main"|"help")
            show_main_help
            ;;
        "create"|"create-container")
            show_create_help
            ;;
        "list"|"list-containers")
            show_list_help
            ;;
        "run"|"run-container")
            show_run_help
            ;;
        "delete"|"delete-container")
            show_delete_help
            ;;
        "monitor"|"monitoring")
            show_monitoring_help
            ;;
        "network"|"topology")
            show_network_help
            ;;
        "debug")
            show_debug_help
            ;;
        "analogy"|"analogies")
            show_analogy_help
            ;;
        *)
            echo -e "${COLOR_RED}❓ Unknown help topic: $topic${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}Available topics: main, create, list, run, delete, monitor, network, debug, analogy${COLOR_RESET}"
            return 1
            ;;
    esac
}

# Main help display
show_main_help() {
    echo -e "\n${COLOR_BLUE}🏘️  RT (Rukun Tetangga) Container Runtime - Interactive Help${COLOR_RESET}"
    echo -e "${COLOR_BLUE}=========================================================${COLOR_RESET}\n"
    
    echo -e "${COLOR_GREEN}📚 PERINTAH UTAMA (Main Commands):${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── create-container  : Membuat rumah baru di kompleks${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── list-containers   : Melihat daftar semua rumah${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── run-container     : Masuk ke rumah untuk beraktivitas${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── delete-container  : Menghapus rumah dari kompleks${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── monitor          : Memantau penggunaan utilitas rumah${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── show-topology    : Melihat peta kompleks perumahan${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── recover-state    : Memulihkan kondisi rumah yang bermasalah${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── validate-system  : Memeriksa kesehatan sistem kompleks${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── emergency-cleanup: Pembersihan darurat semua resource${COLOR_RESET}"
    echo -e "${COLOR_GREEN}└── cleanup-all      : Bersih-bersih kompleks menyeluruh${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}🔧 MODE OPERASI (Operation Modes):${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── --verbose        : Mode penjelasan detail${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── --debug          : Mode debugging teknis${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── --monitor        : Mode monitoring real-time${COLOR_RESET}"
    
    echo -e "\n${COLOR_PURPLE}📖 BANTUAN DETAIL (Detailed Help):${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── $0 help create   : Bantuan membuat container${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── $0 help list     : Bantuan melihat daftar container${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── $0 help run      : Bantuan menjalankan container${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── $0 help delete   : Bantuan menghapus container${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── $0 help monitor  : Bantuan monitoring resources${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── $0 help network  : Bantuan network topology${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── $0 help debug    : Bantuan debugging${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}└── $0 help analogy  : Penjelasan analogi perumahan${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}🔧 OPSI GLOBAL:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── --verbose  : Mode verbose dengan penjelasan detail${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── --debug    : Mode debug dengan informasi teknis${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── --monitor  : Aktifkan monitoring real-time${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── --rootless : Mode tanpa sudo (fitur terbatas)${COLOR_RESET}"

    echo -e "\n${COLOR_YELLOW}💡 CONTOH PENGGUNAAN CEPAT:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Membuat rumah baru dengan nama 'webapp' (perlu sudo)${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 create-container webapp --ram=512 --cpu=50${COLOR_RESET}"
    echo -e "\n${COLOR_YELLOW}# Membuat rumah tanpa sudo (mode rootless)${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}$0 --rootless create-container webapp${COLOR_RESET}"
    echo -e "\n${COLOR_YELLOW}# Masuk ke rumah 'webapp'${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 run-container webapp${COLOR_RESET}"
    echo -e "\n${COLOR_YELLOW}# Melihat semua rumah di kompleks${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 list-containers${COLOR_RESET}"
    echo -e "\n${COLOR_YELLOW}# Memantau penggunaan utilitas rumah 'webapp'${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 monitor webapp 60${COLOR_RESET}"
    
    echo -e "\n${COLOR_BLUE}🏘️  Seperti RT yang siap membantu warga kompleks!${COLOR_RESET}\n"
}

# Create container help
show_create_help() {
    echo -e "\n${COLOR_GREEN}🏗️  BANTUAN: Membuat Container (Rumah Baru)${COLOR_RESET}"
    echo -e "${COLOR_GREEN}===========================================${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}📝 SINTAKS:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$0 create-container <nama_rumah> [--ram=MB] [--cpu=PERCENT]${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}📋 PARAMETER:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── nama_rumah : Nama unik untuk rumah baru (wajib)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── --ram=MB   : Batas penggunaan RAM dalam MB (default: 512)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── --cpu=PERCENT : Batas penggunaan CPU dalam % (default: 50)${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 CONTOH PENGGUNAAN:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Rumah sederhana dengan setting default${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 create-container rumah-kecil${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}# Rumah besar dengan RAM 1GB dan CPU 75%${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 create-container rumah-besar --ram=1024 --cpu=75${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}# Rumah hemat dengan RAM 256MB dan CPU 25%${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 create-container rumah-hemat --ram=256 --cpu=25${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🏘️  ANALOGI PERUMAHAN:${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}Seperti RT yang membantu warga membangun rumah baru:${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── Nama rumah = Alamat untuk identifikasi${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── RAM = Kapasitas listrik rumah${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── CPU = Alokasi waktu kerja untuk aktivitas${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}└── RT akan menyiapkan semua infrastruktur dasar${COLOR_RESET}\n"
    
    echo -e "${COLOR_RED}⚠️  BATASAN DAN ATURAN:${COLOR_RESET}"
    echo -e "${COLOR_RED}├── Nama rumah: 1-50 karakter, huruf/angka/dash/underscore${COLOR_RESET}"
    echo -e "${COLOR_RED}├── RAM minimum: 64MB, maksimum: 8192MB (8GB)${COLOR_RESET}"
    echo -e "${COLOR_RED}├── CPU minimum: 1%, maksimum: 100%${COLOR_RESET}"
    echo -e "${COLOR_RED}└── Nama rumah harus unik di kompleks${COLOR_RESET}\n"
}

# List containers help
show_list_help() {
    echo -e "\n${COLOR_GREEN}📋 BANTUAN: Melihat Daftar Container${COLOR_RESET}"
    echo -e "${COLOR_GREEN}===================================${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}📝 SINTAKS:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$0 list-containers [--verbose] [--monitor]${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}📋 OPSI:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── --verbose : Tampilkan informasi detail${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── --monitor : Tampilkan monitoring real-time${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 CONTOH PENGGUNAAN:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Daftar sederhana${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 list-containers${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}# Daftar dengan detail lengkap${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 list-containers --verbose${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🏘️  ANALOGI: Seperti RT yang mengecek daftar warga dan status rumah${COLOR_RESET}\n"
}

# Run container help
show_run_help() {
    echo -e "\n${COLOR_GREEN}🏃 BANTUAN: Menjalankan Container${COLOR_RESET}"
    echo -e "${COLOR_GREEN}===============================${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}📝 SINTAKS:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$0 run-container <nama_rumah> [command]${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}📋 PARAMETER:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── nama_rumah : Nama rumah yang akan dimasuki${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── command    : Perintah khusus (default: shell interaktif)${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 CONTOH PENGGUNAAN:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Masuk ke rumah dengan shell interaktif${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 run-container webapp${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}# Jalankan perintah khusus${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 run-container webapp 'ls -la'${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🏘️  ANALOGI: Seperti masuk ke rumah warga untuk beraktivitas${COLOR_RESET}\n"
}

# Delete container help
show_delete_help() {
    echo -e "\n${COLOR_GREEN}🗑️  BANTUAN: Menghapus Container${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==============================${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}📝 SINTAKS:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$0 delete-container <nama_rumah> [--force]${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}📋 PARAMETER:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── nama_rumah : Nama rumah yang akan dihapus${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── --force    : Hapus paksa tanpa konfirmasi${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 CONTOH PENGGUNAAN:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Hapus dengan konfirmasi${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 delete-container old-webapp${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}# Hapus paksa${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 delete-container old-webapp --force${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🏘️  ANALOGI: Seperti RT yang membantu warga pindah dan membersihkan rumah lama${COLOR_RESET}\n"
}

# Monitoring help
show_monitoring_help() {
    echo -e "\n${COLOR_GREEN}📊 BANTUAN: Resource Monitoring${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==============================${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}📝 SINTAKS:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$0 monitor <nama_rumah> [duration_seconds]${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}📋 PARAMETER:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── nama_rumah : Nama rumah yang akan dipantau${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── duration   : Durasi monitoring dalam detik (default: 30)${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 CONTOH PENGGUNAAN:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Monitor selama 30 detik${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 monitor webapp${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}# Monitor selama 2 menit${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 monitor webapp 120${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🏘️  ANALOGI: Seperti RT yang mengecek meteran listrik dan air rumah warga${COLOR_RESET}\n"
}

# Network help
show_network_help() {
    echo -e "\n${COLOR_GREEN}🌐 BANTUAN: Network Topology${COLOR_RESET}"
    echo -e "${COLOR_GREEN}============================${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}📝 SINTAKS:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$0 show-topology [--detailed]${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}📋 OPSI:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── --detailed : Tampilkan informasi teknis detail${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 CONTOH PENGGUNAAN:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Peta kompleks sederhana${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 show-topology${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}# Peta dengan detail teknis${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 show-topology --detailed${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🏘️  ANALOGI: Seperti peta kompleks yang menunjukkan semua rumah dan sambungan telepon${COLOR_RESET}\n"
}

# Debug help
show_debug_help() {
    echo -e "\n${COLOR_GREEN}🔍 BANTUAN: Debug Mode${COLOR_RESET}"
    echo -e "${COLOR_GREEN}====================${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}📝 SINTAKS:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$0 debug [component]${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}📋 KOMPONEN:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── all        : Semua informasi debug${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── system     : Informasi sistem${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── containers : Informasi container${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── network    : Informasi jaringan${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── cgroups    : Informasi cgroups${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── namespaces : Informasi namespaces${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 CONTOH PENGGUNAAN:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Debug semua komponen${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 debug${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}# Debug jaringan saja${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}sudo $0 debug network${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🏘️  ANALOGI: Seperti RT yang melakukan inspeksi menyeluruh kompleks${COLOR_RESET}\n"
}

# Analogy help - explain the housing analogy system
show_analogy_help() {
    echo -e "\n${COLOR_PURPLE}🏘️  SISTEM ANALOGI RT DI PERUMAHAN${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}===============================${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}📚 KONSEP DASAR:${COLOR_RESET}"
    echo -e "${COLOR_BLUE}RT Container Runtime menggunakan analogi kompleks perumahan${COLOR_RESET}"
    echo -e "${COLOR_BLUE}untuk menjelaskan konsep container technology${COLOR_RESET}\n"
    
    echo -e "${COLOR_GREEN}🏠 PEMETAAN KONSEP:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── Container        = Rumah di kompleks${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── Host System      = Kantor RW (pemerintahan atas)${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── RT Script        = Kantor RT (pengelola kompleks)${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── PID Namespace    = Sistem penomoran keluarga${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── Network NS       = Sistem telepon internal${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── Mount NS         = Rak buku pribadi rumah${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── UTS NS           = Nama/papan nama rumah${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── IPC NS           = Papan tulis keluarga${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── User NS          = Sistem keanggotaan keluarga${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── Cgroups          = Pembatasan listrik & air${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── veth pairs       = Kabel telepon antar rumah${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── IP Address       = Nomor telepon rumah${COLOR_RESET}"
    echo -e "${COLOR_GREEN}└── Resource Monitor = Meteran listrik & air${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}👨‍👩‍👧‍👦 ANALOGI PID NAMESPACE:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}Setiap rumah punya sistem penomoran keluarga sendiri:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── PID 1 = Ayah (selalu nomor 1 di rumahnya)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── PID 2 = Ibu (nomor 2 di rumahnya)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├── PID 3 = Kakak (anak pertama)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└── PID 4 = Adik (anak kedua)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}Ayah di rumah A berbeda dengan Ayah di rumah B${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}📞 ANALOGI NETWORK:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}├── Setiap rumah punya nomor telepon (IP address)${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}├── Kabel telepon menghubungkan rumah (veth pairs)${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}├── Bisa telepon langsung antar rumah${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}├── RT mengelola sistem telepon kompleks${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}└── RW mengatur koneksi ke luar kompleks${COLOR_RESET}\n"
    
    echo -e "${COLOR_RED}⚡ ANALOGI RESOURCE MANAGEMENT:${COLOR_RESET}"
    echo -e "${COLOR_RED}├── RAM = Kapasitas listrik rumah${COLOR_RESET}"
    echo -e "${COLOR_RED}├── CPU = Alokasi waktu kerja${COLOR_RESET}"
    echo -e "${COLOR_RED}├── RT mengatur pembatasan untuk keadilan${COLOR_RESET}"
    echo -e "${COLOR_RED}├── Meteran untuk monitoring penggunaan${COLOR_RESET}"
    echo -e "${COLOR_RED}└── Tagihan bulanan = laporan resource usage${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🎯 TUJUAN ANALOGI:${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── Membuat konsep teknis lebih mudah dipahami${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── Menggunakan konteks yang familiar (perumahan)${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}├── Membantu visualisasi sistem yang kompleks${COLOR_RESET}"
    echo -e "${COLOR_PURPLE}└── Memberikan pembelajaran yang menyenangkan${COLOR_RESET}\n"
}

# Debug mode with detailed system information
show_debug_info() {
    local component=${1:-"all"}
    
    echo -e "\n${COLOR_CYAN}🔍 DEBUG MODE - System Information${COLOR_RESET}"
    echo -e "${COLOR_CYAN}===================================${COLOR_RESET}\n"
    
    case "$component" in
        "all"|"system")
            show_system_debug_info
            ;;
        "containers")
            show_containers_debug_info
            ;;
        "network")
            show_network_debug_info
            ;;
        "cgroups")
            show_cgroups_debug_info
            ;;
        "namespaces")
            show_namespaces_debug_info
            ;;
        *)
            echo -e "${COLOR_RED}Unknown debug component: $component${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}Available: all, system, containers, network, cgroups, namespaces${COLOR_RESET}"
            return 1
            ;;
    esac
}

# System debug information
show_system_debug_info() {
    echo -e "${COLOR_BLUE}🖥️  SYSTEM DEBUG INFO${COLOR_RESET}"
    echo -e "${COLOR_BLUE}===================${COLOR_RESET}"
    
    echo -e "${COLOR_GREEN}📊 Basic System Info:${COLOR_RESET}"
    echo -e "   OS: $(uname -s) $(uname -r)"
    echo -e "   Architecture: $(uname -m)"
    echo -e "   Hostname: $(hostname)"
    echo -e "   Uptime: $(uptime | awk '{print $3,$4}' | sed 's/,//')"
    
    echo -e "\n${COLOR_GREEN}💾 Memory Info:${COLOR_RESET}"
    if command -v free &> /dev/null; then
        free -h | head -2
    else
        echo -e "   Command 'free' not available"
    fi
    
    echo -e "\n${COLOR_GREEN}💽 Disk Usage:${COLOR_RESET}"
    df -h / 2>/dev/null | tail -1 | awk '{print "   Root: " $3 " used / " $2 " total (" $5 " full)"}'
    df -h /tmp 2>/dev/null | tail -1 | awk '{print "   /tmp: " $3 " used / " $2 " total (" $5 " full)"}'
    
    echo -e "\n${COLOR_GREEN}🔧 Required Commands:${COLOR_RESET}"
    local commands=("unshare" "nsenter" "ip" "mount" "umount")
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "   ✅ $cmd: $(command -v "$cmd")"
        else
            echo -e "   ❌ $cmd: Not found"
        fi
    done

    # Separate check for cgroups (not a command, but a kernel feature)
    if [ -d /sys/fs/cgroup ] && [ -f /sys/fs/cgroup/cgroup.controllers ]; then
        echo -e "   ✅ cgroups: /sys/fs/cgroup (cgroups v2)"
    elif [ -d /sys/fs/cgroup/memory ] && [ -d /sys/fs/cgroup/cpu ]; then
        echo -e "   ✅ cgroups: /sys/fs/cgroup (cgroups v1)"
    else
        echo -e "   ❌ cgroups: Not found"
    fi
    
    echo -e "\n${COLOR_GREEN}🏘️  RT Container Runtime:${COLOR_RESET}"
    echo -e "   Script: $0"
    echo -e "   Version: $SCRIPT_VERSION"
    echo -e "   Containers Dir: $CONTAINERS_DIR"
    echo -e "   Busybox Path: $BUSYBOX_PATH"
    echo -e "   Log Level: $LOG_LEVEL"
    echo -e "   Verbose Mode: $VERBOSE_MODE"
    echo -e "   Debug Mode: $DEBUG_MODE"
    echo ""
}

# Containers debug information
show_containers_debug_info() {
    echo -e "${COLOR_BLUE}🏠 CONTAINERS DEBUG INFO${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========================${COLOR_RESET}"
    
    if [[ ! -d "$CONTAINERS_DIR" ]]; then
        echo -e "${COLOR_RED}   ❌ Containers directory not found: $CONTAINERS_DIR${COLOR_RESET}"
        return 1
    fi
    
    echo -e "${COLOR_GREEN}📁 Containers Directory: $CONTAINERS_DIR${COLOR_RESET}"
    echo -e "   Permissions: $(ls -ld "$CONTAINERS_DIR" | awk '{print $1}')"
    echo -e "   Owner: $(ls -ld "$CONTAINERS_DIR" | awk '{print $3":"$4}')"
    
    local container_count=0
    for container_dir in "$CONTAINERS_DIR"/*; do
        if [[ -d "$container_dir" && "$(basename "$container_dir")" != "busybox" ]]; then
            local container_name=$(basename "$container_dir")
            container_count=$((container_count + 1))
            
            echo -e "\n${COLOR_CYAN}🏠 Container: $container_name${COLOR_RESET}"
            echo -e "   Path: $container_dir"
            echo -e "   Status: $(container_is_running "$container_name" && echo "🟢 Running" || echo "🔴 Stopped")"
            
            # Check config file
            local config_file="$container_dir/config.json"
            if [[ -f "$config_file" ]]; then
                echo -e "   Config: ✅ Present"
                local memory=$(grep -o '"memory_mb":[0-9]*' "$config_file" 2>/dev/null | cut -d':' -f2 || echo "N/A")
                local cpu=$(grep -o '"cpu_percentage":[0-9]*' "$config_file" 2>/dev/null | cut -d':' -f2 || echo "N/A")
                echo -e "   Memory Limit: ${memory}MB"
                echo -e "   CPU Limit: ${cpu}%"
            else
                echo -e "   Config: ❌ Missing"
            fi
            
            # Check PID file
            local pid_file="$container_dir/container.pid"
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file" 2>/dev/null || echo "N/A")
                echo -e "   PID: $pid"
            else
                echo -e "   PID: Not running"
            fi
            
            # Check rootfs
            if [[ -d "$container_dir/rootfs" ]]; then
                echo -e "   Rootfs: ✅ Present"
                echo -e "   Rootfs Size: $(du -sh "$container_dir/rootfs" 2>/dev/null | cut -f1 || echo "N/A")"
            else
                echo -e "   Rootfs: ❌ Missing"
            fi
        fi
    done
    
    echo -e "\n${COLOR_GREEN}📊 Summary: $container_count containers found${COLOR_RESET}"
    echo ""
}

# Network debug information
show_network_debug_info() {
    echo -e "${COLOR_BLUE}🌐 NETWORK DEBUG INFO${COLOR_RESET}"
    echo -e "${COLOR_BLUE}=====================${COLOR_RESET}"
    
    echo -e "${COLOR_GREEN}🔧 Network Commands Availability:${COLOR_RESET}"
    local net_commands=("ip" "ifconfig" "netstat" "ss" "ping")
    for cmd in "${net_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "   ✅ $cmd: Available"
        else
            echo -e "   ❌ $cmd: Not found"
        fi
    done
    
    if command -v ip &> /dev/null; then
        echo -e "\n${COLOR_GREEN}📡 Network Interfaces:${COLOR_RESET}"
        ip link show 2>/dev/null | grep -E "^[0-9]+:" | while read -r line; do
            local iface=$(echo "$line" | awk '{print $2}' | sed 's/://')
            local state=$(echo "$line" | grep -o "state [A-Z]*" | awk '{print $2}')
            echo -e "   └── $iface: $state"
        done
        
        echo -e "\n${COLOR_GREEN}🔗 Virtual Ethernet Pairs:${COLOR_RESET}"
        if ip link show type veth 2>/dev/null | grep -q .; then
            ip link show type veth 2>/dev/null | grep -E "^[0-9]+:" | while read -r line; do
                local veth=$(echo "$line" | awk '{print $2}' | sed 's/@.*//' | sed 's/://')
                local peer=$(echo "$line" | grep -o "@[^:]*" | sed 's/@//')
                echo -e "   └── $veth ↔ $peer"
            done
        else
            echo -e "   └── No veth pairs found"
        fi
        
        echo -e "\n${COLOR_GREEN}🏠 Network Namespaces:${COLOR_RESET}"
        if ip netns list 2>/dev/null | grep -q .; then
            ip netns list 2>/dev/null | while read -r ns; do
                echo -e "   └── $ns"
            done
        else
            echo -e "   └── No network namespaces found"
        fi
        
        echo -e "\n${COLOR_GREEN}🛣️  Routing Table:${COLOR_RESET}"
        ip route show 2>/dev/null | head -5 | while read -r route; do
            echo -e "   └── $route"
        done
    else
        echo -e "\n${COLOR_RED}⚠️  'ip' command not available - limited network debug info${COLOR_RESET}"
    fi
    
    echo ""
}

# Cgroups debug information
show_cgroups_debug_info() {
    echo -e "${COLOR_BLUE}⚙️  CGROUPS DEBUG INFO${COLOR_RESET}"
    echo -e "${COLOR_BLUE}=====================${COLOR_RESET}"
    
    echo -e "${COLOR_GREEN}📁 Cgroups Root: $CGROUP_ROOT${COLOR_RESET}"
    if [[ -d "$CGROUP_ROOT" ]]; then
        echo -e "   Status: ✅ Available"
        echo -e "   Permissions: $(ls -ld "$CGROUP_ROOT" | awk '{print $1}')"
        
        # Check cgroup version
        if [[ -f "$CGROUP_ROOT/cgroup.controllers" ]]; then
            echo -e "   Version: cgroups v2"
        elif [[ -d "$CGROUP_ROOT/memory" ]] && [[ -d "$CGROUP_ROOT/cpu" ]]; then
            echo -e "   Version: cgroups v1"
        else
            echo -e "   Version: Unknown"
        fi
    else
        echo -e "   Status: ❌ Not found"
        return 1
    fi
    
    echo -e "\n${COLOR_GREEN}🏠 Container Cgroups:${COLOR_RESET}"
    local cgroup_count=0
    
    # Check memory cgroups
    if [[ -d "$CGROUP_ROOT/memory" ]]; then
        for cgroup_dir in "$CGROUP_ROOT/memory"/container-*; do
            if [[ -d "$cgroup_dir" ]]; then
                local container_name=$(basename "$cgroup_dir" | sed 's/container-//')
                cgroup_count=$((cgroup_count + 1))
                
                echo -e "   🏠 $container_name:"
                
                # Memory info
                if [[ -f "$cgroup_dir/memory.limit_in_bytes" ]]; then
                    local limit=$(cat "$cgroup_dir/memory.limit_in_bytes" 2>/dev/null || echo "0")
                    local usage=$(cat "$cgroup_dir/memory.usage_in_bytes" 2>/dev/null || echo "0")
                    local limit_mb=$((limit / 1024 / 1024))
                    local usage_mb=$((usage / 1024 / 1024))
                    echo -e "      Memory: ${usage_mb}MB / ${limit_mb}MB"
                fi
                
                # Process count
                if [[ -f "$cgroup_dir/cgroup.procs" ]]; then
                    local proc_count=$(wc -l < "$cgroup_dir/cgroup.procs" 2>/dev/null || echo "0")
                    echo -e "      Processes: $proc_count"
                fi
            fi
        done
    fi
    
    # Check CPU cgroups
    if [[ -d "$CGROUP_ROOT/cpu" ]]; then
        echo -e "\n${COLOR_GREEN}⚡ CPU Cgroups:${COLOR_RESET}"
        for cgroup_dir in "$CGROUP_ROOT/cpu"/container-*; do
            if [[ -d "$cgroup_dir" ]]; then
                local container_name=$(basename "$cgroup_dir" | sed 's/container-//')
                
                if [[ -f "$cgroup_dir/cpu.cfs_quota_us" ]] && [[ -f "$cgroup_dir/cpu.cfs_period_us" ]]; then
                    local quota=$(cat "$cgroup_dir/cpu.cfs_quota_us" 2>/dev/null || echo "-1")
                    local period=$(cat "$cgroup_dir/cpu.cfs_period_us" 2>/dev/null || echo "100000")
                    
                    if [[ "$quota" != "-1" ]]; then
                        local cpu_percent=$(( (quota * 100) / period ))
                        echo -e "   🏠 $container_name: ${cpu_percent}% CPU limit"
                    else
                        echo -e "   🏠 $container_name: No CPU limit"
                    fi
                fi
            fi
        done
    fi
    
    if [[ $cgroup_count -eq 0 ]]; then
        echo -e "   └── No container cgroups found"
    fi
    
    echo ""
}

# Namespaces debug information
show_namespaces_debug_info() {
    echo -e "${COLOR_BLUE}🏠 NAMESPACES DEBUG INFO${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========================${COLOR_RESET}"
    
    echo -e "${COLOR_GREEN}🔧 Namespace Commands:${COLOR_RESET}"
    local ns_commands=("unshare" "nsenter" "lsns")
    for cmd in "${ns_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "   ✅ $cmd: Available"
        else
            echo -e "   ❌ $cmd: Not found"
        fi
    done
    
    # Show current process namespaces
    echo -e "\n${COLOR_GREEN}📊 Current Process Namespaces:${COLOR_RESET}"
    if [[ -d "/proc/$$/ns" ]]; then
        for ns_file in /proc/$$/ns/*; do
            if [[ -L "$ns_file" ]]; then
                local ns_type=$(basename "$ns_file")
                local ns_id=$(readlink "$ns_file" 2>/dev/null || echo "unknown")
                echo -e "   └── $ns_type: $ns_id"
            fi
        done
    else
        echo -e "   └── Namespace info not available"
    fi
    
    # List all namespaces if lsns is available
    if command -v lsns &> /dev/null; then
        echo -e "\n${COLOR_GREEN}🌐 All System Namespaces:${COLOR_RESET}"
        lsns -t net,pid,mnt,uts,ipc,user 2>/dev/null | head -10 | while read -r line; do
            echo -e "   └── $line"
        done
    fi
    
    # Check container namespaces
    echo -e "\n${COLOR_GREEN}🏠 Container Namespace Configs:${COLOR_RESET}"
    local ns_count=0
    if [[ -d "$CONTAINERS_DIR" ]]; then
        for container_dir in "$CONTAINERS_DIR"/*; do
            if [[ -d "$container_dir/namespaces" ]]; then
                local container_name=$(basename "$container_dir")
                ns_count=$((ns_count + 1))
                
                echo -e "   🏠 $container_name:"
                for ns_config in "$container_dir/namespaces"/*.conf; do
                    if [[ -f "$ns_config" ]]; then
                        local ns_type=$(basename "$ns_config" .conf)
                        echo -e "      └── $ns_type: Configured"
                    fi
                done
            fi
        done
    fi
    
    if [[ $ns_count -eq 0 ]]; then
        echo -e "   └── No container namespace configs found"
    fi
    
    echo ""
}

# Enable verbose mode
enable_verbose_mode() {
    VERBOSE_MODE=true
    log_info "Verbose mode enabled" \
             "Seperti RT yang memberikan penjelasan detail untuk setiap langkah"
}

# Enable debug mode
enable_debug_mode() {
    DEBUG_MODE=true
    LOG_LEVEL=4  # Set to debug level
    log_info "Debug mode enabled" \
             "Seperti RT yang mencatat semua detail teknis untuk troubleshooting"
}

# Enable monitoring mode
enable_monitoring_mode() {
    MONITORING_ENABLED=true
    log_info "Monitoring mode enabled" \
             "Seperti RT yang aktif memantau kondisi semua rumah di kompleks"
}

# Initialize busybox management system
init_busybox_system() {
    log_info "Initializing busybox management system" \
             "Seperti RT yang mempersiapkan sistem peralatan standar untuk kompleks"
    
    # Setup busybox binary (from system or create alternative)
    if ! setup_busybox_binary; then
        log_error "Failed to setup busybox binary" \
                  "Gagal menyiapkan peralatan dasar untuk kompleks"
        return 1
    fi
    
    # Verify functionality
    if ! verify_busybox_functionality; then
        log_error "Busybox verification failed" \
                  "Peralatan tidak lolos pemeriksaan keamanan RT"
        return 1
    fi
    
    # Test functionality
    if ! test_busybox_functionality; then
        log_error "Busybox functionality test failed" \
                  "Peralatan tidak berfungsi sebagaimana mestinya"
        return 1
    fi
    
    log_success "Busybox management system initialized successfully" \
                "Sistem peralatan RT yang siap melayani semua rumah"
    
    return 0
}

# Get busybox information
get_busybox_info() {
    echo "=== Busybox Information ==="
    echo "Path: $BUSYBOX_PATH"
    echo "Version: $BUSYBOX_VERSION"
    echo "URL: $BUSYBOX_URL"
    echo "Expected Checksum: $BUSYBOX_CHECKSUM"
    
    if [[ -f "$BUSYBOX_PATH" ]]; then
        echo "Status: Available"
        echo "Size: $(du -h "$BUSYBOX_PATH" | cut -f1)"
        echo "Permissions: $(ls -l "$BUSYBOX_PATH" | cut -d' ' -f1)"
        
        if test_busybox_basic_functionality &>/dev/null; then
            echo "Functionality: ✅ Working"
        else
            echo "Functionality: ❌ Failed"
        fi
    else
        echo "Status: Not Available"
    fi
    
    echo "=========================="
}

# =============================================================================
# NAMESPACE MANAGEMENT FUNCTIONS
# =============================================================================

# Global namespace tracking for cleanup
# Using associative arrays for proper container tracking
declare -A ACTIVE_NAMESPACES

# Helper functions for associative array management
set_container_namespace() {
    local container_name=$1
    local namespaces=$2
    ACTIVE_NAMESPACES["$container_name"]="$namespaces"
}

get_container_namespace() {
    local container_name=$1
    if [[ -n "${ACTIVE_NAMESPACES[$container_name]:-}" ]]; then
        echo "${ACTIVE_NAMESPACES[$container_name]}"
        return 0
    fi
    return 1
}

unset_container_namespace() {
    local container_name=$1
    unset ACTIVE_NAMESPACES["$container_name"]
}

# Create PID namespace with "Ayah nomor 1 di rumah" analogy
create_pid_namespace() {
    local container_name=$1
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    
    log_step 1 "Creating PID namespace for container: $container_name" \
              "Seperti membuat sistem penomoran keluarga baru - Ayah selalu nomor 1 di rumahnya"
    
    # Create namespace info directory
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    create_directory "$ns_dir"
    
    # Create PID namespace using unshare
    log_info "Setting up isolated PID namespace" \
             "Seperti setiap rumah punya sistem penomoran keluarga sendiri"
    
    # The PID namespace will be created when we actually start the container process
    # For now, we prepare the environment and save the configuration
    echo "pid_namespace_enabled=true" > "$ns_dir/pid.conf"
    echo "init_process=/bin/busybox" >> "$ns_dir/pid.conf"
    echo "init_args=sh" >> "$ns_dir/pid.conf"
    
    log_success "PID namespace configuration prepared" \
                "Sistem penomoran keluarga siap - Ayah akan menjadi nomor 1 saat rumah ditempati"
    
    return 0
}

# Setup mount namespace with isolated filesystem
create_mount_namespace() {
    local container_name=$1
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    
    log_step 2 "Creating mount namespace for container: $container_name" \
              "Seperti menyiapkan rak buku pribadi untuk setiap rumah"
    
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    create_directory "$ns_dir"
    
    # Prepare mount namespace configuration
    log_info "Preparing isolated filesystem structure" \
             "Seperti menyiapkan rak buku yang tidak bisa dilihat tetangga"
    
    # Create essential mount points
    create_directory "$container_rootfs/proc"
    create_directory "$container_rootfs/sys"
    create_directory "$container_rootfs/dev"
    create_directory "$container_rootfs/dev/pts"
    create_directory "$container_rootfs/tmp"
    create_directory "$container_rootfs/var/tmp"
    
    # Create mount configuration
    cat > "$ns_dir/mount.conf" << EOF
mount_namespace_enabled=true
rootfs_path=$container_rootfs
bind_mounts=/proc:/proc,/sys:/sys,/dev:/dev
tmpfs_mounts=/tmp,/var/tmp
readonly_mounts=/proc,/sys
EOF
    
    # Create basic device nodes (will be properly created during container start)
    echo "Creating basic device nodes" > "$ns_dir/devices.list"
    echo "/dev/null" >> "$ns_dir/devices.list"
    echo "/dev/zero" >> "$ns_dir/devices.list"
    echo "/dev/random" >> "$ns_dir/devices.list"
    echo "/dev/urandom" >> "$ns_dir/devices.list"
    
    log_success "Mount namespace configuration prepared" \
                "Rak buku pribadi rumah siap untuk digunakan"
    
    return 0
}

# Create UTS namespace for hostname isolation
create_uts_namespace() {
    local container_name=$1
    local hostname_param=${2:-$container_name}
    
    log_step 3 "Creating UTS namespace for container: $container_name" \
              "Seperti memberikan nama rumah sendiri yang unik di kompleks"
    
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    create_directory "$ns_dir"
    
    # Validate and sanitize hostname
    if [[ ! "$hostname_param" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
        log_warn "Invalid hostname format, using container name" \
                 "Format nama rumah tidak sesuai aturan, menggunakan nama default"
        hostname_param="$container_name"
    fi
    
    log_info "Setting container hostname to: $hostname_param" \
             "Seperti memasang papan nama rumah: $hostname_param"
    
    # Create UTS namespace configuration
    cat > "$ns_dir/uts.conf" << EOF
uts_namespace_enabled=true
hostname="$hostname_param"
domainname="container.local"
EOF
    
    # Create hostname file for the container (ensure etc directory exists)
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    create_directory "$container_rootfs/etc"
    echo "$hostname_param" > "$container_rootfs/etc/hostname"
    
    log_success "UTS namespace configuration prepared with hostname: $hostname_param" \
                "Papan nama rumah '$hostname_param' siap dipasang"
    
    return 0
}

# Create IPC namespace for inter-process communication isolation
create_ipc_namespace() {
    local container_name=$1
    
    log_step 4 "Creating IPC namespace for container: $container_name" \
              "Seperti menyiapkan papan tulis keluarga pribadi untuk komunikasi internal"
    
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    create_directory "$ns_dir"
    
    log_info "Setting up isolated IPC namespace" \
             "Seperti setiap rumah punya papan tulis keluarga sendiri"
    
    # Create IPC namespace configuration
    cat > "$ns_dir/ipc.conf" << EOF
ipc_namespace_enabled=true
shared_memory_max=67108864
semaphore_max=32000
message_queue_max=16
EOF
    
    # Create IPC limits file
    cat > "$ns_dir/ipc_limits.conf" << EOF
# IPC Limits for container: $container_name
# Shared Memory: 64MB max
# Semaphores: 32000 max
# Message Queues: 16 max
kernel.shmmax=67108864
kernel.sem=250 32000 32 128
kernel.msgmax=8192
kernel.msgmnb=16384
kernel.msgmni=16
EOF
    
    log_success "IPC namespace configuration prepared" \
                "Papan tulis keluarga pribadi siap untuk komunikasi internal rumah"
    
    return 0
}

# Create user namespace with proper user mapping
create_user_namespace() {
    local container_name=$1
    local host_uid=${2:-$(id -u)}
    local host_gid=${3:-$(id -g)}
    
    log_step 5 "Creating user namespace for container: $container_name" \
              "Seperti mengatur sistem keanggotaan keluarga yang terpisah dari kompleks"
    
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    create_directory "$ns_dir"
    
    log_info "Setting up user namespace with UID/GID mapping" \
             "Seperti setiap rumah punya sistem keanggotaan keluarga sendiri"
    
    # Create user namespace configuration
    cat > "$ns_dir/user.conf" << EOF
user_namespace_enabled=true
host_uid=$host_uid
host_gid=$host_gid
container_uid=0
container_gid=0
uid_map=0 $host_uid 1
gid_map=0 $host_gid 1
EOF
    
    # Create user mapping files (will be applied during container start)
    echo "0 $host_uid 1" > "$ns_dir/uid_map"
    echo "0 $host_gid 1" > "$ns_dir/gid_map"
    
    # Create container passwd and group files (ensure etc directory exists)
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    create_directory "$container_rootfs/etc"
    cat > "$container_rootfs/etc/passwd" << EOF
root:x:0:0:Container Root:/root:/bin/sh
nobody:x:65534:65534:Nobody:/nonexistent:/bin/false
EOF
    
    cat > "$container_rootfs/etc/group" << EOF
root:x:0:
nobody:x:65534:
EOF
    
    log_success "User namespace configuration prepared" \
                "Sistem keanggotaan keluarga rumah siap dengan mapping yang aman"
    
    return 0
}

# Setup all namespaces for a container
setup_container_namespaces() {
    local container_name=$1
    local hostname=${2:-$container_name}
    local host_uid=${3:-$(id -u)}
    local host_gid=${4:-$(id -g)}
    
    log_info "Setting up all namespaces for container: $container_name" \
             "Seperti RT yang menyiapkan semua sistem untuk rumah baru"
    
    # Create PID namespace
    if ! create_pid_namespace "$container_name"; then
        log_error "Failed to create PID namespace" \
                  "Gagal menyiapkan sistem penomoran keluarga"
        return 1
    fi
    
    # Create mount namespace
    if ! create_mount_namespace "$container_name"; then
        log_error "Failed to create mount namespace" \
                  "Gagal menyiapkan rak buku pribadi rumah"
        return 1
    fi
    
    # Create UTS namespace
    if ! create_uts_namespace "$container_name" "$hostname"; then
        log_error "Failed to create UTS namespace" \
                  "Gagal memasang papan nama rumah"
        return 1
    fi
    
    # Create IPC namespace
    if ! create_ipc_namespace "$container_name"; then
        log_error "Failed to create IPC namespace" \
                  "Gagal menyiapkan papan tulis keluarga"
        return 1
    fi
    
    # Create user namespace
    if ! create_user_namespace "$container_name" "$host_uid" "$host_gid"; then
        log_error "Failed to create user namespace" \
                  "Gagal mengatur sistem keanggotaan keluarga"
        return 1
    fi
    
    # Mark namespaces as active for cleanup tracking
    set_container_namespace "$container_name" "pid,mount,uts,ipc,user"
    
    log_success "All namespaces configured for container: $container_name" \
                "Semua sistem rumah siap - penomoran keluarga, rak buku, nama rumah, papan tulis, dan keanggotaan"
    
    return 0
}

# =============================================================================
# NETWORK NAMESPACE AND CONTAINER COMMUNICATION
# =============================================================================

# Global network tracking for cleanup
# Using associative arrays for proper container tracking
declare -A ACTIVE_NETWORKS
declare -A CONTAINER_IPS
NEXT_IP_OCTET=2

# Helper functions for network associative array management
set_container_network() {
    local container_name=$1
    local network_info=$2
    ACTIVE_NETWORKS["$container_name"]="$network_info"
}

get_container_network() {
    local container_name=$1
    if [[ -n "${ACTIVE_NETWORKS[$container_name]:-}" ]]; then
        echo "${ACTIVE_NETWORKS[$container_name]}"
        return 0
    fi
    return 1
}

unset_container_network() {
    local container_name=$1
    unset ACTIVE_NETWORKS["$container_name"]
}

set_container_ip() {
    local container_name=$1
    local ip=$2
    CONTAINER_IPS["$container_name"]="$ip"
}

get_container_ip() {
    local container_name=$1
    if [[ -n "${CONTAINER_IPS[$container_name]:-}" ]]; then
        echo "${CONTAINER_IPS[$container_name]}"
        return 0
    fi
    return 1
}

unset_container_ip() {
    local container_name=$1
    unset CONTAINER_IPS["$container_name"]
}

is_ip_in_use() {
    local ip=$1
    for container_name in "${!CONTAINER_IPS[@]}"; do
        if [[ "${CONTAINER_IPS[$container_name]}" == "$ip" ]]; then
            return 0
        fi
    done
    return 1
}

# Get next available IP address in the container network
get_next_container_ip() {
    local base_ip="10.0.0"
    local octet=$NEXT_IP_OCTET
    
    # Check if IP is already in use
    while is_ip_in_use "$base_ip.$octet"; do
        ((octet++))
        if [[ $octet -gt 254 ]]; then
            log_error "No available IP addresses in container network" \
                      "Seperti kompleks sudah penuh, tidak ada nomor rumah yang tersisa"
            return 1
        fi
    done
    
    NEXT_IP_OCTET=$((octet + 1))
    echo "$base_ip.$octet"
}

# =============================================================================
# CONTAINER LIFECYCLE MANAGEMENT
# =============================================================================

# Container metadata structure and management
save_container_metadata() {
    local container_name=$1
    local memory_mb=$2
    local cpu_percent=$3
    local ip_address=$4
    local status=${5:-"created"}
    
    log_debug "Saving metadata for container: $container_name" \
              "Seperti RT mencatat data lengkap rumah baru di buku administrasi"
    
    local metadata_file="$CONTAINERS_DIR/$container_name/config.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create metadata JSON
    cat > "$metadata_file" << EOF
{
  "name": "$container_name",
  "created": "$timestamp",
  "status": "$status",
  "resources": {
    "memory_mb": $memory_mb,
    "cpu_percentage": $cpu_percent
  },
  "network": {
    "ip_address": "$ip_address",
    "veth_host": "$(generate_veth_names "$container_name" | cut -d' ' -f1)",
    "veth_container": "$(generate_veth_names "$container_name" | cut -d' ' -f2)"
  },
  "namespaces": {
    "pid": "",
    "net": "",
    "mnt": "",
    "uts": "",
    "ipc": "",
    "user": ""
  },
  "cgroups": {
    "memory": "/sys/fs/cgroup/memory/container-$container_name",
    "cpu": "/sys/fs/cgroup/cpu/container-$container_name"
  },
  "pid": 0,
  "rootfs": "$CONTAINERS_DIR/$container_name/rootfs",
  "logs": "$CONTAINERS_DIR/$container_name/logs"
}
EOF
    
    log_debug "Container metadata saved successfully" \
              "Data rumah berhasil dicatat dalam administrasi RT"
    return 0
}

# Load container metadata
load_container_metadata() {
    local container_name=$1
    local metadata_file="$CONTAINERS_DIR/$container_name/config.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        log_error "Container metadata not found: $container_name" \
                  "Data rumah tidak ditemukan dalam catatan RT"
        return 1
    fi
    
    log_debug "Loading metadata for container: $container_name" \
              "Seperti RT membaca data rumah dari buku administrasi"
    
    # Export metadata as environment variables for easy access
    eval "$(cat "$metadata_file" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'CONTAINER_NAME=\"{data[\"name\"]}\"')
print(f'CONTAINER_STATUS=\"{data[\"status\"]}\"')
print(f'CONTAINER_MEMORY_MB={data[\"resources\"][\"memory_mb\"]}')
print(f'CONTAINER_CPU_PERCENT={data[\"resources\"][\"cpu_percentage\"]}')
print(f'CONTAINER_IP=\"{data[\"network\"][\"ip_address\"]}\"')
print(f'CONTAINER_PID={data[\"pid\"]}')
print(f'CONTAINER_ROOTFS=\"{data[\"rootfs\"]}\"')
print(f'CONTAINER_LOGS=\"{data[\"logs\"]}\"')
" 2>/dev/null || echo 'CONTAINER_LOAD_ERROR=1')"
    
    if [[ -n "${CONTAINER_LOAD_ERROR:-}" ]]; then
        log_error "Failed to parse container metadata" \
                  "Gagal membaca data rumah dari catatan RT"
        return 1
    fi
    
    log_debug "Container metadata loaded successfully" \
              "Data rumah berhasil dimuat dari administrasi RT"
    return 0
}

# Update container status in metadata
update_container_status() {
    local container_name=$1
    local new_status=$2
    local pid=${3:-0}
    
    local metadata_file="$CONTAINERS_DIR/$container_name/config.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        log_error "Cannot update status: container metadata not found" \
                  "Tidak bisa update status: data rumah tidak ditemukan"
        return 1
    fi
    
    log_debug "Updating container status: $container_name -> $new_status" \
              "Seperti RT mengupdate status rumah di buku administrasi"
    
    # Use python to update JSON (more reliable than sed for JSON)
    python3 -c "
import json
with open('$metadata_file', 'r') as f:
    data = json.load(f)
data['status'] = '$new_status'
data['pid'] = $pid
with open('$metadata_file', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || {
        log_error "Failed to update container status" \
                  "Gagal mengupdate status rumah di catatan RT"
        return 1
    }
    
    log_debug "Container status updated successfully" \
              "Status rumah berhasil diupdate di administrasi RT"
    return 0
}

# Create container with all components integrated
create_container() {
    local container_name=$1
    local memory_mb=${2:-$DEFAULT_MEMORY_MB}
    local cpu_percent=${3:-$DEFAULT_CPU_PERCENT}
    local hostname=${4:-$container_name}
    
    # Initialize comprehensive error handling
    init_error_handling
    set_operation_context "create_container" "$container_name"
    
    log_step 1 "Creating container: $container_name" \
              "Seperti RT membangun rumah baru lengkap dengan semua fasilitas"
    
    # Validate system state before starting
    if ! validate_system_state "create_container"; then
        log_error "System validation failed for container creation" \
                  "Sistem tidak siap untuk membangun rumah baru"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Validate inputs with enhanced error reporting
    if ! validate_container_name "$container_name"; then
        clear_operation_context "create_container"
        return 1
    fi
    
    if ! validate_memory_limit "$memory_mb"; then
        clear_operation_context "create_container"
        return 1
    fi
    
    if ! validate_cpu_percentage "$cpu_percent"; then
        clear_operation_context "create_container"
        return 1
    fi
    
    # Check if container already exists
    if container_exists "$container_name"; then
        log_error "Container already exists: $container_name" \
                  "Rumah dengan nama tersebut sudah ada di kompleks"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Create container directory structure with rollback capability
    log_info "Creating container directory structure" \
             "Seperti menyiapkan fondasi dan struktur rumah baru"
    
    local container_dir="$CONTAINERS_DIR/$container_name"
    
    if ! create_directory "$container_dir"; then
        log_error "Failed to create container directory: $container_dir" \
                  "Gagal menyiapkan lahan untuk rumah"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Add rollback action for directory cleanup
    add_rollback_action "remove_container_dir" "rm -rf '$container_dir'" "Remove container directory"
    
    if ! create_directory "$container_dir/rootfs"; then
        log_error "Failed to create container rootfs directory" \
                  "Gagal menyiapkan struktur dasar rumah"
        execute_rollback "create_container"
        clear_operation_context "create_container"
        return 1
    fi
    
    if ! create_directory "$container_dir/logs"; then
        log_error "Failed to create container logs directory" \
                  "Gagal menyiapkan tempat catatan rumah"
        execute_rollback "create_container"
        clear_operation_context "create_container"
        return 1
    fi
    
    if ! create_directory "$container_dir/namespaces"; then
        log_error "Failed to create container namespaces directory" \
                  "Gagal menyiapkan tempat konfigurasi sistem rumah"
        execute_rollback "create_container"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Get IP address for container with validation
    log_info "Allocating IP address for container" \
             "Seperti RT mengalokasikan nomor telepon untuk rumah"
    
    local container_ip
    if ! container_ip=$(get_next_container_ip); then
        log_error "Failed to allocate IP address for container" \
                  "Gagal mendapatkan nomor telepon rumah"
        execute_rollback "create_container"
        clear_operation_context "create_container"
        return 1
    fi
    
    log_info "Allocated IP address: $container_ip" \
             "Nomor telepon yang dialokasikan: $container_ip"
    
    # Save initial metadata with error handling
    if ! save_container_metadata "$container_name" "$memory_mb" "$cpu_percent" "$container_ip" "creating"; then
        log_error "Failed to save container metadata" \
                  "Gagal mencatat data rumah di administrasi RT"
        execute_rollback "create_container"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Add rollback action for metadata cleanup
    add_rollback_action "remove_metadata" "rm -f '$container_dir/config.json'" "Remove container metadata"
    
    # Reserve IP address
    set_container_ip "$container_name" "$container_ip"
    add_rollback_action "release_ip" "unset_container_ip '$container_name'" "Release IP address"
    
    # Setup busybox for the container with error handling
    log_info "Setting up busybox for container" \
             "Seperti menyiapkan peralatan dasar untuk rumah baru"
    
    if ! setup_busybox "$container_name"; then
        log_error "Failed to setup busybox for container" \
                  "Gagal menyiapkan peralatan dasar rumah"
        execute_rollback "create_container"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Add rollback action for busybox cleanup
    add_rollback_action "cleanup_busybox" "rm -rf '$container_dir/rootfs/bin'" "Remove busybox setup"
    
    # Setup namespaces with comprehensive error handling
    log_info "Setting up namespaces for container" \
             "Seperti mengatur sistem internal rumah (penomoran, rak buku, nama, dll)"
    
    set_operation_context "setup_namespace" "$container_name"
    
    if ! setup_container_namespaces "$container_name" "$hostname"; then
        log_error "Failed to setup namespaces for container" \
                  "Gagal mengatur sistem internal rumah"
        execute_rollback "create_container"
        clear_operation_context "setup_namespace"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Add rollback action for namespace cleanup
    add_rollback_action "cleanup_namespaces" "cleanup_container_namespaces '$container_name'" "Remove namespaces"
    clear_operation_context "setup_namespace"
    
    # Setup network namespace with error handling
    log_info "Setting up network for container" \
             "Seperti memasang sambungan telepon rumah"
    
    set_operation_context "setup_network" "$container_name"
    
    if ! create_container_network "$container_name" "$container_ip"; then
        log_error "Failed to setup network for container" \
                  "Gagal memasang sambungan telepon rumah"
        execute_rollback "create_container"
        clear_operation_context "setup_network"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Add rollback action for network cleanup
    add_rollback_action "cleanup_network" "cleanup_container_network '$container_name'" "Remove network setup"
    clear_operation_context "setup_network"
    
    # Setup cgroups for resource limiting with error handling
    log_info "Setting up resource limits for container" \
             "Seperti mengatur pembatasan listrik dan air rumah"
    
    set_operation_context "setup_cgroup" "$container_name"
    
    if ! create_container_cgroup "$container_name" "$memory_mb" "$cpu_percent"; then
        log_error "Failed to setup resource limits for container" \
                  "Gagal mengatur pembatasan listrik dan air rumah"
        execute_rollback "create_container"
        clear_operation_context "setup_cgroup"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Add rollback action for cgroup cleanup
    add_rollback_action "cleanup_cgroups" "cleanup_container_cgroups '$container_name'" "Remove resource limits"
    clear_operation_context "setup_cgroup"
    
    # Update status to created with error handling
    if ! update_container_status "$container_name" "created"; then
        log_error "Failed to update container status" \
                  "Gagal mengupdate status rumah"
        execute_rollback "create_container"
        clear_operation_context "create_container"
        return 1
    fi
    
    # Clear rollback stack since creation was successful
    ROLLBACK_STACK=()
    RECOVERY_ACTIONS=()
    
    clear_operation_context "create_container"
    
    log_success "Container created successfully: $container_name" \
                "Rumah '$container_name' berhasil dibangun lengkap dengan semua fasilitas"
    
    # Show container information with enhanced details
    echo ""
    echo -e "${COLOR_GREEN}=== Container Information ===${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Name: $container_name${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Memory Limit: ${memory_mb}MB${COLOR_RESET}"
    echo -e "${COLOR_GREEN}CPU Limit: ${cpu_percent}%${COLOR_RESET}"
    echo -e "${COLOR_GREEN}IP Address: $container_ip${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Hostname: $hostname${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Status: created${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Error Handling: Enabled${COLOR_RESET}"
    echo -e "${COLOR_GREEN}============================${COLOR_RESET}"
    echo ""
    
    log_info "Container is ready to be started with: ./rt.sh run-container $container_name" \
             "Rumah siap ditempati dengan perintah: ./rt.sh run-container $container_name"
    
    return 0
}

# Start container process with busybox integration
start_container_process() {
    local container_name=$1
    local command=${2:-"sh"}
    local interactive=${3:-true}
    
    log_step 1 "Starting container process: $container_name" \
              "Seperti menghidupkan rumah dan memulai kehidupan keluarga"
    
    # Load container metadata
    if ! load_container_metadata "$container_name"; then
        return 1
    fi
    
    # Check if container is already running
    if container_is_running "$container_name"; then
        log_error "Container is already running: $container_name" \
                  "Rumah sudah dihuni dan aktif"
        return 1
    fi
    
    # Prepare container environment
    local container_rootfs="$CONTAINER_ROOTFS"
    local container_logs="$CONTAINER_LOGS"
    local log_file="$container_logs/container.log"
    local pid_file="$CONTAINERS_DIR/$container_name/container.pid"
    
    # Create log file
    create_directory "$container_logs"
    touch "$log_file"
    
    log_info "Preparing container environment" \
             "Seperti menyiapkan rumah sebelum keluarga pindah masuk"
    
    # Mount essential filesystems in the container
    if ! setup_container_mounts "$container_name"; then
        log_error "Failed to setup container mounts" \
                  "Gagal menyiapkan sistem file rumah"
        return 1
    fi
    
    # Apply cgroup limits
    log_info "Applying resource limits" \
             "Seperti mengaktifkan pembatasan listrik dan air rumah"
    
    # Start the container process in all namespaces
    log_info "Starting container with busybox" \
             "Seperti keluarga mulai menempati rumah dengan Ayah sebagai kepala keluarga (PID 1)"
    
    # Build unshare command with all namespaces
    local unshare_cmd="unshare"
    unshare_cmd+=" --pid --fork"           # PID namespace with fork
    unshare_cmd+=" --mount"                # Mount namespace
    unshare_cmd+=" --uts"                  # UTS namespace
    unshare_cmd+=" --ipc"                  # IPC namespace
    unshare_cmd+=" --net"                  # Network namespace
    unshare_cmd+=" --user --map-root-user" # User namespace with root mapping
    
    # Create container startup script
    local startup_script="$CONTAINERS_DIR/$container_name/startup.sh"
    cat > "$startup_script" << EOF
#!/bin/bash
set -e

# This script runs inside the container namespaces
# It sets up the container environment and starts busybox

# Set hostname
hostname "$hostname" 2>/dev/null || true

# Mount essential filesystems
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t tmpfs tmpfs /tmp 2>/dev/null || true

# Create essential device nodes
mknod -m 666 /dev/null c 1 3 2>/dev/null || true
mknod -m 666 /dev/zero c 1 5 2>/dev/null || true
mknod -m 644 /dev/random c 1 8 2>/dev/null || true
mknod -m 644 /dev/urandom c 1 9 2>/dev/null || true

# Change to container root
cd /

# Set environment variables
export PATH="/bin:/sbin:/usr/bin:/usr/sbin"
export HOME="/root"
export USER="root"
export SHELL="/bin/sh"
export TERM="\${TERM:-xterm}"

# Start busybox shell or specified command
if [[ "$interactive" == "true" ]]; then
    echo "🏠 Welcome to container: $container_name"
    echo "📍 IP Address: $CONTAINER_IP"
    echo "💾 Memory Limit: ${CONTAINER_MEMORY_MB}MB"
    echo "⚡ CPU Limit: ${CONTAINER_CPU_PERCENT}%"
    echo "🏘️  Analogi: Selamat datang di rumah Anda di kompleks RT!"
    echo ""
    exec /bin/busybox $command
else
    exec /bin/busybox $command
fi
EOF
    
    chmod +x "$startup_script"
    
    # Start container process
    log_info "Launching container process" \
             "Seperti keluarga resmi menempati rumah baru"
    
    # Use setsid to create new session and avoid terminal issues
    if [[ "$interactive" == "true" ]]; then
        # Interactive mode - run in foreground
        $unshare_cmd chroot "$container_rootfs" /startup.sh &
        local container_pid=$!
    else
        # Non-interactive mode - run in background
        $unshare_cmd chroot "$container_rootfs" /startup.sh > "$log_file" 2>&1 &
        local container_pid=$!
    fi
    
    # Save container PID
    echo "$container_pid" > "$pid_file"
    
    # Add process to cgroups
    if ! add_process_to_container_cgroup "$container_name" "$container_pid"; then
        log_error "Failed to add process to cgroups" \
                  "Gagal menerapkan pembatasan listrik dan air"
        kill "$container_pid" 2>/dev/null || true
        return 1
    fi
    
    # Update container status
    if ! update_container_status "$container_name" "running" "$container_pid"; then
        log_error "Failed to update container status" \
                  "Gagal mengupdate status rumah"
        kill "$container_pid" 2>/dev/null || true
        return 1
    fi
    
    # Wait a moment to ensure container started properly
    sleep 1
    
    if ! kill -0 "$container_pid" 2>/dev/null; then
        log_error "Container process failed to start" \
                  "Proses rumah gagal dimulai"
        update_container_status "$container_name" "failed" 0
        return 1
    fi
    
    log_success "Container started successfully: $container_name (PID: $container_pid)" \
                "Rumah '$container_name' berhasil dihuni keluarga dengan Ayah sebagai kepala keluarga"
    
    if [[ "$interactive" == "true" ]]; then
        # Wait for container process to finish
        wait "$container_pid"
        local exit_code=$?
        
        # Update status when container exits
        update_container_status "$container_name" "stopped" 0
        
        log_info "Container exited with code: $exit_code" \
                 "Keluarga selesai menggunakan rumah dengan kode: $exit_code"
        
        return $exit_code
    else
        log_info "Container running in background (PID: $container_pid)" \
                 "Rumah aktif di latar belakang dengan kepala keluarga PID: $container_pid"
        return 0
    fi
}

# Setup container mounts (called inside container startup)
setup_container_mounts() {
    local container_name=$1
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    
    log_debug "Setting up container mounts for: $container_name" \
              "Seperti memasang rak-rak dan fasilitas di dalam rumah"
    
    # Ensure mount points exist
    create_directory "$container_rootfs/proc"
    create_directory "$container_rootfs/sys"
    create_directory "$container_rootfs/dev"
    create_directory "$container_rootfs/tmp"
    
    # Copy startup script into container
    cp "$CONTAINERS_DIR/$container_name/startup.sh" "$container_rootfs/startup.sh"
    chmod +x "$container_rootfs/startup.sh"
    
    return 0
}

# Monitor container process
monitor_container_process() {
    local container_name=$1
    local show_logs=${2:-false}
    
    log_info "Monitoring container: $container_name" \
             "Seperti RT memantau aktivitas rumah"
    
    # Load container metadata
    if ! load_container_metadata "$container_name"; then
        return 1
    fi
    
    local pid_file="$CONTAINERS_DIR/$container_name/container.pid"
    local log_file="$CONTAINER_LOGS/container.log"
    
    if [[ ! -f "$pid_file" ]]; then
        log_error "Container PID file not found" \
                  "File PID rumah tidak ditemukan"
        return 1
    fi
    
    local container_pid=$(cat "$pid_file")
    
    # Check if process is running
    if ! kill -0 "$container_pid" 2>/dev/null; then
        log_warn "Container process not running (PID: $container_pid)" \
                 "Proses rumah tidak aktif"
        update_container_status "$container_name" "stopped" 0
        return 1
    fi
    
    # Show process information
    echo "=== Container Process Information ==="
    echo "Container: $container_name"
    echo "PID: $container_pid"
    echo "Status: $CONTAINER_STATUS"
    echo "Memory Limit: ${CONTAINER_MEMORY_MB}MB"
    echo "CPU Limit: ${CONTAINER_CPU_PERCENT}%"
    echo "IP Address: $CONTAINER_IP"
    
    # Show resource usage
    if [[ -f "/proc/$container_pid/status" ]]; then
        local memory_kb=$(grep "VmRSS" "/proc/$container_pid/status" | awk '{print $2}')
        local memory_mb=$((memory_kb / 1024))
        echo "Current Memory Usage: ${memory_mb}MB"
    fi
    
    echo "====================================="
    
    # Show logs if requested
    if [[ "$show_logs" == "true" ]] && [[ -f "$log_file" ]]; then
        echo ""
        echo "=== Container Logs ==="
        tail -20 "$log_file"
        echo "======================"
    fi
    
    return 0
}

# Delete container with comprehensive cleanup
delete_container() {
    local container_name=$1
    local force=${2:-false}
    
    # Initialize comprehensive error handling
    init_error_handling
    set_operation_context "delete_container" "$container_name"
    
    log_step 1 "Deleting container: $container_name" \
              "Seperti RT membongkar rumah dan membersihkan semua fasilitas"
    
    # Validate container name
    if ! validate_container_name "$container_name"; then
        clear_operation_context "delete_container"
        return 1
    fi
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_error "Container does not exist: $container_name" \
                  "Rumah dengan nama tersebut tidak ada di kompleks"
        clear_operation_context "delete_container"
        return 1
    fi
    
    # Load container metadata with error handling
    local container_dir="$CONTAINERS_DIR/$container_name"
    local config_file="$container_dir/config.json"
    local container_ip=""
    
    if [[ -f "$config_file" ]]; then
        container_ip=$(grep -o '"ip_address":"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f4 || echo "")
        log_debug "Loaded container IP: $container_ip" \
                  "Memuat nomor telepon rumah: $container_ip"
    else
        log_warn "Container metadata not found, proceeding with cleanup" \
                 "Data rumah tidak ditemukan, melanjutkan pembersihan"
    fi
    
    # Check if container is running and handle appropriately
    local container_was_running=false
    if container_is_running "$container_name"; then
        container_was_running=true
        
        if [[ "$force" == "true" ]]; then
            log_info "Force stopping running container" \
                     "Seperti RT menghentikan paksa aktivitas rumah"
            
            if ! stop_container_force "$container_name"; then
                log_error "Failed to stop running container" \
                          "Gagal menghentikan aktivitas rumah"
                # Continue with cleanup anyway in force mode
                log_warn "Continuing with cleanup despite stop failure" \
                         "Melanjutkan pembersihan meskipun gagal menghentikan"
            fi
        else
            log_error "Container is still running. Use --force to stop and delete" \
                      "Rumah masih aktif. Gunakan --force untuk menghentikan dan menghapus"
            clear_operation_context "delete_container"
            return 1
        fi
    fi
    
    # Track cleanup progress for potential rollback
    local cleanup_steps=()
    local cleanup_errors=()
    
    # Cleanup network with error tracking
    log_info "Cleaning up container network" \
             "Seperti memutus sambungan telepon rumah"
    
    if cleanup_container_network "$container_name"; then
        cleanup_steps+=("network")
        log_debug "Network cleanup successful"
    else
        cleanup_errors+=("network_cleanup_failed")
        log_warn "Network cleanup failed, continuing..." \
                 "Gagal membersihkan jaringan, melanjutkan..."
    fi
    
    # Cleanup cgroups with error tracking
    log_info "Cleaning up resource limits" \
             "Seperti menghapus pembatasan listrik dan air rumah"
    
    if cleanup_container_cgroups "$container_name"; then
        cleanup_steps+=("cgroups")
        log_debug "Cgroups cleanup successful"
    else
        cleanup_errors+=("cgroups_cleanup_failed")
        log_warn "Cgroups cleanup failed, continuing..." \
                 "Gagal membersihkan pembatasan resource, melanjutkan..."
    fi
    
    # Cleanup namespaces with error tracking
    log_info "Cleaning up namespaces" \
             "Seperti menghapus sistem internal rumah"
    
    if cleanup_container_namespaces "$container_name"; then
        cleanup_steps+=("namespaces")
        log_debug "Namespaces cleanup successful"
    else
        cleanup_errors+=("namespaces_cleanup_failed")
        log_warn "Namespaces cleanup failed, continuing..." \
                 "Gagal membersihkan namespace, melanjutkan..."
    fi
    
    # Release IP address with error handling
    if [[ -n "$container_ip" ]]; then
        log_info "Releasing IP address: $container_ip" \
                 "Mengembalikan nomor telepon: $container_ip"
        
        if unset_container_ip "$container_name" 2>/dev/null; then
            cleanup_steps+=("ip_release")
            log_debug "IP address released successfully"
        else
            cleanup_errors+=("ip_release_failed")
            log_warn "Failed to release IP address, continuing..." \
                     "Gagal mengembalikan nomor telepon, melanjutkan..."
        fi
    fi
    
    # Remove container directory with comprehensive cleanup
    log_info "Removing container files" \
             "Seperti membersihkan sisa-sisa rumah"
    
    if [[ -d "$container_dir" ]]; then
        # Unmount any remaining mounts with error handling
        local mount_points=("/proc" "/sys" "/dev/pts" "/dev" "/tmp")
        for mount_point in "${mount_points[@]}"; do
            local full_path="$container_dir/rootfs$mount_point"
            if mountpoint -q "$full_path" 2>/dev/null; then
                log_debug "Unmounting: $full_path"
                if ! umount "$full_path" 2>/dev/null; then
                    log_warn "Failed to unmount: $full_path" \
                             "Gagal melepas mount: $mount_point"
                    # Try force unmount
                    umount -f "$full_path" 2>/dev/null || true
                fi
            fi
        done
        
        # Remove directory with retry mechanism
        local retry_count=0
        local max_retries=3
        
        while [[ $retry_count -lt $max_retries ]]; do
            if rm -rf "$container_dir" 2>/dev/null; then
                cleanup_steps+=("directory_removal")
                log_debug "Container directory removed successfully"
                break
            else
                retry_count=$((retry_count + 1))
                log_warn "Failed to remove container directory (attempt $retry_count/$max_retries)" \
                         "Gagal menghapus direktori rumah (percobaan $retry_count/$max_retries)"
                
                if [[ $retry_count -lt $max_retries ]]; then
                    sleep 1
                    # Try to kill any remaining processes that might be holding files
                    if [[ "$container_was_running" == "true" ]]; then
                        pkill -f "$container_name" 2>/dev/null || true
                    fi
                else
                    cleanup_errors+=("directory_removal_failed")
                    log_error "Failed to remove container directory after $max_retries attempts" \
                              "Gagal menghapus direktori rumah setelah $max_retries percobaan"
                fi
            fi
        done
    fi
    
    # Remove from active tracking
    unset_container_namespace "$container_name" 2>/dev/null || true
    
    # Report cleanup results
    local total_steps=${#cleanup_steps[@]}
    local total_errors=${#cleanup_errors[@]}
    
    clear_operation_context "delete_container"
    
    if [[ $total_errors -eq 0 ]]; then
        log_success "Container deleted successfully: $container_name" \
                    "Rumah '$container_name' berhasil dibongkar dan dibersihkan dari kompleks"
        
        echo -e "\n${COLOR_GREEN}📋 Cleanup Summary:${COLOR_RESET}"
        echo -e "${COLOR_GREEN}├── Steps completed: $total_steps${COLOR_RESET}"
        echo -e "${COLOR_GREEN}├── Errors: $total_errors${COLOR_RESET}"
        echo -e "${COLOR_GREEN}└── Status: Complete${COLOR_RESET}"
        
        return 0
    else
        log_warn "Container deletion completed with $total_errors errors: $container_name" \
                 "Penghapusan rumah selesai dengan $total_errors masalah: $container_name"
        
        echo -e "\n${COLOR_YELLOW}📋 Cleanup Summary:${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}├── Steps completed: $total_steps${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}├── Errors: $total_errors${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}├── Failed steps: ${cleanup_errors[*]}${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}└── Status: Partial${COLOR_RESET}"
        
        echo -e "\n${COLOR_CYAN}💡 Troubleshooting:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}├── Run: $0 debug containers${COLOR_RESET}"
        echo -e "${COLOR_CYAN}├── Check: $0 recover-state${COLOR_RESET}"
        echo -e "${COLOR_CYAN}└── Manual cleanup: $0 cleanup-all${COLOR_RESET}"
        
        return 1
    fi
}

# Stop container forcefully
stop_container_force() {
    local container_name=$1
    
    log_info "Force stopping container: $container_name" \
             "Seperti RT menghentikan paksa aktivitas rumah"
    
    local pid_file="$CONTAINERS_DIR/$container_name/container.pid"
    
    if [[ -f "$pid_file" ]]; then
        local container_pid=$(cat "$pid_file")
        
        if kill -0 "$container_pid" 2>/dev/null; then
            # Try graceful shutdown first
            log_debug "Sending SIGTERM to container process" \
                      "Memberikan peringatan untuk menghentikan aktivitas rumah"
            kill -TERM "$container_pid" 2>/dev/null || true
            
            # Wait a few seconds
            sleep 3
            
            # Force kill if still running
            if kill -0 "$container_pid" 2>/dev/null; then
                log_debug "Sending SIGKILL to container process" \
                          "Menghentikan paksa aktivitas rumah"
                kill -KILL "$container_pid" 2>/dev/null || true
            fi
            
            # Wait for process to die
            local count=0
            while kill -0 "$container_pid" 2>/dev/null && [[ $count -lt 10 ]]; do
                sleep 1
                ((count++))
            done
        fi
        
        # Remove PID file
        rm -f "$pid_file"
    fi
    
    # Update status
    update_container_status "$container_name" "stopped" 0 || true
    
    return 0
}

# Cleanup failed container creation
cleanup_failed_container() {
    local container_name=$1
    
    log_warn "Cleaning up failed container creation: $container_name" \
             "Seperti RT membersihkan sisa pembangunan rumah yang gagal"
    
    # Stop any running processes
    stop_container_force "$container_name" 2>/dev/null || true
    
    # Cleanup network
    cleanup_container_network "$container_name" 2>/dev/null || true
    
    # Cleanup cgroups
    cleanup_container_cgroups "$container_name" 2>/dev/null || true
    
    # Remove IP reservation
    unset_container_ip "$container_name"
    
    # Remove container directory
    local container_dir="$CONTAINERS_DIR/$container_name"
    if [[ -d "$container_dir" ]]; then
        rm -rf "$container_dir" 2>/dev/null || true
    fi
    
    # Remove from tracking
    unset_container_namespace "$container_name" 2>/dev/null || true
    unset_container_network "$container_name" 2>/dev/null || true
    
    return 0
}

get_next_container_ip() {
    local ip="10.0.0.$NEXT_IP_OCTET"
    ((NEXT_IP_OCTET++))
    echo "$ip"
}

# Create network namespace for container
create_network_namespace() {
    local container_name=$1
    
    log_step 1 "Creating network namespace for container: $container_name" \
              "Seperti menyiapkan sistem telepon rumah dengan nomor khusus"
    
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    create_directory "$ns_dir"
    
    # Create network namespace
    if ! ip netns add "container-$container_name" 2>/dev/null; then
        # Check if namespace already exists
        if ip netns list | grep -q "container-$container_name"; then
            log_warn "Network namespace already exists for container: $container_name" \
                     "Seperti nomor telepon rumah sudah terdaftar sebelumnya"
        else
            log_error "Failed to create network namespace" \
                      "Gagal mendaftarkan nomor telepon rumah"
            return 1
        fi
    fi
    
    log_info "Network namespace created: container-$container_name" \
             "Seperti nomor telepon rumah berhasil didaftarkan"
    
    # Configure loopback interface in the namespace
    if ! ip netns exec "container-$container_name" ip link set lo up; then
        log_error "Failed to configure loopback interface" \
                  "Gagal mengaktifkan telepon internal rumah"
        return 1
    fi
    
    # Save network namespace configuration
    cat > "$ns_dir/network.conf" << EOF
network_namespace_enabled=true
namespace_name=container-$container_name
loopback_configured=true
created_at=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # Track active network namespace
    ACTIVE_NETWORKS["$container_name"]="container-$container_name"
    
    log_success "Network namespace configured with loopback interface" \
                "Sistem telepon rumah siap dengan jalur internal aktif"
    
    return 0
}

# Generate consistent short veth names (max 15 chars for Linux interface names)
generate_veth_names() {
    local container_name=$1
    local name_hash=$(echo "$container_name" | md5sum | cut -c1-6)
    echo "veth-h${name_hash}" "veth-c${name_hash}"
}

# Create veth pair for container-to-container communication
create_veth_pair() {
    local container_name=$1
    local peer_container=${2:-""}
    
    log_step 2 "Creating veth pair for container: $container_name" \
              "Seperti memasang kabel telepon khusus untuk komunikasi antar rumah"
    
    # Generate short veth names using helper function
    local veth_names=($(generate_veth_names "$container_name"))
    local veth_host="${veth_names[0]}"
    local veth_container="${veth_names[1]}"
    
    # Create veth pair
    if ! ip link add "$veth_host" type veth peer name "$veth_container"; then
        log_error "Failed to create veth pair" \
                  "Gagal memasang kabel telepon antar rumah"
        return 1
    fi
    
    log_info "Veth pair created: $veth_host <-> $veth_container" \
             "Seperti kabel telepon terpasang antara sentral dan rumah"
    
    # Move container end to the container's network namespace
    if ! ip link set "$veth_container" netns "container-$container_name"; then
        log_error "Failed to move veth to container namespace" \
                  "Gagal memasang ujung kabel ke dalam rumah"
        # Cleanup on failure
        ip link delete "$veth_host" 2>/dev/null
        return 1
    fi
    
    # Bring up the host end
    if ! ip link set "$veth_host" up; then
        log_error "Failed to bring up host veth interface" \
                  "Gagal mengaktifkan ujung kabel di sentral"
        return 1
    fi
    
    # Bring up the container end
    if ! ip netns exec "container-$container_name" ip link set "$veth_container" up; then
        log_error "Failed to bring up container veth interface" \
                  "Gagal mengaktifkan ujung kabel di dalam rumah"
        return 1
    fi
    
    # Save veth configuration
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    cat >> "$ns_dir/network.conf" << EOF
veth_host=$veth_host
veth_container=$veth_container
veth_created=true
EOF
    
    log_success "Veth pair configured and activated" \
                "Kabel telepon terpasang dan siap untuk komunikasi"
    
    return 0
}

# Setup IP addressing with 10.0.0.x subnet
setup_container_ip() {
    local container_name=$1
    local container_ip=${2:-$(get_next_container_ip)}
    
    log_step 3 "Setting up IP address for container: $container_name" \
              "Seperti memberikan nomor telepon khusus: $container_ip"
    
    local veth_container="veth-${container_name}-c"
    local subnet_mask="24"
    
    # Assign IP address to container interface
    if ! ip netns exec "container-$container_name" ip addr add "${container_ip}/${subnet_mask}" dev "$veth_container"; then
        log_error "Failed to assign IP address to container" \
                  "Gagal memberikan nomor telepon ke rumah"
        return 1
    fi
    
    log_info "IP address assigned: $container_ip/$subnet_mask" \
             "Seperti nomor telepon $container_ip berhasil didaftarkan"
    
    # Store container IP for tracking
    set_container_ip "$container_name" "$container_ip"
    
    # Update network configuration
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    cat >> "$ns_dir/network.conf" << EOF
container_ip=$container_ip
subnet_mask=$subnet_mask
ip_configured=true
EOF
    
    log_success "Container IP configuration completed" \
                "Nomor telepon rumah siap untuk menerima dan melakukan panggilan"
    
    return 0
}

# Configure routing for direct container communication
setup_container_routing() {
    local container_name=$1
    
    log_step 4 "Setting up routing for container: $container_name" \
              "Seperti mengatur jalur telepon langsung antar rumah tanpa lewat sentral"
    
    local container_ip=$(get_container_ip "$container_name" 2>/dev/null || echo "")
    local veth_host="veth-${container_name}"
    
    if [[ -z "$container_ip" ]]; then
        log_error "Container IP not found for routing setup" \
                  "Nomor telepon rumah belum terdaftar untuk pengaturan jalur"
        return 1
    fi
    
    # Add route to container from host
    if ! ip route add "$container_ip/32" dev "$veth_host" 2>/dev/null; then
        # Route might already exist, check if it's correct
        if ip route show | grep -q "$container_ip.*$veth_host"; then
            log_info "Route to container already exists" \
                     "Jalur telepon ke rumah sudah terdaftar sebelumnya"
        else
            log_warn "Failed to add route to container, but continuing" \
                     "Jalur telepon mungkin sudah ada atau akan dibuat otomatis"
        fi
    fi
    
    # Setup default route in container (optional, for internet access)
    local gateway_ip="10.0.0.1"
    if ! ip netns exec "container-$container_name" ip route add default via "$gateway_ip" 2>/dev/null; then
        log_debug "Default route setup skipped (not required for container-to-container communication)" \
                  "Jalur ke luar kompleks tidak diperlukan untuk komunikasi antar rumah"
    fi
    
    # Update network configuration
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    cat >> "$ns_dir/network.conf" << EOF
routing_configured=true
host_route_added=true
gateway_ip=$gateway_ip
EOF
    
    log_success "Container routing configured" \
                "Jalur komunikasi langsung antar rumah siap digunakan"
    
    return 0
}

# Setup complete network for container
setup_container_network() {
    local container_name=$1
    local container_ip=${2:-""}
    
    log_info "Setting up complete network for container: $container_name" \
             "Seperti RT yang menyiapkan sistem komunikasi lengkap untuk rumah baru"
    
    # Create network namespace
    if ! create_network_namespace "$container_name"; then
        log_error "Failed to create network namespace" \
                  "Gagal menyiapkan sistem telepon rumah"
        return 1
    fi
    
    # Create veth pair
    if ! create_veth_pair "$container_name"; then
        log_error "Failed to create veth pair" \
                  "Gagal memasang kabel telepon"
        cleanup_container_network "$container_name"
        return 1
    fi
    
    # Setup IP addressing
    if ! setup_container_ip "$container_name" "$container_ip"; then
        log_error "Failed to setup container IP" \
                  "Gagal memberikan nomor telepon"
        cleanup_container_network "$container_name"
        return 1
    fi
    
    # Configure routing
    if ! setup_container_routing "$container_name"; then
        log_error "Failed to setup container routing" \
                  "Gagal mengatur jalur komunikasi"
        cleanup_container_network "$container_name"
        return 1
    fi
    
    log_success "Complete network setup finished for container: $container_name" \
                "Sistem komunikasi rumah lengkap dan siap untuk berkomunikasi dengan rumah lain"
    
    return 0
}

# Test network connectivity between containers
test_container_connectivity() {
    local container1=$1
    local container2=$2
    
    log_step 5 "Testing network connectivity between containers" \
              "Seperti menguji apakah telepon antar rumah bisa saling terhubung"
    
    local ip1=$(get_container_ip "$container1" 2>/dev/null || echo "")
    local ip2=$(get_container_ip "$container2" 2>/dev/null || echo "")
    
    if [[ -z "$ip1" || -z "$ip2" ]]; then
        log_error "Container IPs not found for connectivity test" \
                  "Nomor telepon rumah tidak ditemukan untuk tes koneksi"
        return 1
    fi
    
    log_info "Testing connectivity: $container1 ($ip1) -> $container2 ($ip2)" \
             "Seperti menguji panggilan dari rumah $container1 ke rumah $container2"
    
    # Test ping from container1 to container2
    if ip netns exec "container-$container1" ping -c 3 -W 2 "$ip2" >/dev/null 2>&1; then
        log_success "Connectivity test passed: $container1 can reach $container2" \
                    "Telepon antar rumah berfungsi dengan baik"
        return 0
    else
        log_error "Connectivity test failed: $container1 cannot reach $container2" \
                  "Telepon antar rumah tidak bisa terhubung"
        return 1
    fi
}

# Cleanup network resources for container
cleanup_container_network() {
    local container_name=$1
    
    log_info "Cleaning up network resources for container: $container_name" \
             "Seperti RT yang membersihkan sistem telepon rumah yang sudah kosong"
    
    local veth_host="veth-${container_name}"
    local container_ip=$(get_container_ip "$container_name" 2>/dev/null || echo "")
    
    # Remove route to container
    if [[ -n "$container_ip" ]]; then
        ip route del "$container_ip/32" 2>/dev/null || true
        log_debug "Removed route to container IP: $container_ip"
    fi
    
    # Delete veth pair (this also removes the container end)
    if ip link show "$veth_host" >/dev/null 2>&1; then
        if ip link delete "$veth_host" 2>/dev/null; then
            log_debug "Deleted veth pair: $veth_host"
        else
            log_warn "Failed to delete veth pair: $veth_host" \
                     "Gagal mencabut kabel telepon rumah"
        fi
    fi
    
    # Delete network namespace
    if ip netns list | grep -q "container-$container_name"; then
        if ip netns delete "container-$container_name" 2>/dev/null; then
            log_debug "Deleted network namespace: container-$container_name"
        else
            log_warn "Failed to delete network namespace: container-$container_name" \
                     "Gagal menghapus sistem telepon rumah"
        fi
    fi
    
    # Clean up tracking
    unset_container_network "$container_name"
    unset_container_ip "$container_name"
    
    # Remove network configuration files
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    rm -f "$ns_dir/network.conf" 2>/dev/null
    
    log_success "Network cleanup completed for container: $container_name" \
                "Sistem telepon rumah berhasil dibersihkan"
    
    return 0
}

# Wrapper function for container lifecycle management
create_container_network() {
    local container_name=$1
    local container_ip=$2
    
    setup_container_network "$container_name" "$container_ip"
    
    return 0
}

# Show network information for container
show_container_network_info() {
    local container_name=$1
    
    echo "=== Network Information for Container: $container_name ==="
    
    local ns_name="container-$container_name"
    local container_ip=$(get_container_ip "$container_name" 2>/dev/null || echo "")
    local veth_host="veth-${container_name}"
    local veth_container="veth-${container_name}-c"
    
    echo "Network Namespace: $ns_name"
    echo "Container IP: ${container_ip:-Not assigned}"
    echo "Host veth: $veth_host"
    echo "Container veth: $veth_container"
    
    # Check if namespace exists
    if ip netns list | grep -q "$ns_name"; then
        echo "Namespace Status: ✅ Active"
        
        # Show interfaces in namespace
        echo ""
        echo "Interfaces in namespace:"
        ip netns exec "$ns_name" ip link show 2>/dev/null || echo "  Failed to list interfaces"
        
        echo ""
        echo "IP addresses in namespace:"
        ip netns exec "$ns_name" ip addr show 2>/dev/null || echo "  Failed to show IP addresses"
        
        echo ""
        echo "Routes in namespace:"
        ip netns exec "$ns_name" ip route show 2>/dev/null || echo "  Failed to show routes"
    else
        echo "Namespace Status: ❌ Not found"
    fi
    
    # Check host veth
    if ip link show "$veth_host" >/dev/null 2>&1; then
        echo "Host veth Status: ✅ Active"
    else
        echo "Host veth Status: ❌ Not found"
    fi
    
    echo "=================================================="
}

# List all container networks
list_container_networks() {
    echo "=== Container Network Overview ==="
    echo "Network Subnet: $CONTAINER_NETWORK"
    echo "Next Available IP: 10.0.0.$NEXT_IP_OCTET"
    echo ""
    
    if [[ ${#CONTAINER_IPS[@]} -eq 0 ]]; then
        echo "No containers with network configuration found."
        return 0
    fi
    
    echo "Active Container Networks:"
    printf "%-20s %-15s %-20s %-10s\n" "CONTAINER" "IP ADDRESS" "NAMESPACE" "STATUS"
    printf "%-20s %-15s %-20s %-10s\n" "--------" "----------" "---------" "------"
    
    for container_name in "${!CONTAINER_IPS[@]}"; do
        local ip=$(get_container_ip "$container_name" 2>/dev/null || echo "")
        local ns_name="container-$container_name"
        local status="❌"
        
        if ip netns list | grep -q "$ns_name"; then
            status="✅"
        fi
        
        printf "%-20s %-15s %-20s %-10s\n" "$container_name" "$ip" "$ns_name" "$status"
    done
    
    echo ""
    echo "Network Connectivity Test:"
    echo "Use: $0 test-network <container1> <container2>"
    echo "=================================="
}

# Network monitoring and debugging tools
monitor_container_network() {
    local container_name=$1
    local duration=${2:-10}
    
    log_info "Monitoring network for container: $container_name (${duration}s)" \
             "Seperti RT yang memantau aktivitas telepon rumah"
    
    local ns_name="container-$container_name"
    
    if ! ip netns list | grep -q "$ns_name"; then
        log_error "Network namespace not found: $ns_name" \
                  "Sistem telepon rumah tidak ditemukan"
        return 1
    fi
    
    echo "=== Network Monitoring for $container_name ==="
    echo "Duration: ${duration} seconds"
    echo "Press Ctrl+C to stop early"
    echo ""
    
    # Monitor network interfaces
    echo "Network Interfaces:"
    ip netns exec "$ns_name" ip link show
    echo ""
    
    echo "IP Addresses:"
    ip netns exec "$ns_name" ip addr show
    echo ""
    
    echo "Routing Table:"
    ip netns exec "$ns_name" ip route show
    echo ""
    
    echo "Network Statistics (updating every 2 seconds):"
    for ((i=0; i<duration; i+=2)); do
        echo "--- Time: ${i}s ---"
        ip netns exec "$ns_name" cat /proc/net/dev 2>/dev/null | grep -E "(veth|lo)" || echo "No network activity"
        sleep 2
    done
    
    echo "=== Monitoring Complete ==="
}

# Debug network issues
debug_container_network() {
    local container_name=$1
    
    log_info "Debugging network for container: $container_name" \
             "Seperti RT yang memeriksa masalah sistem telepon rumah"
    
    local ns_name="container-$container_name"
    local veth_host="veth-${container_name}"
    local veth_container="veth-${container_name}-c"
    local container_ip=$(get_container_ip "$container_name" 2>/dev/null || echo "")
    
    echo "=== Network Debug Information ==="
    echo "Container: $container_name"
    echo "Expected IP: ${container_ip:-Not assigned}"
    echo ""
    
    # Check namespace
    echo "1. Network Namespace Check:"
    if ip netns list | grep -q "$ns_name"; then
        echo "   ✅ Namespace exists: $ns_name"
    else
        echo "   ❌ Namespace missing: $ns_name"
        echo "   💡 Solution: Run container creation again"
    fi
    echo ""
    
    # Check host veth
    echo "2. Host veth Interface Check:"
    if ip link show "$veth_host" >/dev/null 2>&1; then
        echo "   ✅ Host veth exists: $veth_host"
        echo "   Status: $(ip link show "$veth_host" | grep -o 'state [A-Z]*' | cut -d' ' -f2)"
    else
        echo "   ❌ Host veth missing: $veth_host"
        echo "   💡 Solution: Recreate veth pair"
    fi
    echo ""
    
    # Check container veth (if namespace exists)
    echo "3. Container veth Interface Check:"
    if ip netns list | grep -q "$ns_name"; then
        if ip netns exec "$ns_name" ip link show "$veth_container" >/dev/null 2>&1; then
            echo "   ✅ Container veth exists: $veth_container"
            echo "   Status: $(ip netns exec "$ns_name" ip link show "$veth_container" | grep -o 'state [A-Z]*' | cut -d' ' -f2)"
        else
            echo "   ❌ Container veth missing: $veth_container"
            echo "   💡 Solution: Recreate veth pair"
        fi
    else
        echo "   ⚠️  Cannot check (namespace missing)"
    fi
    echo ""
    
    # Check IP assignment
    echo "4. IP Address Check:"
    if [[ -n "$container_ip" ]] && ip netns list | grep -q "$ns_name"; then
        if ip netns exec "$ns_name" ip addr show | grep -q "$container_ip"; then
            echo "   ✅ IP address assigned: $container_ip"
        else
            echo "   ❌ IP address not assigned: $container_ip"
            echo "   💡 Solution: Reassign IP address"
        fi
    else
        echo "   ⚠️  Cannot check (IP not configured or namespace missing)"
    fi
    echo ""
    
    # Check connectivity to other containers
    echo "5. Connectivity Check:"
    if [[ ${#CONTAINER_IPS[@]} -gt 1 ]]; then
        for other_container in "${!CONTAINER_IPS[@]}"; do
            if [[ "$other_container" != "$container_name" ]]; then
                local other_ip=$(get_container_ip "$other_container" 2>/dev/null || echo "")
                echo "   Testing connectivity to $other_container ($other_ip):"
                if ip netns exec "$ns_name" ping -c 1 -W 1 "$other_ip" >/dev/null 2>&1; then
                    echo "   ✅ Can reach $other_container"
                else
                    echo "   ❌ Cannot reach $other_container"
                    echo "   💡 Check if $other_container network is properly configured"
                fi
            fi
        done
    else
        echo "   ⚠️  No other containers to test connectivity"
    fi
    
    echo "=================================="
}

# =============================================================================
# CGROUP RESOURCE MANAGEMENT FUNCTIONS
# =============================================================================

# Global cgroup tracking for cleanup
# Using associative arrays for proper container tracking
declare -A ACTIVE_CGROUPS

# Helper functions for cgroup associative array management
set_container_cgroup() {
    local container_name=$1
    local cgroup_info=$2
    ACTIVE_CGROUPS["$container_name"]="$cgroup_info"
}

get_container_cgroup() {
    local container_name=$1
    if [[ -n "${ACTIVE_CGROUPS[$container_name]:-}" ]]; then
        echo "${ACTIVE_CGROUPS[$container_name]}"
        return 0
    fi
    return 1
}

unset_container_cgroup() {
    local container_name=$1
    unset ACTIVE_CGROUPS["$container_name"]
}

# Create cgroup directory structure for memory and CPU control
create_cgroup_structure() {
    local container_name=$1
    local memory_mb=$2
    local cpu_percent=$3

    log_step 1 "Creating cgroup structure for container: $container_name" \
              "Seperti RT yang menyiapkan sistem pembatasan listrik dan air untuk rumah baru"

    # Skip cgroups on macOS
    if [[ "$MACOS_MODE" == "true" ]]; then
        log_warn "Skipping cgroup setup on macOS - resource limits not supported" \
                 "Melewati pengaturan cgroup di macOS - pembatasan resource tidak didukung"
        return 0
    fi

    # Skip cgroups in rootless mode if not supported
    if [[ "$ROOTLESS_MODE" == "true" ]] && ! check_rootless_cgroups; then
        log_warn "Skipping cgroup setup in rootless mode - resource limits disabled" \
                 "Melewati pengaturan pembatasan resource dalam mode terbatas"
        return 0
    fi

    # Validate inputs
    validate_memory_limit "$memory_mb" || return 1
    validate_cpu_percentage "$cpu_percent" || return 1

    # Set cgroup paths based on version
    local memory_cgroup
    local cpu_cgroup

    if [[ "$CGROUP_V2_MODE" == "true" ]]; then
        # cgroups v2: unified hierarchy
        memory_cgroup="$CGROUP_ROOT/container-$container_name"
        cpu_cgroup="$CGROUP_ROOT/container-$container_name"

        # Check cgroup root permissions
        if [[ ! -w "$CGROUP_ROOT" ]]; then
            log_error "No write permission to cgroup root" \
                      "Tidak ada izin menulis ke root cgroup"
            show_cgroup_permission_help
            return 1
        fi
    else
        # cgroups v1: separate hierarchies
        memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
        cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"

        # Check cgroup subsystem permissions
        if [[ ! -w "$CGROUP_ROOT/memory" ]] || [[ ! -w "$CGROUP_ROOT/cpu" ]]; then
            log_error "No write permission to cgroup subsystems" \
                      "Tidak ada izin menulis ke subsistem cgroup"
            log_info "Memory cgroup writable: $(test -w "$CGROUP_ROOT/memory" && echo "Yes" || echo "No")" \
                     "Cgroup memori dapat ditulis: $(test -w "$CGROUP_ROOT/memory" && echo "Ya" || echo "Tidak")"
            log_info "CPU cgroup writable: $(test -w "$CGROUP_ROOT/cpu" && echo "Yes" || echo "No")" \
                     "Cgroup CPU dapat ditulis: $(test -w "$CGROUP_ROOT/cpu" && echo "Ya" || echo "Tidak")"
            show_cgroup_permission_help
            return 1
        fi
    fi

    if [[ "$CGROUP_V2_MODE" == "true" ]]; then
        # cgroups v2: create single unified cgroup
        log_info "Creating unified cgroup (v2): $memory_cgroup" \
                 "Seperti menyiapkan meteran listrik dan waktu kerja terpadu untuk rumah"

        if ! create_directory "$memory_cgroup" 755; then
            log_error "Failed to create cgroup directory: $memory_cgroup" \
                      "Gagal menyiapkan meteran terpadu rumah: $memory_cgroup"
            log_info "Check parent directory permissions: $(ls -ld "$CGROUP_ROOT" 2>/dev/null || echo 'Directory not found')" \
                     "Periksa izin direktori induk: $(ls -ld "$CGROUP_ROOT" 2>/dev/null || echo 'Direktori tidak ditemukan')"
            show_cgroup_permission_help
            return 1
        fi

        # Enable memory and cpu controllers for the cgroup
        log_info "Enabling memory and cpu controllers for cgroup v2" \
                 "Mengaktifkan pengontrol memori dan CPU untuk cgroup v2"

        # Enable controllers in parent cgroup
        if [[ -f "$CGROUP_ROOT/cgroup.subtree_control" ]]; then
            echo "+memory +cpu" > "$CGROUP_ROOT/cgroup.subtree_control" 2>/dev/null || true
        fi

    else
        # cgroups v1: create separate memory and cpu cgroups
        log_info "Creating memory cgroup (v1): $memory_cgroup" \
                 "Seperti menyiapkan meteran listrik khusus untuk rumah"

        if ! create_directory "$memory_cgroup" 755; then
            log_error "Failed to create memory cgroup directory: $memory_cgroup" \
                      "Gagal menyiapkan meteran listrik rumah: $memory_cgroup"
            log_info "Check parent directory permissions: $(ls -ld "$CGROUP_ROOT/memory" 2>/dev/null || echo 'Directory not found')" \
                     "Periksa izin direktori induk: $(ls -ld "$CGROUP_ROOT/memory" 2>/dev/null || echo 'Direktori tidak ditemukan')"
            show_cgroup_permission_help
            return 1
        fi

        log_info "Creating CPU cgroup (v1): $cpu_cgroup" \
                 "Seperti menyiapkan pembagi waktu kerja untuk rumah"

        if ! create_directory "$cpu_cgroup" 755; then
            log_error "Failed to create CPU cgroup directory: $cpu_cgroup" \
                      "Gagal menyiapkan pembagi waktu kerja rumah: $cpu_cgroup"
            log_info "Check parent directory permissions: $(ls -ld "$CGROUP_ROOT/cpu" 2>/dev/null || echo 'Directory not found')" \
                     "Periksa izin direktori induk: $(ls -ld "$CGROUP_ROOT/cpu" 2>/dev/null || echo 'Direktori tidak ditemukan')"
            show_cgroup_permission_help
            return 1
        fi
    fi
    
    # Store cgroup paths for later use
    local cgroup_dir="$CONTAINERS_DIR/$container_name/cgroups"
    create_directory "$cgroup_dir"
    
    cat > "$cgroup_dir/paths.conf" << EOF
memory_cgroup=$memory_cgroup
cpu_cgroup=$cpu_cgroup
memory_limit_mb=$memory_mb
cpu_limit_percent=$cpu_percent
EOF
    
    # Mark cgroups as active for cleanup tracking
    set_container_cgroup "$container_name" "memory,cpu"
    
    log_success "Cgroup structure created successfully" \
                "Sistem pembatasan listrik dan waktu kerja rumah siap"
    
    return 0
}

# Implement memory limit functions with validation
set_memory_limit() {
    local container_name=$1
    local memory_mb=$2

    log_step 2 "Setting memory limit for container: $container_name to ${memory_mb}MB" \
              "Seperti RT yang mengatur batas pemakaian listrik rumah: ${memory_mb}MB"

    # Skip memory limits on macOS
    if [[ "$MACOS_MODE" == "true" ]]; then
        log_warn "Memory limits not supported on macOS - skipping" \
                 "Pembatasan memori tidak didukung di macOS - dilewati"
        return 0
    fi

    # Validate memory limit
    validate_memory_limit "$memory_mb" || return 1

    # Set memory cgroup path based on version
    local memory_cgroup
    local memory_limit_file

    if [[ "$CGROUP_V2_MODE" == "true" ]]; then
        memory_cgroup="$CGROUP_ROOT/container-$container_name"
        memory_limit_file="$memory_cgroup/memory.max"
    else
        memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
        memory_limit_file="$memory_cgroup/memory.limit_in_bytes"
    fi

    # Check if cgroup exists
    if [[ ! -d "$memory_cgroup" ]]; then
        log_error "Memory cgroup does not exist: $memory_cgroup" \
                  "Meteran listrik rumah belum dipasang"
        return 1
    fi

    # Check if we have write permission to the memory limit file
    if [[ ! -w "$memory_limit_file" ]]; then
        log_error "No write permission to memory limit file: $memory_limit_file" \
                  "Tidak ada izin menulis ke file pembatas memori"
        log_info "Current user: $(whoami), EUID: $EUID" \
                 "User saat ini: $(whoami), EUID: $EUID"
        log_info "File permissions: $(ls -l "$memory_limit_file" 2>/dev/null || echo 'File not found')" \
                 "Izin file: $(ls -l "$memory_limit_file" 2>/dev/null || echo 'File tidak ditemukan')"
        log_info "Try running with: sudo $0 [command]" \
                 "Coba jalankan dengan: sudo $0 [command]"
        return 1
    fi
    
    # Convert MB to bytes
    local memory_bytes=$((memory_mb * 1024 * 1024))

    log_info "Setting memory limit to $memory_bytes bytes" \
             "Seperti mengatur batas listrik rumah: ${memory_mb}MB"

    # Set memory limit with better error handling
    if ! echo "$memory_bytes" > "$memory_limit_file" 2>/dev/null; then
        # Check if it's a permission issue
        if [[ ! -w "$memory_limit_file" ]]; then
            log_error "Permission denied: Cannot write to cgroup memory limit file" \
                      "Akses ditolak: Tidak bisa menulis ke file pembatas memori"
            show_cgroup_permission_help
        else
            log_error "Failed to set memory limit (unknown error)" \
                      "Gagal mengatur batas pemakaian listrik rumah (error tidak diketahui)"
        fi
        return 1
    fi

    if [[ "$CGROUP_V2_MODE" == "true" ]]; then
        # cgroups v2: set swap limit separately
        local swap_limit_file="$memory_cgroup/memory.swap.max"
        if [[ -f "$swap_limit_file" ]]; then
            if ! echo "0" > "$swap_limit_file" 2>/dev/null; then
                log_warn "Failed to disable swap, continuing with swap enabled" \
                         "Tidak bisa menonaktifkan swap, melanjutkan dengan swap aktif"
            fi
        fi
    else
        # cgroups v1: set memory+swap limit (same as memory to prevent swap usage)
        if [[ -f "$memory_cgroup/memory.memsw.limit_in_bytes" ]]; then
            if ! echo "$memory_bytes" > "$memory_cgroup/memory.memsw.limit_in_bytes"; then
                log_warn "Failed to set memory+swap limit, continuing without swap limit" \
                         "Tidak bisa mengatur batas swap, tapi listrik utama sudah dibatasi"
            fi
        fi

        # Enable OOM killer for the cgroup
        if [[ -f "$memory_cgroup/memory.oom_control" ]]; then
            echo 0 > "$memory_cgroup/memory.oom_control" 2>/dev/null || true
        fi
    fi

    # Verify the limit was set correctly
    local actual_limit
    if actual_limit=$(cat "$memory_limit_file" 2>/dev/null); then
        local actual_mb=$((actual_limit / 1024 / 1024))
        log_info "Memory limit verified: ${actual_mb}MB" \
                 "Batas listrik rumah terpasang: ${actual_mb}MB"
    else
        log_warn "Could not verify memory limit" \
                 "Tidak bisa memverifikasi batas listrik"
    fi
    
    log_success "Memory limit set successfully: ${memory_mb}MB" \
                "Batas pemakaian listrik rumah berhasil diatur: ${memory_mb}MB"
    
    return 0
}

# Create CPU limit functions with percentage-based control
set_cpu_limit() {
    local container_name=$1
    local cpu_percent=$2

    log_step 3 "Setting CPU limit for container: $container_name to ${cpu_percent}%" \
              "Seperti RT yang mengatur pembagian waktu kerja rumah: ${cpu_percent}%"

    # Skip CPU limits on macOS
    if [[ "$MACOS_MODE" == "true" ]]; then
        log_warn "CPU limits not supported on macOS - skipping" \
                 "Pembatasan CPU tidak didukung di macOS - dilewati"
        return 0
    fi

    # Validate CPU percentage
    validate_cpu_percentage "$cpu_percent" || return 1

    # Set CPU cgroup path and files based on version
    local cpu_cgroup
    local cpu_limit_file

    if [[ "$CGROUP_V2_MODE" == "true" ]]; then
        cpu_cgroup="$CGROUP_ROOT/container-$container_name"
        cpu_limit_file="$cpu_cgroup/cpu.max"
    else
        cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
        cpu_limit_file="$cpu_cgroup/cpu.cfs_quota_us"
    fi

    # Check if cgroup exists
    if [[ ! -d "$cpu_cgroup" ]]; then
        log_error "CPU cgroup does not exist: $cpu_cgroup" \
                  "Pembagi waktu kerja rumah belum dipasang"
        return 1
    fi

    # Check if we have write permission to the CPU limit files
    if [[ ! -w "$cpu_limit_file" ]]; then
        log_error "No write permission to CPU limit file: $cpu_limit_file" \
                  "Tidak ada izin menulis ke file pembatas CPU"
        log_info "Current user: $(whoami), EUID: $EUID" \
                 "User saat ini: $(whoami), EUID: $EUID"
        log_info "Try running with: sudo $0 [command]" \
                 "Coba jalankan dengan: sudo $0 [command]"
        return 1
    fi

    if [[ "$CGROUP_V2_MODE" == "true" ]]; then
        # cgroups v2: use cpu.max format "quota period"
        local cfs_period=100000
        local cfs_quota=$((cfs_period * cpu_percent / 100))

        log_info "Setting CPU limit to $cfs_quota/$cfs_period (${cpu_percent}%)" \
                 "Seperti mengatur waktu kerja: ${cpu_percent}% dari total waktu"

        # Set CPU limit in v2 format: "quota period"
        if ! echo "$cfs_quota $cfs_period" > "$cpu_limit_file" 2>/dev/null; then
            if [[ ! -w "$cpu_limit_file" ]]; then
                log_error "Permission denied: Cannot write to CPU limit file" \
                          "Akses ditolak: Tidak bisa menulis ke file pembatas CPU"
                show_cgroup_permission_help
            else
                log_error "Failed to set CPU limit (unknown error)" \
                          "Gagal mengatur pembatasan waktu kerja (error tidak diketahui)"
            fi
            return 1
        fi

        # Set CPU weight (relative weight, 100 = default)
        local cpu_weight=$((100 * cpu_percent / 100))
        if [[ -f "$cpu_cgroup/cpu.weight" ]]; then
            if ! echo "$cpu_weight" > "$cpu_cgroup/cpu.weight" 2>/dev/null; then
                log_warn "Failed to set CPU weight, continuing with limit only" \
                         "Tidak bisa mengatur bobot relatif, tapi pembatasan sudah diatur"
            fi
        fi

        # Verify the limit was set correctly
        local actual_limit
        if actual_limit=$(cat "$cpu_limit_file" 2>/dev/null); then
            log_info "CPU limit verified: $actual_limit" \
                     "Pembagian waktu kerja terpasang: ${cpu_percent}%"
        else
            log_warn "Could not verify CPU limit" \
                     "Tidak bisa memverifikasi pembatasan waktu kerja"
        fi

    else
        # cgroups v1: use separate period and quota files
        local cfs_period=100000
        local cfs_quota=$((cfs_period * cpu_percent / 100))

        log_info "Setting CPU quota to $cfs_quota/$cfs_period (${cpu_percent}%)" \
                 "Seperti mengatur waktu kerja: ${cpu_percent}% dari total waktu"

        # Set CFS period
        if ! echo "$cfs_period" > "$cpu_cgroup/cpu.cfs_period_us" 2>/dev/null; then
            if [[ ! -w "$cpu_cgroup/cpu.cfs_period_us" ]]; then
                log_error "Permission denied: Cannot write to CPU period file" \
                          "Akses ditolak: Tidak bisa menulis ke file periode CPU"
                show_cgroup_permission_help
            else
                log_error "Failed to set CPU period (unknown error)" \
                          "Gagal mengatur periode waktu kerja (error tidak diketahui)"
            fi
            return 1
        fi

        # Set CFS quota
        if ! echo "$cfs_quota" > "$cpu_cgroup/cpu.cfs_quota_us" 2>/dev/null; then
            if [[ ! -w "$cpu_cgroup/cpu.cfs_quota_us" ]]; then
                log_error "Permission denied: Cannot write to CPU quota file" \
                          "Akses ditolak: Tidak bisa menulis ke file kuota CPU"
                show_cgroup_permission_help
            else
                log_error "Failed to set CPU quota (unknown error)" \
                          "Gagal mengatur kuota waktu kerja (error tidak diketahui)"
            fi
            return 1
        fi

        # Set CPU shares (relative weight, 1024 = 100%)
        local cpu_shares=$((1024 * cpu_percent / 100))
        if [[ -f "$cpu_cgroup/cpu.shares" ]]; then
            if ! echo "$cpu_shares" > "$cpu_cgroup/cpu.shares"; then
                log_warn "Failed to set CPU shares, continuing with quota only" \
                         "Tidak bisa mengatur bobot relatif, tapi kuota sudah diatur"
            fi
        fi

        # Verify the limit was set correctly
        local actual_period actual_quota
        if actual_period=$(cat "$cpu_cgroup/cpu.cfs_period_us" 2>/dev/null) && \
           actual_quota=$(cat "$cpu_cgroup/cpu.cfs_quota_us" 2>/dev/null); then
            local actual_percent=$((actual_quota * 100 / actual_period))
            log_info "CPU limit verified: ${actual_percent}%" \
                     "Pembagian waktu kerja terpasang: ${actual_percent}%"
        else
            log_warn "Could not verify CPU limit" \
                     "Tidak bisa memverifikasi pembagian waktu kerja"
        fi
    fi
    
    log_success "CPU limit set successfully: ${cpu_percent}%" \
                "Pembagian waktu kerja rumah berhasil diatur: ${cpu_percent}%"
    
    return 0
}

# Implement process assignment to cgroups
assign_process_to_cgroups() {
    local container_name=$1
    local pid=$2
    
    log_step 4 "Assigning process $pid to cgroups for container: $container_name" \
              "Seperti RT yang mendaftarkan penghuni rumah ke sistem pembatasan"
    
    # Validate PID
    if [[ ! "$pid" =~ ^[0-9]+$ ]] || [[ $pid -le 0 ]]; then
        log_error "Invalid PID: $pid" \
                  "Nomor penghuni tidak valid"
        return 1
    fi
    
    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "Process $pid does not exist" \
                  "Penghuni dengan nomor $pid tidak ditemukan"
        return 1
    fi
    
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    # Assign to memory cgroup
    log_info "Assigning process $pid to memory cgroup" \
             "Mendaftarkan penghuni $pid ke meteran listrik rumah"
    
    if [[ -f "$memory_cgroup/cgroup.procs" ]]; then
        if ! echo "$pid" > "$memory_cgroup/cgroup.procs"; then
            log_error "Failed to assign process to memory cgroup" \
                      "Gagal mendaftarkan penghuni ke meteran listrik"
            return 1
        fi
    else
        log_error "Memory cgroup procs file not found" \
                  "File pendaftaran meteran listrik tidak ditemukan"
        return 1
    fi
    
    # Assign to CPU cgroup
    log_info "Assigning process $pid to CPU cgroup" \
             "Mendaftarkan penghuni $pid ke pembagi waktu kerja rumah"
    
    if [[ -f "$cpu_cgroup/cgroup.procs" ]]; then
        if ! echo "$pid" > "$cpu_cgroup/cgroup.procs"; then
            log_error "Failed to assign process to CPU cgroup" \
                      "Gagal mendaftarkan penghuni ke pembagi waktu kerja"
            return 1
        fi
    else
        log_error "CPU cgroup procs file not found" \
                  "File pendaftaran pembagi waktu kerja tidak ditemukan"
        return 1
    fi
    
    # Verify assignment
    local memory_procs cpu_procs
    memory_procs=$(cat "$memory_cgroup/cgroup.procs" 2>/dev/null | grep "^$pid$" || true)
    cpu_procs=$(cat "$cpu_cgroup/cgroup.procs" 2>/dev/null | grep "^$pid$" || true)
    
    if [[ -n "$memory_procs" ]] && [[ -n "$cpu_procs" ]]; then
        log_success "Process $pid successfully assigned to all cgroups" \
                    "Penghuni $pid berhasil terdaftar di semua sistem pembatasan rumah"
    else
        log_warn "Process assignment verification incomplete" \
                 "Pendaftaran penghuni mungkin belum lengkap"
    fi
    
    return 0
}

# Create cgroup cleanup and monitoring functions
cleanup_container_cgroups() {
    local container_name=$1
    
    log_step 5 "Cleaning up cgroups for container: $container_name" \
              "Seperti RT yang membersihkan sistem pembatasan rumah yang sudah kosong"
    
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    # Kill any remaining processes in the cgroups
    log_info "Terminating remaining processes in cgroups" \
             "Mengeluarkan penghuni yang masih tersisa di rumah"
    
    # Kill processes in memory cgroup
    if [[ -f "$memory_cgroup/cgroup.procs" ]]; then
        local pids
        pids=$(cat "$memory_cgroup/cgroup.procs" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            for pid in $pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    log_debug "Terminating process $pid from memory cgroup"
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 0.1
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            done
        fi
    fi
    
    # Kill processes in CPU cgroup
    if [[ -f "$cpu_cgroup/cgroup.procs" ]]; then
        local pids
        pids=$(cat "$cpu_cgroup/cgroup.procs" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            for pid in $pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    log_debug "Terminating process $pid from CPU cgroup"
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 0.1
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            done
        fi
    fi
    
    # Wait a moment for processes to exit
    sleep 0.5
    
    # Remove memory cgroup
    if [[ -d "$memory_cgroup" ]]; then
        log_info "Removing memory cgroup: $memory_cgroup" \
                 "Melepas meteran listrik rumah"
        
        # Ensure no processes remain
        if [[ -f "$memory_cgroup/cgroup.procs" ]]; then
            local remaining_procs
            remaining_procs=$(cat "$memory_cgroup/cgroup.procs" 2>/dev/null | wc -l)
            if [[ $remaining_procs -gt 0 ]]; then
                log_warn "Still $remaining_procs processes in memory cgroup, force removing" \
                         "Masih ada $remaining_procs penghuni, paksa mengeluarkan"
                echo > "$memory_cgroup/cgroup.procs" 2>/dev/null || true
            fi
        fi
        
        if ! rmdir "$memory_cgroup" 2>/dev/null; then
            log_warn "Failed to remove memory cgroup directory" \
                     "Tidak bisa melepas meteran listrik, mungkin masih ada penghuni"
        else
            log_debug "Memory cgroup removed successfully"
        fi
    fi
    
    # Remove CPU cgroup
    if [[ -d "$cpu_cgroup" ]]; then
        log_info "Removing CPU cgroup: $cpu_cgroup" \
                 "Melepas pembagi waktu kerja rumah"
        
        # Ensure no processes remain
        if [[ -f "$cpu_cgroup/cgroup.procs" ]]; then
            local remaining_procs
            remaining_procs=$(cat "$cpu_cgroup/cgroup.procs" 2>/dev/null | wc -l)
            if [[ $remaining_procs -gt 0 ]]; then
                log_warn "Still $remaining_procs processes in CPU cgroup, force removing" \
                         "Masih ada $remaining_procs penghuni, paksa mengeluarkan"
                echo > "$cpu_cgroup/cgroup.procs" 2>/dev/null || true
            fi
        fi
        
        if ! rmdir "$cpu_cgroup" 2>/dev/null; then
            log_warn "Failed to remove CPU cgroup directory" \
                     "Tidak bisa melepas pembagi waktu kerja, mungkin masih ada penghuni"
        else
            log_debug "CPU cgroup removed successfully"
        fi
    fi
    
    # Remove from active cgroups tracking
    unset_container_cgroup "$container_name"
    
    log_success "Cgroup cleanup completed for container: $container_name" \
                "Sistem pembatasan rumah berhasil dibersihkan dan dilepas"
    
    return 0
}

# Write resource usage reporting with "Tagihan listrik dan air" analogy
get_container_resource_usage() {
    local container_name=$1
    
    log_info "Getting resource usage for container: $container_name" \
             "Seperti RT yang mengecek tagihan listrik dan air rumah"
    
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    # Check if cgroups exist
    if [[ ! -d "$memory_cgroup" ]] || [[ ! -d "$cpu_cgroup" ]]; then
        log_error "Cgroups not found for container: $container_name" \
                  "Meteran rumah tidak ditemukan"
        return 1
    fi
    
    echo "=== Resource Usage Report for Container: $container_name ==="
    echo "🏠 Tagihan Listrik dan Air Rumah: $container_name"
    echo ""
    
    # Memory usage report
    echo "💡 LISTRIK (Memory Usage):"
    if [[ -f "$memory_cgroup/memory.usage_in_bytes" ]] && [[ -f "$memory_cgroup/memory.limit_in_bytes" ]]; then
        local usage_bytes limit_bytes
        usage_bytes=$(cat "$memory_cgroup/memory.usage_in_bytes" 2>/dev/null || echo "0")
        limit_bytes=$(cat "$memory_cgroup/memory.limit_in_bytes" 2>/dev/null || echo "0")
        
        local usage_mb=$((usage_bytes / 1024 / 1024))
        local limit_mb=$((limit_bytes / 1024 / 1024))
        local usage_percent=0
        
        if [[ $limit_bytes -gt 0 ]]; then
            usage_percent=$((usage_bytes * 100 / limit_bytes))
        fi
        
        echo "   📊 Pemakaian: ${usage_mb}MB / ${limit_mb}MB (${usage_percent}%)"
        
        # Memory usage bar
        local bar_length=20
        local filled_length=$((usage_percent * bar_length / 100))
        local bar=""
        for ((i=0; i<filled_length; i++)); do bar+="█"; done
        for ((i=filled_length; i<bar_length; i++)); do bar+="░"; done
        echo "   📈 Grafik: [$bar] ${usage_percent}%"
        
        # Memory status
        if [[ $usage_percent -lt 50 ]]; then
            echo "   ✅ Status: Normal (pemakaian listrik wajar)"
        elif [[ $usage_percent -lt 80 ]]; then
            echo "   ⚠️  Status: Tinggi (perlu perhatian RT)"
        else
            echo "   🚨 Status: Kritis (hampir melebihi batas)"
        fi
    else
        echo "   ❌ Data pemakaian listrik tidak tersedia"
    fi
    
    echo ""
    
    # CPU usage report
    echo "⚡ WAKTU KERJA (CPU Usage):"
    if [[ -f "$cpu_cgroup/cpu.cfs_quota_us" ]] && [[ -f "$cpu_cgroup/cpu.cfs_period_us" ]]; then
        local quota_us period_us
        quota_us=$(cat "$cpu_cgroup/cpu.cfs_quota_us" 2>/dev/null || echo "-1")
        period_us=$(cat "$cpu_cgroup/cpu.cfs_period_us" 2>/dev/null || echo "100000")
        
        if [[ $quota_us -gt 0 ]]; then
            local cpu_limit_percent=$((quota_us * 100 / period_us))
            echo "   📊 Batas Waktu Kerja: ${cpu_limit_percent}%"
            
            # Get CPU statistics if available
            if [[ -f "$cpu_cgroup/cpuacct.usage" ]]; then
                local cpu_usage_ns
                cpu_usage_ns=$(cat "$cpu_cgroup/cpuacct.usage" 2>/dev/null || echo "0")
                local cpu_usage_seconds=$((cpu_usage_ns / 1000000000))
                echo "   ⏱️  Total Waktu Kerja: ${cpu_usage_seconds} detik"
            fi
            
            # CPU usage bar (simplified, showing limit)
            local bar_length=20
            local filled_length=$((cpu_limit_percent * bar_length / 100))
            local bar=""
            for ((i=0; i<filled_length; i++)); do bar+="█"; done
            for ((i=filled_length; i<bar_length; i++)); do bar+="░"; done
            echo "   📈 Batas: [$bar] ${cpu_limit_percent}%"
            
            echo "   ✅ Status: Terbatas sesuai aturan RT"
        else
            echo "   ♾️  Batas Waktu Kerja: Tidak terbatas"
            echo "   ⚠️  Status: Bebas (tidak ada pembatasan)"
        fi
    else
        echo "   ❌ Data waktu kerja tidak tersedia"
    fi
    
    echo ""
    
    # Process count
    echo "👥 PENGHUNI RUMAH (Processes):"
    local memory_procs=0 cpu_procs=0
    
    if [[ -f "$memory_cgroup/cgroup.procs" ]]; then
        memory_procs=$(cat "$memory_cgroup/cgroup.procs" 2>/dev/null | wc -l)
    fi
    
    if [[ -f "$cpu_cgroup/cgroup.procs" ]]; then
        cpu_procs=$(cat "$cpu_cgroup/cgroup.procs" 2>/dev/null | wc -l)
    fi
    
    echo "   👨‍👩‍👧‍👦 Jumlah Penghuni: $memory_procs proses"
    
    if [[ $memory_procs -eq $cpu_procs ]]; then
        echo "   ✅ Status: Semua penghuni terdaftar dengan benar"
    else
        echo "   ⚠️  Status: Ada ketidaksesuaian pendaftaran ($memory_procs vs $cpu_procs)"
    fi
    
    # List active processes if any
    if [[ $memory_procs -gt 0 ]]; then
        echo "   📋 Daftar Penghuni Aktif:"
        if [[ -f "$memory_cgroup/cgroup.procs" ]]; then
            local pids
            pids=$(cat "$memory_cgroup/cgroup.procs" 2>/dev/null || true)
            for pid in $pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    local cmd
                    cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                    echo "      - PID $pid: $cmd"
                fi
            done
        fi
    fi
    
    echo ""
    echo "=== End of Resource Usage Report ==="
    echo "📝 Catatan RT: Laporan ini menunjukkan pemakaian sumber daya rumah secara real-time"
    
    return 0
}

# Monitor resource usage in real-time
monitor_container_resources() {
    local container_name=$1
    local interval=${2:-5}
    
    log_info "Starting resource monitoring for container: $container_name (interval: ${interval}s)" \
             "Seperti RT yang memantau pemakaian listrik dan air rumah secara berkala"
    
    if [[ ! "$interval" =~ ^[0-9]+$ ]] || [[ $interval -lt 1 ]]; then
        log_error "Invalid monitoring interval: $interval" \
                  "Interval pemantauan tidak valid"
        return 1
    fi
    
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    # Check if cgroups exist
    if [[ ! -d "$memory_cgroup" ]] || [[ ! -d "$cpu_cgroup" ]]; then
        log_error "Cgroups not found for container: $container_name" \
                  "Meteran rumah tidak ditemukan"
        return 1
    fi
    
    echo "🔍 Real-time Resource Monitoring for Container: $container_name"
    echo "📊 Press Ctrl+C to stop monitoring"
    echo "⏱️  Update interval: ${interval} seconds"
    echo ""
    
    # Set up signal handler for clean exit
    trap 'echo -e "\n👋 Monitoring stopped by user"; exit 0' INT
    
    while true; do
        clear
        echo "🏠 RT Container Resource Monitor - $(date)"
        echo "Container: $container_name"
        echo "=========================================="
        
        # Get current resource usage
        get_container_resource_usage "$container_name" 2>/dev/null || {
            echo "❌ Failed to get resource usage"
            break
        }
        
        echo ""
        echo "🔄 Next update in ${interval} seconds... (Ctrl+C to stop)"
        
        sleep "$interval"
    done
    
    return 0
}

# Setup complete cgroup system for container
setup_container_cgroups() {
    local container_name=$1
    local memory_mb=$2
    local cpu_percent=$3
    
    log_info "Setting up complete cgroup system for container: $container_name" \
             "Seperti RT yang menyiapkan sistem pembatasan lengkap untuk rumah baru"
    
    # Create cgroup structure
    if ! create_cgroup_structure "$container_name" "$memory_mb" "$cpu_percent"; then
        log_error "Failed to create cgroup structure" \
                  "Gagal menyiapkan struktur sistem pembatasan"
        return 1
    fi
    
    # Set memory limit
    if ! set_memory_limit "$container_name" "$memory_mb"; then
        log_error "Failed to set memory limit" \
                  "Gagal mengatur batas pemakaian listrik"
        cleanup_container_cgroups "$container_name"
        return 1
    fi
    
    # Set CPU limit
    if ! set_cpu_limit "$container_name" "$cpu_percent"; then
        log_error "Failed to set CPU limit" \
                  "Gagal mengatur pembagian waktu kerja"
        cleanup_container_cgroups "$container_name"
        return 1
    fi
    
    log_success "Complete cgroup system setup completed for container: $container_name" \
                "Sistem pembatasan lengkap rumah siap: listrik ${memory_mb}MB, waktu kerja ${cpu_percent}%"
    
    return 0
}

# Apply mount namespace configuration during container start
apply_mount_namespace() {
    local container_name=$1
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    
    log_info "Applying mount namespace for container: $container_name" \
             "Seperti memasang rak buku dan perabotan di rumah baru"
    
    # Check if mount configuration exists
    if [[ ! -f "$ns_dir/mount.conf" ]]; then
        log_error "Mount namespace configuration not found" \
                  "Konfigurasi rak buku tidak ditemukan"
        return 1
    fi
    
    # Source the mount configuration
    source "$ns_dir/mount.conf"
    
    # Create and mount /proc
    if ! mount -t proc proc "$container_rootfs/proc"; then
        log_warn "Failed to mount /proc, container may have limited functionality" \
                 "Gagal memasang sistem informasi rumah"
    else
        log_debug "Mounted /proc in container" "Sistem informasi rumah terpasang"
    fi
    
    # Create and mount /sys
    if ! mount -t sysfs sysfs "$container_rootfs/sys"; then
        log_warn "Failed to mount /sys, container may have limited functionality" \
                 "Gagal memasang sistem kontrol rumah"
    else
        log_debug "Mounted /sys in container" "Sistem kontrol rumah terpasang"
    fi
    
    # Create and mount /dev/pts for terminal support
    if [[ -d "$container_rootfs/dev/pts" ]]; then
        if ! mount -t devpts devpts "$container_rootfs/dev/pts"; then
            log_warn "Failed to mount /dev/pts, terminal may not work properly" \
                     "Gagal memasang sistem terminal rumah"
        else
            log_debug "Mounted /dev/pts in container" "Sistem terminal rumah terpasang"
        fi
    fi
    
    # Mount tmpfs on /tmp for temporary files
    if ! mount -t tmpfs tmpfs "$container_rootfs/tmp"; then
        log_warn "Failed to mount tmpfs on /tmp" \
                 "Gagal memasang ruang sementara rumah"
    else
        log_debug "Mounted tmpfs on /tmp" "Ruang sementara rumah terpasang"
    fi
    
    log_success "Mount namespace applied successfully" \
                "Semua rak buku dan perabotan rumah berhasil dipasang"
    
    return 0
}

# Wrapper functions for container lifecycle management
create_container_cgroup() {
    local container_name=$1
    local memory_mb=$2
    local cpu_percent=$3

    setup_container_cgroups "$container_name" "$memory_mb" "$cpu_percent"
    return $?
}

add_process_to_container_cgroup() {
    local container_name=$1
    local pid=$2

    assign_process_to_cgroups "$container_name" "$pid"
    return $?
}

cleanup_container_cgroup() {
    local container_name=$1

    cleanup_container_cgroups "$container_name"
    return $?
}

# Start container with all namespaces
start_container_with_namespaces() {
    local container_name=$1
    local command=${2:-"/bin/sh"}
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    
    log_info "Starting container with namespaces: $container_name" \
             "Seperti keluarga yang mulai menempati rumah baru dengan semua fasilitasnya"
    
    # Check if namespace configurations exist
    for ns_type in pid mount uts ipc user; do
        if [[ ! -f "$ns_dir/$ns_type.conf" ]]; then
            log_error "Namespace configuration missing: $ns_type" \
                      "Konfigurasi sistem rumah tidak lengkap: $ns_type"
            return 1
        fi
    done
    
    # Source namespace configurations with error handling
    local hostname="$container_name"  # Default hostname
    local host_uid=$(id -u)
    local host_gid=$(id -g)
    
    # Source configurations and extract variables safely
    if [[ -f "$ns_dir/uts.conf" ]]; then
        source "$ns_dir/uts.conf"
        # hostname variable should now be set from uts.conf
    fi
    
    if [[ -f "$ns_dir/user.conf" ]]; then
        source "$ns_dir/user.conf"
        # host_uid and host_gid should be set from user.conf
    fi
    
    # Ensure hostname is set
    if [[ -z "$hostname" ]]; then
        hostname="$container_name"
        log_warn "Hostname not found in configuration, using container name: $hostname"
    fi
    
    # Create the unshare command with all namespaces
    local unshare_cmd="unshare"
    unshare_cmd+=" --pid --fork"           # PID namespace - Ayah nomor 1
    unshare_cmd+=" --mount"                # Mount namespace - Rak buku pribadi
    unshare_cmd+=" --uts"                  # UTS namespace - Nama rumah sendiri
    unshare_cmd+=" --ipc"                  # IPC namespace - Papan tulis keluarga
    unshare_cmd+=" --user --map-root-user" # User namespace - Sistem keanggotaan
    
    # Prepare the container startup script
    local startup_script="$ns_dir/startup.sh"
    cat > "$startup_script" << EOF
#!/bin/bash
set -euo pipefail

# This script runs inside the container namespaces
# Seperti skrip yang dijalankan saat keluarga mulai menempati rumah

# Set hostname (UTS namespace)
hostname "$hostname"
echo "Hostname set to: $hostname (Nama rumah dipasang)"

# Change to container root filesystem
cd "$container_rootfs"

# Apply mount namespace
if ! mount --bind "$container_rootfs" "$container_rootfs"; then
    echo "Warning: Failed to bind mount rootfs"
fi

# Mount essential filesystems
mount -t proc proc proc/ 2>/dev/null || echo "Warning: Failed to mount /proc"
mount -t sysfs sysfs sys/ 2>/dev/null || echo "Warning: Failed to mount /sys"
mount -t devpts devpts dev/pts/ 2>/dev/null || echo "Warning: Failed to mount /dev/pts"
mount -t tmpfs tmpfs tmp/ 2>/dev/null || echo "Warning: Failed to mount /tmp"

# Create basic device nodes if they don't exist
[[ ! -e dev/null ]] && mknod dev/null c 1 3 2>/dev/null || true
[[ ! -e dev/zero ]] && mknod dev/zero c 1 5 2>/dev/null || true
[[ ! -e dev/random ]] && mknod dev/random c 1 8 2>/dev/null || true
[[ ! -e dev/urandom ]] && mknod dev/urandom c 1 9 2>/dev/null || true

# Change root to container filesystem
if ! chroot . $command; then
    echo "Error: Failed to chroot and execute command"
    exit 1
fi
EOF
    
    chmod +x "$startup_script"
    
    # Execute the container with all namespaces
    log_info "Executing container with command: $command" \
             "Seperti keluarga yang mulai beraktivitas di rumah baru"
    
    # Start the container process
    if $unshare_cmd bash "$startup_script"; then
        log_success "Container started successfully with all namespaces" \
                    "Keluarga berhasil menempati rumah dengan semua fasilitas lengkap"
        return 0
    else
        log_error "Failed to start container with namespaces" \
                  "Keluarga gagal menempati rumah, ada masalah dengan fasilitas"
        return 1
    fi
}

# Cleanup namespace resources
cleanup_container_namespaces() {
    local container_name=$1
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    
    log_info "Cleaning up namespaces for container: $container_name" \
             "Seperti RT yang membersihkan rumah setelah keluarga pindah"
    
    # Unmount filesystems in reverse order
    local mount_points=(
        "$container_rootfs/tmp"
        "$container_rootfs/dev/pts"
        "$container_rootfs/sys"
        "$container_rootfs/proc"
        "$container_rootfs"
    )
    
    for mount_point in "${mount_points[@]}"; do
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log_debug "Unmounting: $mount_point" "Membongkar perabotan: $mount_point"
            if ! umount "$mount_point" 2>/dev/null; then
                log_warn "Failed to unmount: $mount_point" \
                         "Gagal membongkar perabotan, mungkin masih digunakan"
                # Force unmount if regular unmount fails
                umount -f "$mount_point" 2>/dev/null || true
            fi
        fi
    done
    
    # Remove namespace configuration files
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    if [[ -d "$ns_dir" ]]; then
        log_debug "Removing namespace configurations" \
                  "Menghapus dokumen konfigurasi rumah"
        rm -rf "$ns_dir"
    fi
    
    # Remove from active namespaces tracking
    unset_container_namespace "$container_name"
    
    log_success "Namespace cleanup completed for container: $container_name" \
                "Rumah telah dibersihkan dan siap untuk keluarga baru"
    
    return 0
}

# Cleanup all active namespaces (emergency cleanup)
cleanup_all_namespaces() {
    log_info "Performing emergency cleanup of all active namespaces" \
             "Seperti RT yang melakukan pembersihan darurat seluruh kompleks"
    
    local cleanup_count=0
    
    # Cleanup tracked namespaces
    for container_name in "${!ACTIVE_NAMESPACES[@]}"; do
        log_info "Emergency cleanup for container: $container_name" \
                 "Pembersihan darurat rumah: $container_name"
        
        if cleanup_container_namespaces "$container_name"; then
            ((cleanup_count++))
        fi
    done
    
    # Force cleanup any remaining mount points
    local containers_mounts=$(mount | grep "$CONTAINERS_DIR" | awk '{print $3}' | sort -r)
    if [[ -n "$containers_mounts" ]]; then
        log_info "Force unmounting remaining container mount points" \
                 "Membongkar paksa sisa perabotan yang tertinggal"
        
        while IFS= read -r mount_point; do
            if [[ -n "$mount_point" ]]; then
                log_debug "Force unmounting: $mount_point"
                umount -f "$mount_point" 2>/dev/null || true
            fi
        done <<< "$containers_mounts"
    fi
    
    # Clear the tracking array
    for key in "${!ACTIVE_NAMESPACES[@]}"; do
        unset ACTIVE_NAMESPACES["$key"]
    done
    
    log_success "Emergency namespace cleanup completed ($cleanup_count containers)" \
                "Pembersihan darurat kompleks selesai ($cleanup_count rumah dibersihkan)"
    
    return 0
}

# Get namespace information for a container
get_namespace_info() {
    local container_name=$1
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    
    echo "=== Namespace Information for Container: $container_name ==="
    echo "🏘️  Seperti informasi lengkap rumah di kompleks RT"
    echo
    
    if [[ ! -d "$ns_dir" ]]; then
        echo "❌ No namespace configuration found"
        echo "   Seperti rumah yang belum diatur sistemnya"
        return 1
    fi
    
    # PID Namespace Info
    if [[ -f "$ns_dir/pid.conf" ]]; then
        echo "👨 PID Namespace (Sistem Penomoran Keluarga):"
        source "$ns_dir/pid.conf"
        echo "   Status: ✅ Configured"
        echo "   Init Process: $init_process"
        echo "   Analogi: Ayah nomor 1 di rumah"
    fi
    
    # Mount Namespace Info
    if [[ -f "$ns_dir/mount.conf" ]]; then
        echo
        echo "📚 Mount Namespace (Rak Buku Pribadi):"
        source "$ns_dir/mount.conf"
        echo "   Status: ✅ Configured"
        echo "   Root FS: $rootfs_path"
        echo "   Analogi: Rak buku yang tidak bisa dilihat tetangga"
    fi
    
    # UTS Namespace Info
    if [[ -f "$ns_dir/uts.conf" ]]; then
        echo
        echo "🏠 UTS Namespace (Nama Rumah):"
        source "$ns_dir/uts.conf"
        echo "   Status: ✅ Configured"
        echo "   Hostname: $hostname"
        echo "   Domain: $domainname"
        echo "   Analogi: Papan nama rumah sendiri"
    fi
    
    # IPC Namespace Info
    if [[ -f "$ns_dir/ipc.conf" ]]; then
        echo
        echo "📝 IPC Namespace (Papan Tulis Keluarga):"
        source "$ns_dir/ipc.conf"
        echo "   Status: ✅ Configured"
        echo "   Shared Memory Max: $shared_memory_max bytes"
        echo "   Semaphore Max: $semaphore_max"
        echo "   Message Queue Max: $message_queue_max"
        echo "   Analogi: Papan tulis keluarga pribadi"
    fi
    
    # User Namespace Info
    if [[ -f "$ns_dir/user.conf" ]]; then
        echo
        echo "👥 User Namespace (Sistem Keanggotaan):"
        source "$ns_dir/user.conf"
        echo "   Status: ✅ Configured"
        echo "   Host UID: $host_uid → Container UID: $container_uid"
        echo "   Host GID: $host_gid → Container GID: $container_gid"
        echo "   Analogi: Sistem keanggotaan keluarga terpisah"
    fi
    
    echo
    echo "=== Active Status ==="
    if [[ -n "${ACTIVE_NAMESPACES[$container_name]:-}" ]]; then
        echo "Status: 🟢 Active (${ACTIVE_NAMESPACES[$container_name]})"
        echo "Seperti: Rumah sedang ditempati keluarga"
    else
        echo "Status: 🔴 Inactive"
        echo "Seperti: Rumah kosong, siap ditempati"
    fi
    
    echo "=================================================="
    
    return 0
}

# List all containers with namespace information
list_container_namespaces() {
    echo "=== RT Container Namespace Status ==="
    echo "🏘️  Seperti daftar status semua rumah di kompleks"
    echo
    
    if [[ ! -d "$CONTAINERS_DIR" ]] || [[ -z "$(ls -A "$CONTAINERS_DIR" 2>/dev/null)" ]]; then
        echo "❌ No containers found"
        echo "   Seperti kompleks yang masih kosong"
        return 0
    fi
    
    local container_count=0
    local active_count=0
    
    for container_dir in "$CONTAINERS_DIR"/*; do
        if [[ -d "$container_dir" ]]; then
            local container_name=$(basename "$container_dir")
            
            # Skip busybox file
            [[ "$container_name" == "busybox" ]] && continue
            
            ((container_count++))
            
            echo "🏠 Container: $container_name"
            
            local ns_dir="$container_dir/namespaces"
            if [[ -d "$ns_dir" ]]; then
                local ns_types=()
                [[ -f "$ns_dir/pid.conf" ]] && ns_types+=("PID")
                [[ -f "$ns_dir/mount.conf" ]] && ns_types+=("Mount")
                [[ -f "$ns_dir/uts.conf" ]] && ns_types+=("UTS")
                [[ -f "$ns_dir/ipc.conf" ]] && ns_types+=("IPC")
                [[ -f "$ns_dir/user.conf" ]] && ns_types+=("User")
                
                if [[ ${#ns_types[@]} -gt 0 ]]; then
                    echo "   Namespaces: ${ns_types[*]}"
                    
                    if [[ -n "${ACTIVE_NAMESPACES[$container_name]:-}" ]]; then
                        echo "   Status: 🟢 Active"
                        ((active_count++))
                    else
                        echo "   Status: 🔴 Configured but inactive"
                    fi
                else
                    echo "   Status: ❌ No namespaces configured"
                fi
            else
                echo "   Status: ❌ No namespace configuration"
            fi
            
            echo
        fi
    done
    
    echo "=== Summary ==="
    echo "Total Containers: $container_count"
    echo "Active Namespaces: $active_count"
    echo "Seperti: $container_count rumah di kompleks, $active_count sedang ditempati"
    echo "================================"
    
    return 0
}

# =============================================================================
# NETWORK UTILITY COMMANDS
# =============================================================================

# Test network functionality
test_network_functionality() {
    log_info "Testing network functionality" \
             "Seperti RT yang menguji sistem telepon kompleks"
    
    # Test 1: Check if ip command is available
    if ! command -v ip &> /dev/null; then
        log_error "ip command not found - required for network operations" \
                  "Perintah 'ip' tidak ditemukan - diperlukan untuk sistem telepon"
        return 1
    fi
    
    # Test 2: Check if we can create a test namespace
    local test_ns="rt-test-$$"
    if ip netns add "$test_ns" 2>/dev/null; then
        log_info "Network namespace creation test: ✅ PASSED"
        ip netns delete "$test_ns" 2>/dev/null
    else
        log_error "Network namespace creation test: ❌ FAILED" \
                  "Tidak bisa membuat sistem telepon test"
        return 1
    fi
    
    # Test 3: Check if we can create veth pairs
    local test_veth="rt-test-veth-$$"
    if ip link add "${test_veth}-a" type veth peer name "${test_veth}-b" 2>/dev/null; then
        log_info "Veth pair creation test: ✅ PASSED"
        ip link delete "${test_veth}-a" 2>/dev/null
    else
        log_error "Veth pair creation test: ❌ FAILED" \
                  "Tidak bisa membuat kabel telepon test"
        return 1
    fi
    
    log_success "All network functionality tests passed" \
                "Semua tes sistem telepon berhasil"
    return 0
}

# Create a test network setup for demonstration
create_test_network() {
    local container1=${1:-"test-container-1"}
    local container2=${2:-"test-container-2"}
    
    log_info "Creating test network setup" \
             "Seperti RT yang membuat demo sistem telepon untuk 2 rumah"
    
    # Create directories for test containers
    create_directory "$CONTAINERS_DIR/$container1/namespaces"
    create_directory "$CONTAINERS_DIR/$container2/namespaces"
    
    # Setup network for first container
    if ! setup_container_network "$container1" "10.0.0.10"; then
        log_error "Failed to setup network for $container1"
        return 1
    fi
    
    # Setup network for second container
    if ! setup_container_network "$container2" "10.0.0.11"; then
        log_error "Failed to setup network for $container2"
        cleanup_container_network "$container1"
        return 1
    fi
    
    # Test connectivity
    if test_container_connectivity "$container1" "$container2"; then
        log_success "Test network setup completed successfully" \
                    "Demo sistem telepon berhasil - kedua rumah bisa saling menelepon"
        
        echo ""
        echo "=== Test Network Created ==="
        echo "Container 1: $container1 (10.0.0.10)"
        echo "Container 2: $container2 (10.0.0.11)"
        echo ""
        echo "Test commands:"
        echo "  Show network info: $0 show-network $container1"
        echo "  Test connectivity: $0 test-connectivity $container1 $container2"
        echo "  Monitor network: $0 monitor-network $container1"
        echo "  Debug network: $0 debug-network $container1"
        echo "  Cleanup: $0 cleanup-test-network"
        echo "=========================="
        
        return 0
    else
        log_error "Test network connectivity failed"
        cleanup_container_network "$container1"
        cleanup_container_network "$container2"
        return 1
    fi
}

# Cleanup test network
cleanup_test_network() {
    log_info "Cleaning up test network" \
             "Seperti RT yang membersihkan demo sistem telepon"
    
    local containers=("test-container-1" "test-container-2")
    
    for container in "${containers[@]}"; do
        if [[ -d "$CONTAINERS_DIR/$container" ]]; then
            cleanup_container_network "$container"
            rm -rf "$CONTAINERS_DIR/$container"
            log_debug "Cleaned up test container: $container"
        fi
    done
    
    log_success "Test network cleanup completed" \
                "Demo sistem telepon berhasil dibersihkan"
}

# =============================================================================
# RECOVERY AND ERROR HANDLING COMMAND HANDLERS
# =============================================================================

# Recovery command handler
cmd_recover_state() {
    local container_name="$1"
    
    log_info "Starting system state recovery..." \
             "Seperti RT melakukan pemulihan kondisi kompleks perumahan"
    
    # Initialize error handling
    init_error_handling
    set_operation_context "recover_state" "$container_name"
    
    if [[ -n "$container_name" ]]; then
        log_info "Recovering specific container: $container_name" \
                 "Memulihkan rumah tertentu: $container_name"
        
        if ! validate_container_name "$container_name"; then
            clear_operation_context "recover_state"
            return 1
        fi
        
        if ! container_exists "$container_name"; then
            log_error "Container '$container_name' does not exist" \
                      "Rumah '$container_name' tidak ditemukan"
            clear_operation_context "recover_state"
            return 1
        fi
        
        detect_and_recover_corrupted_state "$container_name"
    else
        log_info "Recovering all containers..." \
                 "Memulihkan semua rumah di kompleks"
        
        detect_and_recover_corrupted_state
    fi
    
    clear_operation_context "recover_state"
    
    log_success "State recovery completed" \
                "Pemulihan kondisi kompleks selesai"
    
    return 0
}

# System validation command handler
cmd_validate_system() {
    log_info "Validating system state..." \
             "Seperti RT melakukan inspeksi menyeluruh kompleks"
    
    init_error_handling
    set_operation_context "validate_system" ""
    
    local validation_passed=true
    local issues_found=()
    
    # Check basic system requirements
    echo -e "\n${COLOR_BLUE}🔍 SYSTEM VALIDATION REPORT${COLOR_RESET}"
    echo -e "${COLOR_BLUE}===========================${COLOR_RESET}\n"
    
    # Check privileges
    echo -e "${COLOR_GREEN}📋 Checking system privileges...${COLOR_RESET}"
    if [[ $EUID -eq 0 ]]; then
        echo -e "${COLOR_GREEN}   ✅ Root privileges: Available${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}   ❌ Root privileges: Missing${COLOR_RESET}"
        issues_found+=("missing_root_privileges")
        validation_passed=false
    fi
    
    # Check dependencies
    echo -e "\n${COLOR_GREEN}📋 Checking required commands...${COLOR_RESET}"
    local required_commands=("unshare" "nsenter" "ip" "mount" "umount")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "${COLOR_GREEN}   ✅ $cmd: Available${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}   ❌ $cmd: Missing${COLOR_RESET}"
            issues_found+=("missing_command_$cmd")
            validation_passed=false
        fi
    done
    
    # Check system resources
    echo -e "\n${COLOR_GREEN}📋 Checking system resources...${COLOR_RESET}"
    
    # Check disk space
    local available_space=$(df "$CONTAINERS_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    if [[ $available_space -gt 100000 ]]; then  # More than 100MB
        echo -e "${COLOR_GREEN}   ✅ Disk space: $(( available_space / 1024 ))MB available${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}   ❌ Disk space: Low ($(( available_space / 1024 ))MB)${COLOR_RESET}"
        issues_found+=("low_disk_space")
        validation_passed=false
    fi
    
    # Check memory
    if command -v free &> /dev/null; then
        local available_memory=$(free | grep '^Mem:' | awk '{print $7}' 2>/dev/null || echo "0")
        if [[ $available_memory -gt 100000 ]]; then  # More than 100MB
            echo -e "${COLOR_GREEN}   ✅ Memory: $(( available_memory / 1024 ))MB available${COLOR_RESET}"
        else
            echo -e "${COLOR_YELLOW}   ⚠️  Memory: Low ($(( available_memory / 1024 ))MB)${COLOR_RESET}"
            issues_found+=("low_memory")
        fi
    fi
    
    # Check cgroups
    echo -e "\n${COLOR_GREEN}📋 Checking cgroups availability...${COLOR_RESET}"
    if [[ -d "$CGROUP_ROOT" ]]; then
        echo -e "${COLOR_GREEN}   ✅ Cgroups root: Available at $CGROUP_ROOT${COLOR_RESET}"
        
        if [[ -d "$CGROUP_ROOT/memory" ]]; then
            if [[ -w "$CGROUP_ROOT/memory" ]]; then
                echo -e "${COLOR_GREEN}   ✅ Memory cgroup: Available and writable${COLOR_RESET}"
            else
                echo -e "${COLOR_YELLOW}   ⚠️  Memory cgroup: Available but not writable${COLOR_RESET}"
                echo -e "${COLOR_YELLOW}      Permissions: $(ls -ld "$CGROUP_ROOT/memory" | awk '{print $1}')"
                issues_found+=("memory_cgroup_not_writable")
                validation_passed=false
            fi
        else
            echo -e "${COLOR_RED}   ❌ Memory cgroup: Not available${COLOR_RESET}"
            issues_found+=("missing_memory_cgroup")
            validation_passed=false
        fi

        if [[ -d "$CGROUP_ROOT/cpu" ]]; then
            if [[ -w "$CGROUP_ROOT/cpu" ]]; then
                echo -e "${COLOR_GREEN}   ✅ CPU cgroup: Available and writable${COLOR_RESET}"
            else
                echo -e "${COLOR_YELLOW}   ⚠️  CPU cgroup: Available but not writable${COLOR_RESET}"
                echo -e "${COLOR_YELLOW}      Permissions: $(ls -ld "$CGROUP_ROOT/cpu" | awk '{print $1}')"
                issues_found+=("cpu_cgroup_not_writable")
                validation_passed=false
            fi
        else
            echo -e "${COLOR_RED}   ❌ CPU cgroup: Not available${COLOR_RESET}"
            issues_found+=("missing_cpu_cgroup")
            validation_passed=false
        fi
    else
        echo -e "${COLOR_RED}   ❌ Cgroups root: Not available${COLOR_RESET}"
        issues_found+=("missing_cgroups")
        validation_passed=false
    fi
    
    # Check busybox
    echo -e "\n${COLOR_GREEN}📋 Checking busybox availability...${COLOR_RESET}"
    if [[ -x "$BUSYBOX_PATH" ]]; then
        echo -e "${COLOR_GREEN}   ✅ Busybox: Available at $BUSYBOX_PATH${COLOR_RESET}"
        
        if test_busybox_basic_functionality &>/dev/null; then
            echo -e "${COLOR_GREEN}   ✅ Busybox functionality: Working${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}   ❌ Busybox functionality: Failed${COLOR_RESET}"
            issues_found+=("busybox_not_functional")
            validation_passed=false
        fi
    else
        echo -e "${COLOR_YELLOW}   ⚠️  Busybox: Not found (will be created)${COLOR_RESET}"
    fi
    
    # Check for corrupted containers
    echo -e "\n${COLOR_GREEN}📋 Checking container integrity...${COLOR_RESET}"
    local corrupted_containers=()
    
    if [[ -d "$CONTAINERS_DIR" ]]; then
        for container_dir in "$CONTAINERS_DIR"/*; do
            if [[ -d "$container_dir" && "$(basename "$container_dir")" != "busybox" ]]; then
                local container_name=$(basename "$container_dir")
                if check_container_corruption "$container_name"; then
                    corrupted_containers+=("$container_name")
                fi
            fi
        done
    fi
    
    if [[ ${#corrupted_containers[@]} -eq 0 ]]; then
        echo -e "${COLOR_GREEN}   ✅ Container integrity: All containers healthy${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}   ⚠️  Container integrity: ${#corrupted_containers[@]} corrupted containers found${COLOR_RESET}"
        for container in "${corrupted_containers[@]}"; do
            echo -e "${COLOR_YELLOW}      - $container${COLOR_RESET}"
        done
        issues_found+=("corrupted_containers")
    fi
    
    # Summary
    echo -e "\n${COLOR_BLUE}📊 VALIDATION SUMMARY${COLOR_RESET}"
    echo -e "${COLOR_BLUE}===================${COLOR_RESET}"
    
    if [[ "$validation_passed" == "true" ]]; then
        echo -e "${COLOR_GREEN}✅ System Status: HEALTHY${COLOR_RESET}"
        echo -e "${COLOR_GREEN}   All critical components are working properly${COLOR_RESET}"
        
        if [[ ${#corrupted_containers[@]} -gt 0 ]]; then
            echo -e "\n${COLOR_YELLOW}💡 Recommendations:${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}   Run: $0 recover-state${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_RED}❌ System Status: ISSUES FOUND${COLOR_RESET}"
        echo -e "${COLOR_RED}   Issues detected: ${#issues_found[@]}${COLOR_RESET}"
        
        echo -e "\n${COLOR_YELLOW}🔧 Required Actions:${COLOR_RESET}"
        for issue in "${issues_found[@]}"; do
            case "$issue" in
                "missing_root_privileges")
                    echo -e "${COLOR_YELLOW}   - Run with sudo: sudo $0 validate-system${COLOR_RESET}"
                    ;;
                "missing_command_"*)
                    local cmd="${issue#missing_command_}"
                    echo -e "${COLOR_YELLOW}   - Install missing command: $cmd${COLOR_RESET}"
                    ;;
                "low_disk_space")
                    echo -e "${COLOR_YELLOW}   - Free up disk space in $CONTAINERS_DIR${COLOR_RESET}"
                    ;;
                "missing_cgroups"|"missing_memory_cgroup"|"missing_cpu_cgroup")
                    echo -e "${COLOR_YELLOW}   - Enable cgroups in kernel configuration${COLOR_RESET}"
                    ;;
                "memory_cgroup_not_writable"|"cpu_cgroup_not_writable")
                    echo -e "${COLOR_YELLOW}   - Run with sudo: sudo $0 [command]${COLOR_RESET}"
                    echo -e "${COLOR_YELLOW}   - Check cgroup mount options and permissions${COLOR_RESET}"
                    echo -e "${COLOR_YELLOW}   - For detailed help: $0 validate-system${COLOR_RESET}"
                    ;;
                "busybox_not_functional")
                    echo -e "${COLOR_YELLOW}   - Reinstall or fix busybox binary${COLOR_RESET}"
                    ;;
                "corrupted_containers")
                    echo -e "${COLOR_YELLOW}   - Run recovery: $0 recover-state${COLOR_RESET}"
                    ;;
            esac
        done

        # Show additional help for cgroup permission issues
        for issue in "${issues_found[@]}"; do
            if [[ "$issue" == "memory_cgroup_not_writable" || "$issue" == "cpu_cgroup_not_writable" ]]; then
                echo ""
                show_cgroup_permission_help
                break
            fi
        done
    fi

    clear_operation_context "validate_system"

    if [[ "$validation_passed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Emergency cleanup command handler
cmd_emergency_cleanup() {
    log_warn "Starting emergency cleanup..." \
             "Seperti RT melakukan pembersihan darurat kompleks"
    
    init_error_handling
    set_operation_context "emergency_cleanup" ""
    
    echo -e "\n${COLOR_RED}🚨 EMERGENCY CLEANUP MODE${COLOR_RESET}"
    echo -e "${COLOR_RED}=========================${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}⚠️  This will forcefully clean up all container resources!${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   - All running containers will be stopped${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   - All container data will be removed${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   - All network interfaces will be cleaned${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   - All cgroups will be removed${COLOR_RESET}\n"
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Emergency cleanup cancelled by user" \
                 "Pembersihan darurat dibatalkan oleh pengguna"
        clear_operation_context "emergency_cleanup"
        return 0
    fi
    
    log_warn "Proceeding with emergency cleanup..." \
             "Melanjutkan pembersihan darurat..."
    
    # Set recovery flag to prevent recursive cleanup
    RECOVERY_IN_PROGRESS=true
    
    perform_emergency_cleanup
    
    RECOVERY_IN_PROGRESS=false
    
    clear_operation_context "emergency_cleanup"
    
    log_success "Emergency cleanup completed" \
                "Pembersihan darurat selesai"
    
    echo -e "\n${COLOR_GREEN}✅ Emergency cleanup completed successfully${COLOR_RESET}"
    echo -e "${COLOR_GREEN}   All container resources have been cleaned up${COLOR_RESET}"
    echo -e "${COLOR_GREEN}   System is ready for fresh container creation${COLOR_RESET}\n"
    
    return 0
}

# =============================================================================
# MAIN ENTRY POINT PLACEHOLDER
# =============================================================================

# =============================================================================
# CLI COMMAND HANDLERS
# =============================================================================

# Create container command handler
cmd_create_container() {
    local args=("$@")
    
    log_info "Pak RT sedang memproses permintaan pembuatan rumah baru..." \
             "Seperti RT yang menerima pendaftaran warga baru untuk menempati rumah"
    
    # Enhanced security checks for container creation
    if ! check_enhanced_privileges "namespace_operations"; then
        log_error "Insufficient privileges for container creation" \
                  "Wewenang tidak cukup untuk membuat rumah baru"
        return 1
    fi
    
    # Parse and validate arguments with security sanitization
    if ! parse_create_container_args "${args[@]}"; then
        return 1
    fi
    
    if ! validate_create_container_args; then
        return 1
    fi
    
    local container_name="$PARSED_CONTAINER_NAME"
    local memory_mb="$PARSED_MEMORY_MB"
    local cpu_percent="$PARSED_CPU_PERCENT"
    
    # Check if container already exists
    if container_exists "$container_name"; then
        log_error "Container '$container_name' already exists" \
                  "Seperti rumah dengan nama '$container_name' sudah terdaftar di kompleks RT"
        return 1
    fi
    
    log_info "Creating container: $container_name (RAM: ${memory_mb}MB, CPU: ${cpu_percent}%)" \
             "Seperti RT mendaftarkan rumah '$container_name' dengan alokasi listrik ${memory_mb}MB dan waktu kerja ${cpu_percent}%"
    
    # Initialize busybox system if not already done
    if ! init_busybox_system; then
        log_error "Failed to initialize busybox system" \
                  "Gagal menyiapkan peralatan dasar untuk kompleks"
        return 1
    fi
    
    # Create container directory structure
    local container_dir="$CONTAINERS_DIR/$container_name"
    create_directory "$container_dir"
    create_directory "$container_dir/rootfs"
    create_directory "$container_dir/logs"
    
    # Setup container namespaces
    if ! setup_container_namespaces "$container_name"; then
        log_error "Failed to setup namespaces for container: $container_name" \
                  "Gagal menyiapkan sistem rumah untuk '$container_name'"
        cleanup_container_resources "$container_name"
        return 1
    fi
    
    # Setup busybox for container
    if ! setup_busybox "$container_name"; then
        log_error "Failed to setup busybox for container: $container_name" \
                  "Gagal menyiapkan peralatan rumah untuk '$container_name'"
        cleanup_container_resources "$container_name"
        return 1
    fi
    
    # Create cgroups for resource management
    if ! create_container_cgroup "$container_name" "$memory_mb" "$cpu_percent"; then
        log_error "Failed to create cgroups for container: $container_name" \
                  "Gagal mengatur pembatasan listrik dan air untuk rumah '$container_name'"
        cleanup_container_resources "$container_name"
        return 1
    fi

    # Allocate IP address for container
    log_info "Allocating IP address for container" \
             "Seperti RT mengalokasikan nomor telepon untuk rumah"

    local container_ip
    if ! container_ip=$(get_next_container_ip); then
        log_error "Failed to allocate IP address for container" \
                  "Gagal mendapatkan nomor telepon rumah"
        cleanup_container_resources "$container_name"
        return 1
    fi

    log_info "Allocated IP address: $container_ip" \
             "Nomor telepon yang dialokasikan: $container_ip"

    # Reserve IP address
    set_container_ip "$container_name" "$container_ip"

    # Setup network namespace
    if ! create_container_network "$container_name" "$container_ip"; then
        log_error "Failed to setup network for container: $container_name" \
                  "Gagal menyiapkan sambungan telepon untuk rumah '$container_name'"
        cleanup_container_resources "$container_name"
        return 1
    fi
    
    # Save container metadata
    save_container_metadata "$container_name" "$memory_mb" "$cpu_percent"
    
    # Verify container isolation after creation
    log_info "Verifying container security and isolation..." \
             "Seperti RT memeriksa keamanan dan isolasi rumah yang baru dibuat"
    
    if ! verify_container_isolation "$container_name" 2>/dev/null; then
        log_warn "Container isolation verification failed, but container was created" \
                 "Verifikasi isolasi gagal, tapi rumah sudah berhasil dibuat"
    fi
    
    log_success "Container '$container_name' created successfully!" \
                "Rumah '$container_name' berhasil didaftarkan dan siap ditempati warga"
    
    log_info "Next steps:" \
             "Langkah selanjutnya untuk menempati rumah:"
    echo "  1. Run container: $0 run-container $container_name"
    echo "  2. List containers: $0 list-containers"
    echo "  3. Delete container: $0 delete-container $container_name"
    
    return 0
}

# List containers command handler
cmd_list_containers() {
    log_info "Pak RT sedang memeriksa daftar semua rumah di kompleks..." \
             "Seperti RT yang melakukan pendataan warga dan status rumah"
    
    if [[ ! -d "$CONTAINERS_DIR" ]]; then
        log_info "No containers directory found" \
                 "Belum ada kompleks perumahan yang terdaftar"
        echo "No containers created yet."
        echo "Use '$0 create-container <name>' to create your first container."
        return 0
    fi
    
    local containers=($(find "$CONTAINERS_DIR" -maxdepth 1 -type d -not -path "$CONTAINERS_DIR" -exec basename {} \; 2>/dev/null | sort))
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        log_info "No containers found" \
                 "Kompleks perumahan masih kosong, belum ada rumah yang terdaftar"
        echo "No containers created yet."
        echo "Use '$0 create-container <name>' to create your first container."
        return 0
    fi
    
    echo ""
    echo "🏘️  RT Container Runtime - Daftar Rumah Kompleks"
    echo "=================================================="
    printf "%-20s %-10s %-15s %-15s %-20s\n" "NAMA RUMAH" "STATUS" "RAM (MB)" "CPU (%)" "IP ADDRESS"
    echo "--------------------------------------------------"
    
    for container_name in "${containers[@]}"; do
        local status="stopped"
        local memory_mb="N/A"
        local cpu_percent="N/A"
        local ip_address="N/A"
        
        # Check if container is running
        if container_is_running "$container_name"; then
            status="running"
        elif [[ -f "$CONTAINERS_DIR/$container_name/config.json" ]]; then
            status="created"
        fi
        
        # Get container metadata
        local config_file="$CONTAINERS_DIR/$container_name/config.json"
        if [[ -f "$config_file" ]]; then
            memory_mb=$(grep -o '"memory_mb":[0-9]*' "$config_file" 2>/dev/null | cut -d: -f2 || echo "N/A")
            cpu_percent=$(grep -o '"cpu_percentage":[0-9]*' "$config_file" 2>/dev/null | cut -d: -f2 || echo "N/A")
            ip_address=$(grep -o '"ip_address":"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f4 || echo "N/A")
        fi
        
        # Color code status
        local status_colored
        case "$status" in
            "running")
                status_colored="${COLOR_GREEN}running${COLOR_RESET}"
                ;;
            "created")
                status_colored="${COLOR_YELLOW}created${COLOR_RESET}"
                ;;
            *)
                status_colored="${COLOR_RED}stopped${COLOR_RESET}"
                ;;
        esac
        
        printf "%-20s %-20s %-15s %-15s %-20s\n" "$container_name" "$status_colored" "$memory_mb" "$cpu_percent" "$ip_address"
    done
    
    echo ""
    echo "📊 Summary:"
    echo "   Total containers: ${#containers[@]}"
    echo "   🏃 Running: $(count_running_containers)"
    echo "   📦 Created: $(count_created_containers)"
    echo "   ⏹️ Stopped: $(count_stopped_containers)"
    echo ""
    echo "💡 Analogi: Seperti RT yang memiliki data lengkap semua rumah dan penghuninya"
    
    return 0
}

# Run container command handler
cmd_run_container() {
    local container_name="$1"
    local command_to_run="${2:-/bin/sh}"
    
    if [[ -z "$container_name" ]]; then
        log_error "Container name is required" \
                  "Seperti RT perlu tahu rumah mana yang akan dibuka untuk ditempati"
        echo "Usage: $0 run-container <name> [command]"
        return 1
    fi
    
    if ! validate_container_name "$container_name"; then
        return 1
    fi
    
    if ! container_exists "$container_name"; then
        log_error "Container '$container_name' does not exist" \
                  "Rumah '$container_name' tidak terdaftar di kompleks RT"
        echo "Use '$0 list-containers' to see available containers."
        echo "Use '$0 create-container $container_name' to create it first."
        return 1
    fi
    
    if container_is_running "$container_name"; then
        log_warn "Container '$container_name' is already running" \
                 "Rumah '$container_name' sudah ditempati warga"
        echo "Use 'nsenter' to enter the running container or stop it first."
        return 1
    fi
    
    log_info "Pak RT sedang membuka rumah '$container_name' untuk ditempati..." \
             "Seperti RT yang membuka pintu rumah dan menyalakan listrik untuk warga baru"
    
    # Start container with all namespaces and resource limits
    if ! start_container_process "$container_name" "$command_to_run"; then
        log_error "Failed to start container: $container_name" \
                  "Gagal membuka rumah '$container_name' untuk ditempati"
        return 1
    fi
    
    log_success "Container '$container_name' started successfully!" \
                "Rumah '$container_name' berhasil dibuka dan siap ditempati"
    
    return 0
}

# Delete container command handler
cmd_delete_container() {
    local container_name="$1"
    
    if [[ -z "$container_name" ]]; then
        log_error "Container name is required" \
                  "Seperti RT perlu tahu rumah mana yang akan dihapus dari kompleks"
        echo "Usage: $0 delete-container <name>"
        return 1
    fi
    
    if ! validate_container_name "$container_name"; then
        return 1
    fi
    
    if ! container_exists "$container_name"; then
        log_error "Container '$container_name' does not exist" \
                  "Rumah '$container_name' tidak terdaftar di kompleks RT"
        echo "Use '$0 list-containers' to see available containers."
        return 1
    fi
    
    # Confirmation prompt
    echo "⚠️  WARNING: This will permanently delete container '$container_name' and all its data!"
    echo "🏠 Analogi: Seperti RT yang akan menghancurkan rumah dan membersihkan semua fasilitasnya"
    echo ""
    read -p "Are you sure you want to delete container '$container_name'? (yes/no): " confirmation
    
    case "$confirmation" in
        yes|YES|y|Y)
            log_info "RT confirmed deletion of container: $container_name" \
                     "RT mengkonfirmasi penghapusan rumah '$container_name'"
            ;;
        *)
            log_info "Container deletion cancelled by user" \
                     "Penghapusan rumah dibatalkan oleh RT"
            return 0
            ;;
    esac
    
    log_info "Pak RT sedang menghapus rumah '$container_name' dari kompleks..." \
             "Seperti RT yang membongkar rumah dan membersihkan semua fasilitas"
    
    # Stop container if running
    if container_is_running "$container_name"; then
        log_info "Stopping running container first..." \
                 "Mengevakuasi penghuni rumah terlebih dahulu..."
        stop_container_process "$container_name"
    fi
    
    # Cleanup all container resources
    if ! cleanup_container_resources "$container_name"; then
        log_error "Failed to cleanup some resources for container: $container_name" \
                  "Gagal membersihkan beberapa fasilitas rumah '$container_name'"
        log_warn "Some resources may need manual cleanup" \
                 "Beberapa fasilitas mungkin perlu dibersihkan manual oleh RT"
    fi
    
    # Remove container directory
    local container_dir="$CONTAINERS_DIR/$container_name"
    if [[ -d "$container_dir" ]]; then
        rm -rf "$container_dir"
        log_info "Container directory removed: $container_dir" \
                 "Folder rumah '$container_name' telah dihapus dari arsip RT"
    fi
    
    log_success "Container '$container_name' deleted successfully!" \
                "Rumah '$container_name' berhasil dihapus dari kompleks RT"
    
    return 0
}

# Cleanup all containers command handler
cmd_cleanup_all() {
    log_warn "RT EMERGENCY CLEANUP - This will remove ALL containers and resources!" \
             "PEMBERSIHAN DARURAT RT - Ini akan menghapus SEMUA rumah dan fasilitas kompleks!"
    
    echo "⚠️  EMERGENCY CLEANUP WARNING!"
    echo "🏘️  This will permanently delete ALL containers and cleanup ALL resources!"
    echo "📋 Analogi: Seperti RT yang melakukan pembersihan total kompleks dalam keadaan darurat"
    echo ""
    echo "This includes:"
    echo "  - All container processes"
    echo "  - All namespaces"
    echo "  - All network interfaces"
    echo "  - All cgroups"
    echo "  - All container data"
    echo ""
    read -p "Are you ABSOLUTELY sure you want to cleanup everything? (type 'YES/yes/y/Y' to confirm): " confirmation
    
    case "$confirmation" in
        yes|YES|y|Y)
            log_info "RT confirmed deletion of emergency cleanup" \
                     "RT mengkonfirmasi pembersihan darurat"
            ;;
        *)
           log_info "Emergency cleanup cancelled by RT" \
                 "Pembersihan darurat dibatalkan oleh RT"
            ;;
    esac

    log_info "RT starting emergency cleanup of entire complex..." \
             "RT memulai pembersihan darurat seluruh kompleks perumahan..."
    
    local cleanup_errors=0
    
    # Get list of all containers
    local containers=()
    if [[ -d "$CONTAINERS_DIR" ]]; then
        containers=($(find "$CONTAINERS_DIR" -maxdepth 1 -type d -not -path "$CONTAINERS_DIR" -exec basename {} \; 2>/dev/null))
    fi
    
    # Stop and cleanup each container
    for container_name in "${containers[@]}"; do
        log_info "Cleaning up container: $container_name" \
                 "Membersihkan rumah: $container_name"
        
        # Stop container if running
        if container_is_running "$container_name"; then
            stop_container_process "$container_name" || ((cleanup_errors++))
        fi
        
        # Cleanup container resources
        cleanup_container_resources "$container_name" || ((cleanup_errors++))
    done
    
    # Remove entire containers directory
    if [[ -d "$CONTAINERS_DIR" ]]; then
        log_info "Removing containers directory: $CONTAINERS_DIR" \
                 "Menghapus seluruh direktori kompleks perumahan"
        rm -rf "$CONTAINERS_DIR" || ((cleanup_errors++))
    fi
    
    # Cleanup any remaining network namespaces
    log_info "Cleaning up remaining network namespaces..." \
             "Membersihkan sisa-sisa sambungan telepon kompleks..."
    cleanup_all_network_namespaces || ((cleanup_errors++))
    
    # Cleanup any remaining cgroups
    log_info "Cleaning up remaining cgroups..." \
             "Membersihkan sisa-sisa pembatasan listrik dan air..."
    cleanup_all_cgroups || ((cleanup_errors++))
    
    if [[ $cleanup_errors -eq 0 ]]; then
        log_success "Emergency cleanup completed successfully!" \
                    "Pembersihan darurat RT berhasil diselesaikan - kompleks kembali bersih"
    else
        log_warn "Emergency cleanup completed with $cleanup_errors errors" \
                 "Pembersihan darurat selesai dengan $cleanup_errors masalah yang perlu perhatian RT"
        log_info "Some resources may need manual cleanup" \
                 "Beberapa fasilitas mungkin perlu dibersihkan manual"
    fi
    
    return $cleanup_errors
}

# Comprehensive container resource cleanup
cleanup_container_resources() {
    local container_name=$1
    
    log_info "Cleaning up all resources for container: $container_name" \
             "Membersihkan semua fasilitas rumah: $container_name"
    
    local cleanup_errors=0
    
    # Stop container process if running
    if container_is_running "$container_name"; then
        log_info "Stopping container process..." \
                 "Menghentikan aktivitas penghuni rumah..."
        stop_container_process "$container_name" || ((cleanup_errors++))
    fi
    
    # Cleanup network resources
    log_debug "Cleaning up network resources..." \
              "Membersihkan sambungan telepon rumah..."
    cleanup_container_network "$container_name" || ((cleanup_errors++))
    
    # Cleanup cgroup resources
    log_debug "Cleaning up cgroup resources..." \
              "Membersihkan pembatasan listrik dan air rumah..."
    cleanup_container_cgroups "$container_name" || ((cleanup_errors++))
    
    # Cleanup namespace resources
    log_debug "Cleaning up namespace resources..." \
              "Membersihkan sistem internal rumah..."
    cleanup_container_namespaces "$container_name" || ((cleanup_errors++))
    
    # Remove IP address reservation
    local container_ip=$(get_container_ip "$container_name" 2>/dev/null || true)
    if [[ -n "$container_ip" ]]; then
        unset_container_ip "$container_name"
        log_debug "Released IP address for container: $container_name"
    fi
    
    if [[ $cleanup_errors -eq 0 ]]; then
        log_success "All resources cleaned up for container: $container_name" \
                    "Semua fasilitas rumah '$container_name' berhasil dibersihkan"
    else
        log_warn "Resource cleanup completed with $cleanup_errors errors for container: $container_name" \
                 "Pembersihan rumah selesai dengan $cleanup_errors masalah"
    fi
    
    return $cleanup_errors
}

# Save container metadata to config file
save_container_metadata() {
    local container_name=$1
    local memory_mb=$2
    local cpu_percent=$3
    local ip_address=$(get_container_ip "$container_name" 2>/dev/null || echo "N/A")
    
    local config_file="$CONTAINERS_DIR/$container_name/config.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Use secure temporary file for atomic write
    local temp_config=$(create_secure_temp_file "container_config" ".json")
    if [[ -z "$temp_config" ]]; then
        log_error "Failed to create secure temporary file for container metadata" \
                  "Gagal membuat file sementara yang aman untuk data rumah"
        return 1
    fi
    
    cat > "$temp_config" << EOF
{
  "name": "$container_name",
  "created": "$timestamp",
  "status": "created",
  "resources": {
    "memory_mb": $memory_mb,
    "cpu_percentage": $cpu_percent
  },
  "network": {
    "ip_address": "$ip_address",
    "veth_host": "veth-$container_name-host",
    "veth_container": "veth-$container_name-cont"
  },
  "namespaces": {
    "pid": "/proc/\$PID/ns/pid",
    "net": "/proc/\$PID/ns/net",
    "mnt": "/proc/\$PID/ns/mnt",
    "uts": "/proc/\$PID/ns/uts",
    "ipc": "/proc/\$PID/ns/ipc",
    "user": "/proc/\$PID/ns/user"
  },
  "cgroups": {
    "memory": "/sys/fs/cgroup/memory/container-$container_name",
    "cpu": "/sys/fs/cgroup/cpu/container-$container_name"
  },
  "pid": null
}
EOF
    
    # Atomically move temp file to final location
    if mv "$temp_config" "$config_file"; then
        # Set secure permissions on config file
        chmod 644 "$config_file"
        log_debug "Container metadata saved securely to: $config_file" \
                  "Data rumah disimpan dengan aman dalam arsip RT"
    else
        log_error "Failed to save container metadata" \
                  "Gagal menyimpan data rumah dalam arsip RT"
        rm -f "$temp_config" 2>/dev/null || true
        return 1
    fi
}

# Start container process with all namespaces and limits
start_container_process() {
    local container_name=$1
    local command_to_run=${2:-"/bin/sh"}
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
    local pid_file="$CONTAINERS_DIR/$container_name/container.pid"
    
    log_info "Starting container process for: $container_name" \
             "Memulai aktivitas penghuni rumah: $container_name"
    
    # Create startup script for the container using secure temporary file
    local startup_script="$CONTAINERS_DIR/$container_name/startup.sh"
    local temp_startup=$(create_secure_temp_file "container_startup" ".sh")
    if [[ -z "$temp_startup" ]]; then
        log_error "Failed to create secure temporary file for startup script" \
                  "Gagal membuat file sementara yang aman untuk skrip startup"
        return 1
    fi
    
    cat > "$temp_startup" << EOF
#!/bin/bash
set -e

# Mount essential filesystems
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t tmpfs tmpfs /tmp 2>/dev/null || true

# Set hostname
hostname "$container_name" 2>/dev/null || true

# Setup basic environment
export PATH="/bin:/sbin:/usr/bin:/usr/sbin"
export HOME="/root"
export USER="root"
export SHELL="/bin/sh"

# Change to root directory
cd /

# Execute the requested command
exec $command_to_run
EOF
    
    # Atomically move temp file to final location
    if mv "$temp_startup" "$startup_script"; then
        chmod +x "$startup_script"
        log_debug "Startup script created securely: $startup_script" \
                  "Skrip startup dibuat dengan aman"
    else
        log_error "Failed to create startup script" \
                  "Gagal membuat skrip startup"
        rm -f "$temp_startup" 2>/dev/null || true
        return 1
    fi
    
    # Start container with all namespaces
    log_info "Launching container with full isolation..." \
             "Meluncurkan rumah dengan sistem isolasi lengkap..."
    
    # Use unshare to create all namespaces and start the container
    unshare --pid --mount --uts --ipc --net --user --map-root-user \
        chroot "$container_rootfs" /startup.sh &
    
    local container_pid=$!
    echo "$container_pid" > "$pid_file"
    
    # Wait a moment to ensure container started
    sleep 1
    
    # Check if container is still running
    if ! kill -0 "$container_pid" 2>/dev/null; then
        log_error "Container failed to start" \
                  "Rumah gagal dibuka untuk penghuni"
        rm -f "$pid_file"
        return 1
    fi
    
    # Add process to cgroups
    add_process_to_container_cgroups "$container_name" "$container_pid"
    
    # Update container status
    update_container_status "$container_name" "running" "$container_pid"
    
    log_success "Container '$container_name' started with PID: $container_pid" \
                "Rumah '$container_name' berhasil dibuka dengan penghuni PID: $container_pid"
    
    # Show container information
    echo ""
    echo "🏠 Container Information:"
    echo "   Name: $container_name"
    echo "   PID: $container_pid"
    echo "   Command: $command_to_run"
    echo "   IP: $(get_container_ip "$container_name" 2>/dev/null || echo "N/A")"
    echo ""
    echo "💡 To connect to the container:"
    echo "   nsenter -t $container_pid -p -m -u -i -n $command_to_run"
    echo ""
    
    return 0
}

# Stop container process
stop_container_process() {
    local container_name=$1
    local pid_file="$CONTAINERS_DIR/$container_name/container.pid"
    
    if [[ ! -f "$pid_file" ]]; then
        log_debug "No PID file found for container: $container_name"
        return 0
    fi
    
    local container_pid=$(cat "$pid_file")
    
    if ! kill -0 "$container_pid" 2>/dev/null; then
        log_debug "Container process already stopped: $container_name"
        rm -f "$pid_file"
        return 0
    fi
    
    log_info "Stopping container process: $container_pid" \
             "Menghentikan aktivitas penghuni rumah"
    
    # Try graceful shutdown first
    kill -TERM "$container_pid" 2>/dev/null || true
    
    # Wait for graceful shutdown
    local timeout=10
    while [[ $timeout -gt 0 ]] && kill -0 "$container_pid" 2>/dev/null; do
        sleep 1
        ((timeout--))
    done
    
    # Force kill if still running
    if kill -0 "$container_pid" 2>/dev/null; then
        log_warn "Force killing container process: $container_pid" \
                 "Menghentikan paksa aktivitas penghuni rumah"
        kill -KILL "$container_pid" 2>/dev/null || true
    fi
    
    rm -f "$pid_file"
    update_container_status "$container_name" "stopped"
    
    log_success "Container process stopped: $container_name" \
                "Aktivitas penghuni rumah berhasil dihentikan"
    
    return 0
}

# Update container status in config file
update_container_status() {
    local container_name=$1
    local status=$2
    local pid=${3:-"null"}
    local config_file="$CONTAINERS_DIR/$container_name/config.json"
    
    if [[ -f "$config_file" ]]; then
        # Update status and PID in JSON file
        sed -i "s/\"status\": \"[^\"]*\"/\"status\": \"$status\"/" "$config_file"
        sed -i "s/\"pid\": [^,}]*/\"pid\": $pid/" "$config_file"
        
        log_debug "Updated container status: $container_name -> $status"
    fi
}

# Add process to container cgroups
add_process_to_container_cgroups() {
    local container_name=$1
    local pid=$2
    
    local memory_cgroup="/sys/fs/cgroup/memory/container-$container_name"
    local cpu_cgroup="/sys/fs/cgroup/cpu/container-$container_name"
    
    # Add to memory cgroup
    if [[ -d "$memory_cgroup" ]]; then
        echo "$pid" > "$memory_cgroup/cgroup.procs" 2>/dev/null || true
        log_debug "Added PID $pid to memory cgroup: $container_name"
    fi
    
    # Add to CPU cgroup
    if [[ -d "$cpu_cgroup" ]]; then
        echo "$pid" > "$cpu_cgroup/cgroup.procs" 2>/dev/null || true
        log_debug "Added PID $pid to CPU cgroup: $container_name"
    fi
}

# Cleanup all network namespaces
cleanup_all_network_namespaces() {
    log_info "Cleaning up all network namespaces..." \
             "Membersihkan semua sambungan telepon kompleks..."
    
    local cleanup_count=0
    
    # List all network namespaces and clean them up
    if command -v ip &> /dev/null; then
        local namespaces=$(ip netns list 2>/dev/null | grep -E "container-|test-" | awk '{print $1}' || true)
        
        for ns in $namespaces; do
            log_debug "Removing network namespace: $ns"
            ip netns delete "$ns" 2>/dev/null || true
            ((cleanup_count++))
        done
    fi
    
    log_info "Cleaned up $cleanup_count network namespaces" \
             "Berhasil membersihkan $cleanup_count sambungan telepon"
    
    return 0
}

# Cleanup all cgroups
cleanup_all_cgroups() {
    log_info "Cleaning up all container cgroups..." \
             "Membersihkan semua pembatasan listrik dan air kompleks..."
    
    local cleanup_count=0
    
    # Cleanup memory cgroups
    if [[ -d "/sys/fs/cgroup/memory" ]]; then
        local memory_cgroups=$(find /sys/fs/cgroup/memory -name "container-*" -type d 2>/dev/null || true)
        for cgroup in $memory_cgroups; do
            log_debug "Removing memory cgroup: $cgroup"
            rmdir "$cgroup" 2>/dev/null || true
            ((cleanup_count++))
        done
    fi
    
    # Cleanup CPU cgroups
    if [[ -d "/sys/fs/cgroup/cpu" ]]; then
        local cpu_cgroups=$(find /sys/fs/cgroup/cpu -name "container-*" -type d 2>/dev/null || true)
        for cgroup in $cpu_cgroups; do
            log_debug "Removing CPU cgroup: $cgroup"
            rmdir "$cgroup" 2>/dev/null || true
            ((cleanup_count++))
        done
    fi
    
    log_info "Cleaned up $cleanup_count cgroups" \
             "Berhasil membersihkan $cleanup_count pembatasan fasilitas"
    
    return 0
}

# Helper functions for container counting
count_running_containers() {
    local count=0
    if [[ -d "$CONTAINERS_DIR" ]]; then
        local containers=($(find "$CONTAINERS_DIR" -maxdepth 1 -type d -not -path "$CONTAINERS_DIR" -exec basename {} \; 2>/dev/null))
        for container_name in "${containers[@]}"; do
            if container_is_running "$container_name"; then
                ((count++))
            fi
        done
    fi
    echo $count
}

count_created_containers() {
    local count=0
    if [[ -d "$CONTAINERS_DIR" ]]; then
        local containers=($(find "$CONTAINERS_DIR" -maxdepth 1 -type d -not -path "$CONTAINERS_DIR" -exec basename {} \; 2>/dev/null))
        for container_name in "${containers[@]}"; do
            if [[ -f "$CONTAINERS_DIR/$container_name/config.json" ]] && ! container_is_running "$container_name"; then
                ((count++))
            fi
        done
    fi
    echo $count
}

count_stopped_containers() {
    local count=0
    if [[ -d "$CONTAINERS_DIR" ]]; then
        local containers=($(find "$CONTAINERS_DIR" -maxdepth 1 -type d -not -path "$CONTAINERS_DIR" -exec basename {} \; 2>/dev/null))
        for container_name in "${containers[@]}"; do
            if [[ ! -f "$CONTAINERS_DIR/$container_name/config.json" ]] && ! container_is_running "$container_name"; then
                ((count++))
            fi
        done
    fi
    echo $count
}

# Show usage information
show_usage() {
    cat << EOF
RT (Rukun Tetangga) Container Runtime v$SCRIPT_VERSION
Educational container runtime using Linux namespaces and cgroups

USAGE:
    $0 <command> [options]

CONTAINER LIFECYCLE COMMANDS:
    create-container <name> [--ram=MB] [--cpu=PERCENT]
                                    Create new container with resource limits
    list-containers                 List all containers with status and resources
    run-container <name> [command]  Start container and provide interactive shell
    delete-container <name>         Delete container and cleanup all resources
    cleanup-all                     Emergency cleanup of all containers and resources

ERROR HANDLING & RECOVERY COMMANDS:
    recover-state [container]       Detect and recover corrupted container states
    validate-system                 Comprehensive system health check
    emergency-cleanup               Force cleanup all resources (destructive)

SECURITY COMMANDS:
    security-audit [scope] [container]  Perform security audit (scope: all|system|container)

NETWORK COMMANDS (Task 6 Implementation):
    test-network                    Test network functionality
    create-test-network [name1] [name2]  Create test network with 2 containers
    cleanup-test-network            Cleanup test network
    show-network <container>        Show network info for container
    test-connectivity <cont1> <cont2>  Test connectivity between containers
    monitor-network <container> [duration]  Monitor network activity
    debug-network <container>       Debug network issues
    list-networks                   List all container networks

EXAMPLES:
    # Container lifecycle
    $0 create-container rumah-a --ram=512 --cpu=50
    $0 list-containers
    $0 run-container rumah-a
    $0 run-container rumah-a /bin/ls
    $0 delete-container rumah-a
    $0 cleanup-all

    # Error handling and recovery
    $0 validate-system
    $0 recover-state
    $0 recover-state webapp
    $0 emergency-cleanup

    # Security audit
    $0 security-audit
    $0 security-audit system
    $0 security-audit container webapp

    # Network testing
    $0 test-network
    $0 create-test-network
    $0 show-network test-container-1
    $0 test-connectivity test-container-1 test-container-2

ANALOGY:
    RT Container Runtime seperti Rukun Tetangga (RT) yang mengatur kompleks perumahan.
    - create-container: RT mendaftarkan rumah baru dengan alokasi listrik dan air
    - list-containers: RT melihat daftar semua rumah dan status penghuninya
    - run-container: RT membuka pintu rumah untuk ditempati warga
    - delete-container: RT menghapus rumah dan membersihkan semua fasilitasnya
    - cleanup-all: RT membersihkan seluruh kompleks dalam keadaan darurat

For more information, visit: https://github.com/container-learning/rt-runtime
EOF
}

# Main function (to be implemented in later tasks)
main() {
    local command=${1:-""}

    # Show usage if no command provided
    if [[ -z "$command" ]]; then
        show_usage
        exit 0
    fi

    # Check OS compatibility first
    if [[ "$MACOS_MODE" == "true" ]]; then
        check_os_compatibility
        echo ""
        read -p "Continue anyway for educational purposes? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Exiting. For full functionality, use Linux or Docker Desktop" \
                     "Keluar. Untuk fungsi penuh, gunakan Linux atau Docker Desktop"
            exit 0
        fi
        log_info "Continuing in educational mode with limited functionality" \
                 "Melanjutkan dalam mode edukasi dengan fungsi terbatas"
        echo ""
    fi

    # Setup signal handlers
    setup_signal_handlers
    
    # Parse global flags first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                enable_verbose_mode
                shift
                ;;
            --debug)
                enable_debug_mode
                shift
                ;;
            --monitor)
                enable_monitoring_mode
                shift
                ;;
            --rootless)
                ROOTLESS_MODE=true
                init_paths  # Initialize paths for rootless mode
                log_info "Rootless mode enabled" \
                         "Seperti RT yang bekerja dengan wewenang terbatas"
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Update command after flag parsing
    command=${1:-""}
    
    # Setup rootless environment if enabled
    if [[ "$ROOTLESS_MODE" == "true" ]]; then
        if ! check_rootless_support; then
            log_error "Rootless mode is not supported on this system" \
                      "Mode tanpa wewenang penuh tidak didukung sistem ini"
            exit 1
        fi
        setup_rootless_environment
    fi

    # Check dependencies and privileges for commands that need them
    case "$command" in
        create-container|run-container|delete-container|cleanup-all|test-network|create-test-network|cleanup-test-network|show-network|test-connectivity|monitor-network|debug-network|list-networks|monitor|show-topology|debug|recover-state|validate-system|emergency-cleanup|security-audit)
            check_dependencies
            check_privileges
            ;;
    esac

    # Create base directories
    create_directory "$CONTAINERS_DIR"
    
    # Handle commands
    case "$command" in
        "create-container")
            shift  # Remove command from arguments
            cmd_create_container "$@"
            ;;
        "list-containers")
            cmd_list_containers
            ;;
        "run-container")
            cmd_run_container "$2" "$3"
            ;;
        "delete-container")
            cmd_delete_container "$2"
            ;;
        "cleanup-all")
            cmd_cleanup_all
            ;;
        "test-network")
            test_network_functionality
            ;;
        "create-test-network")
            local container1=${2:-"test-container-1"}
            local container2=${3:-"test-container-2"}
            create_test_network "$container1" "$container2"
            ;;
        "cleanup-test-network")
            cleanup_test_network
            ;;
        "show-network")
            local container_name=$2
            if [[ -z "$container_name" ]]; then
                log_error "Container name required for show-network command"
                echo "Usage: $0 show-network <container_name>"
                exit 1
            fi
            show_container_network_info "$container_name"
            ;;
        "test-connectivity")
            local container1=$2
            local container2=$3
            if [[ -z "$container1" || -z "$container2" ]]; then
                log_error "Two container names required for test-connectivity command"
                echo "Usage: $0 test-connectivity <container1> <container2>"
                exit 1
            fi
            test_container_connectivity "$container1" "$container2"
            ;;
        "monitor-network")
            local container_name=$2
            local duration=${3:-10}
            if [[ -z "$container_name" ]]; then
                log_error "Container name required for monitor-network command"
                echo "Usage: $0 monitor-network <container_name> [duration]"
                exit 1
            fi
            monitor_container_network "$container_name" "$duration"
            ;;
        "debug-network")
            local container_name=$2
            if [[ -z "$container_name" ]]; then
                log_error "Container name required for debug-network command"
                echo "Usage: $0 debug-network <container_name>"
                exit 1
            fi
            debug_container_network "$container_name"
            ;;
        "list-networks")
            list_container_networks
            ;;
        "monitor")
            local container_name=$2
            local duration=${3:-30}
            if [[ -z "$container_name" ]]; then
                log_error "Container name required for monitor command" \
                          "Seperti RT perlu tahu rumah mana yang akan dipantau"
                echo "Usage: $0 monitor <container_name> [duration_seconds]"
                exit 1
            fi
            monitor_container_resources "$container_name" "$duration"
            ;;
        "show-topology")
            show_network_topology
            ;;
        "debug")
            local component=${2:-"all"}
            show_debug_info "$component"
            ;;
        "recover-state"|"recover")
            local container_name=${2:-""}
            cmd_recover_state "$container_name"
            ;;
        "validate-system")
            cmd_validate_system
            ;;
        "emergency-cleanup")
            cmd_emergency_cleanup
            ;;
        "security-audit")
            local scope=${2:-"all"}
            local container_name=${3:-""}
            cmd_security_audit "$scope" "$container_name"
            ;;
        "help"|"--help"|"-h")
            local topic=${2:-""}
            if [[ -n "$topic" ]]; then
                show_interactive_help "$topic"
            else
                show_interactive_help "main"
            fi
            ;;
        *)
            log_error "Unknown command: $command" \
                      "Seperti RT menerima permintaan yang tidak dimengerti"
            echo ""
            show_interactive_help "main"
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi