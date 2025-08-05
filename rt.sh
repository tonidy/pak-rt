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

# System paths and directories
readonly CONTAINERS_DIR="/tmp/containers"
readonly BUSYBOX_PATH="/tmp/containers/busybox"
readonly CGROUP_ROOT="/sys/fs/cgroup"

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
                [[ -n "$analogy" ]] && echo -e "${COLOR_RED}        📝 Analoginya: $analogy${COLOR_RESET}" >&2
                ;;
            $LOG_WARN)
                echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET}  [$timestamp] ⚠️  $message" >&2
                [[ -n "$analogy" ]] && echo -e "${COLOR_YELLOW}        📝 Analoginya: $analogy${COLOR_RESET}" >&2
                ;;
            $LOG_INFO)
                echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET}  [$timestamp] ℹ️  $message"
                [[ -n "$analogy" ]] && echo -e "${COLOR_GREEN}        📝 Analoginya: $analogy${COLOR_RESET}"
                ;;
            $LOG_DEBUG)
                echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} [$timestamp] 🔍 $message"
                [[ -n "$analogy" ]] && echo -e "${COLOR_CYAN}        📝 Analoginya: $analogy${COLOR_RESET}"
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
    [[ -n "$analogy" ]] && echo -e "${COLOR_BLUE}   🏘️  Analoginya: $analogy${COLOR_RESET}"
}

# Success message with celebration
log_success() {
    local message=$1
    local analogy=${2:-"Seperti RT berhasil menyelesaikan tugas untuk warga kompleks"}
    
    echo -e "\n${COLOR_GREEN}✅ SUCCESS: $message${COLOR_RESET}"
    echo -e "${COLOR_GREEN}   🎉 Analoginya: $analogy${COLOR_RESET}\n"
}

# =============================================================================
# INPUT VALIDATION AND ERROR HANDLING UTILITIES
# =============================================================================

# Validate container name
validate_container_name() {
    local name=$1
    
    if [[ -z "$name" ]]; then
        log_error "Container name cannot be empty" "Seperti rumah harus punya nama/nomor untuk identifikasi RT"
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
    
    return 0
}

# Validate memory limit
validate_memory_limit() {
    local memory_mb=$1
    
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

# Validate CPU percentage
validate_cpu_percentage() {
    local cpu_percent=$1
    
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

# Check if running as root or with sufficient privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges for namespace and cgroup operations" \
                  "Seperti RT memerlukan wewenang khusus untuk mengatur kompleks perumahan"
        log_info "Please run with: sudo $0 $*"
        exit 1
    fi
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
    
    # Test 2: Check busybox version
    local version_output
    if ! version_output=$("$BUSYBOX_PATH" --help 2>&1 | head -1); then
        log_error "Failed to get busybox version" \
                  "Seperti tidak bisa mengecek spesifikasi peralatan rumah"
        return 1
    fi
    
    log_info "Busybox version: $version_output" \
             "Seperti mengecek spesifikasi peralatan yang tersedia"
    
    # Test 3: Test basic commands
    local test_commands=("echo" "ls" "cat" "ps" "sh")
    
    for cmd in "${test_commands[@]}"; do
        if ! "$BUSYBOX_PATH" "$cmd" --help &>/dev/null; then
            log_warn "Command '$cmd' not available in busybox" \
                     "Seperti ada peralatan yang tidak tersedia di set standar"
        else
            log_debug "Command '$cmd' available and working"
        fi
    done
    
    # Test 4: Test shell functionality
    local test_script='echo "Hello from busybox shell"'
    if ! echo "$test_script" | "$BUSYBOX_PATH" sh; then
        log_error "Busybox shell test failed" \
                  "Seperti sistem komunikasi rumah tidak berfungsi"
        return 1
    fi
    
    log_success "All busybox functionality tests passed" \
                "Semua peralatan rumah telah diuji dan berfungsi dengan baik"
    
    return 0
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
declare -A ACTIVE_NAMESPACES

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
    local hostname=${2:-$container_name}
    
    log_step 3 "Creating UTS namespace for container: $container_name" \
              "Seperti memberikan nama rumah sendiri yang unik di kompleks"
    
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    create_directory "$ns_dir"
    
    # Validate hostname
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
        log_warn "Invalid hostname format, using container name" \
                 "Format nama rumah tidak sesuai aturan, menggunakan nama default"
        hostname="$container_name"
    fi
    
    log_info "Setting container hostname to: $hostname" \
             "Seperti memasang papan nama rumah: $hostname"
    
    # Create UTS namespace configuration
    cat > "$ns_dir/uts.conf" << EOF
uts_namespace_enabled=true
hostname=$hostname
domainname=container.local
EOF
    
    # Create hostname file for the container
    echo "$hostname" > "$CONTAINERS_DIR/$container_name/rootfs/etc/hostname"
    
    log_success "UTS namespace configuration prepared with hostname: $hostname" \
                "Papan nama rumah '$hostname' siap dipasang"
    
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
    
    # Create container passwd and group files
    local container_rootfs="$CONTAINERS_DIR/$container_name/rootfs"
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
    ACTIVE_NAMESPACES["$container_name"]="pid,mount,uts,ipc,user"
    
    log_success "All namespaces configured for container: $container_name" \
                "Semua sistem rumah siap - penomoran keluarga, rak buku, nama rumah, papan tulis, dan keanggotaan"
    
    return 0
}

# =============================================================================
# NETWORK NAMESPACE AND CONTAINER COMMUNICATION
# =============================================================================

# Global network tracking for cleanup
declare -A ACTIVE_NETWORKS
declare -A CONTAINER_IPS
declare -g NEXT_IP_OCTET=2

# Get next available IP address in the container network
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

# Create veth pair for container-to-container communication
create_veth_pair() {
    local container_name=$1
    local peer_container=${2:-""}
    
    log_step 2 "Creating veth pair for container: $container_name" \
              "Seperti memasang kabel telepon khusus untuk komunikasi antar rumah"
    
    local veth_host="veth-${container_name}"
    local veth_container="veth-${container_name}-c"
    
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
    CONTAINER_IPS["$container_name"]="$container_ip"
    
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
    
    local container_ip="${CONTAINER_IPS[$container_name]}"
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
    
    local ip1="${CONTAINER_IPS[$container1]}"
    local ip2="${CONTAINER_IPS[$container2]}"
    
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
    local container_ip="${CONTAINER_IPS[$container_name]}"
    
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
    unset ACTIVE_NETWORKS["$container_name"]
    unset CONTAINER_IPS["$container_name"]
    
    # Remove network configuration files
    local ns_dir="$CONTAINERS_DIR/$container_name/namespaces"
    rm -f "$ns_dir/network.conf" 2>/dev/null
    
    log_success "Network cleanup completed for container: $container_name" \
                "Sistem telepon rumah berhasil dibersihkan"
    
    return 0
}

# Show network information for container
show_container_network_info() {
    local container_name=$1
    
    echo "=== Network Information for Container: $container_name ==="
    
    local ns_name="container-$container_name"
    local container_ip="${CONTAINER_IPS[$container_name]}"
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
        local ip="${CONTAINER_IPS[$container_name]}"
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
    local container_ip="${CONTAINER_IPS[$container_name]}"
    
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
                local other_ip="${CONTAINER_IPS[$other_container]}"
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
declare -A ACTIVE_CGROUPS

# Create cgroup directory structure for memory and CPU control
create_cgroup_structure() {
    local container_name=$1
    local memory_mb=$2
    local cpu_percent=$3
    
    log_step 1 "Creating cgroup structure for container: $container_name" \
              "Seperti RT yang menyiapkan sistem pembatasan listrik dan air untuk rumah baru"
    
    # Validate inputs
    validate_memory_limit "$memory_mb" || return 1
    validate_cpu_percentage "$cpu_percent" || return 1
    
    # Create cgroup directories
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    log_info "Creating memory cgroup: $memory_cgroup" \
             "Seperti menyiapkan meteran listrik khusus untuk rumah"
    
    if ! create_directory "$memory_cgroup" 755; then
        log_error "Failed to create memory cgroup directory" \
                  "Gagal menyiapkan meteran listrik rumah"
        return 1
    fi
    
    log_info "Creating CPU cgroup: $cpu_cgroup" \
             "Seperti menyiapkan pembagi waktu kerja untuk rumah"
    
    if ! create_directory "$cpu_cgroup" 755; then
        log_error "Failed to create CPU cgroup directory" \
                  "Gagal menyiapkan pembagi waktu kerja rumah"
        return 1
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
    ACTIVE_CGROUPS["$container_name"]="memory,cpu"
    
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
    
    # Validate memory limit
    validate_memory_limit "$memory_mb" || return 1
    
    local memory_cgroup="$CGROUP_ROOT/memory/container-$container_name"
    
    # Check if cgroup exists
    if [[ ! -d "$memory_cgroup" ]]; then
        log_error "Memory cgroup does not exist: $memory_cgroup" \
                  "Meteran listrik rumah belum dipasang"
        return 1
    fi
    
    # Convert MB to bytes
    local memory_bytes=$((memory_mb * 1024 * 1024))
    
    log_info "Setting memory limit to $memory_bytes bytes" \
             "Seperti mengatur batas listrik rumah: ${memory_mb}MB"
    
    # Set memory limit
    if ! echo "$memory_bytes" > "$memory_cgroup/memory.limit_in_bytes"; then
        log_error "Failed to set memory limit" \
                  "Gagal mengatur batas pemakaian listrik rumah"
        return 1
    fi
    
    # Set memory+swap limit (same as memory to prevent swap usage)
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
    
    # Verify the limit was set correctly
    local actual_limit
    if actual_limit=$(cat "$memory_cgroup/memory.limit_in_bytes" 2>/dev/null); then
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
    
    # Validate CPU percentage
    validate_cpu_percentage "$cpu_percent" || return 1
    
    local cpu_cgroup="$CGROUP_ROOT/cpu/container-$container_name"
    
    # Check if cgroup exists
    if [[ ! -d "$cpu_cgroup" ]]; then
        log_error "CPU cgroup does not exist: $cpu_cgroup" \
                  "Pembagi waktu kerja rumah belum dipasang"
        return 1
    fi
    
    # CPU cgroup uses CFS (Completely Fair Scheduler)
    # Period is typically 100000 microseconds (100ms)
    local cfs_period=100000
    local cfs_quota=$((cfs_period * cpu_percent / 100))
    
    log_info "Setting CPU quota to $cfs_quota/$cfs_period (${cpu_percent}%)" \
             "Seperti mengatur waktu kerja: ${cpu_percent}% dari total waktu"
    
    # Set CFS period
    if ! echo "$cfs_period" > "$cpu_cgroup/cpu.cfs_period_us"; then
        log_error "Failed to set CPU period" \
                  "Gagal mengatur periode waktu kerja"
        return 1
    fi
    
    # Set CFS quota
    if ! echo "$cfs_quota" > "$cpu_cgroup/cpu.cfs_quota_us"; then
        log_error "Failed to set CPU quota" \
                  "Gagal mengatur kuota waktu kerja"
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
    unset ACTIVE_CGROUPS["$container_name"]
    
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
    
    # Create basic device nodes
    if [[ ! -e "$container_rootfs/dev/null" ]]; then
        mknod "$container_rootfs/dev/null" c 1 3 2>/dev/null || true
    fi
    if [[ ! -e "$container_rootfs/dev/zero" ]]; then
        mknod "$container_rootfs/dev/zero" c 1 5 2>/dev/null || true
    fi
    if [[ ! -e "$container_rootfs/dev/random" ]]; then
        mknod "$container_rootfs/dev/random" c 1 8 2>/dev/null || true
    fi
    if [[ ! -e "$container_rootfs/dev/urandom" ]]; then
        mknod "$container_rootfs/dev/urandom" c 1 9 2>/dev/null || true
    fi
    
    # Create /dev/pts for pseudo terminals
    create_directory "$container_rootfs/dev/pts"
    if ! mount -t devpts devpts "$container_rootfs/dev/pts"; then
        log_warn "Failed to mount /dev/pts, terminal functionality may be limited" \
                 "Gagal memasang sistem terminal rumah"
    else
        log_debug "Mounted /dev/pts in container" "Sistem terminal rumah terpasang"
    fi
    
    # Mount tmpfs for /tmp
    if ! mount -t tmpfs tmpfs "$container_rootfs/tmp"; then
        log_warn "Failed to mount tmpfs on /tmp" \
                 "Gagal memasang ruang kerja sementara"
    else
        log_debug "Mounted tmpfs on /tmp" "Ruang kerja sementara terpasang"
    fi
    
    log_success "Mount namespace applied successfully" \
                "Semua rak buku dan perabotan rumah terpasang dengan baik"
    
    return 0
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
    
    # Source namespace configurations
    source "$ns_dir/pid.conf"
    source "$ns_dir/mount.conf"
    source "$ns_dir/uts.conf"
    source "$ns_dir/ipc.conf"
    source "$ns_dir/user.conf"
    
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
    unset ACTIVE_NAMESPACES["$container_name"]
    
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
    ACTIVE_NAMESPACES=()
    
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
# MAIN ENTRY POINT PLACEHOLDER
# =============================================================================

# Show usage information
show_usage() {
    cat << EOF
RT (Rukun Tetangga) Container Runtime v$SCRIPT_VERSION
Educational container runtime using Linux namespaces and cgroups

USAGE:
    $0 <command> [options]

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
    $0 test-network
    $0 create-test-network
    $0 show-network test-container-1
    $0 test-connectivity test-container-1 test-container-2
    $0 monitor-network test-container-1 30
    $0 debug-network test-container-1
    $0 cleanup-test-network

ANALOGY:
    RT Container Runtime seperti Rukun Tetangga (RT) yang mengatur kompleks perumahan.
    Setiap container adalah rumah dengan sistem telepon sendiri untuk komunikasi.

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
    
    # Setup signal handlers
    setup_signal_handlers
    
    # Check dependencies and privileges for network commands
    case "$command" in
        test-network|create-test-network|cleanup-test-network|show-network|test-connectivity|monitor-network|debug-network|list-networks)
            check_dependencies
            check_privileges
            ;;
    esac
    
    # Create base directories
    create_directory "$CONTAINERS_DIR"
    
    # Handle commands
    case "$command" in
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
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi