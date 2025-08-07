# Design Document

## Overview

Bash script container runtime ini akan mengimplementasikan container technology fundamentals menggunakan Linux namespaces dan cgroups. Script akan terdiri dari beberapa modul yang menangani namespace management, network setup, resource limiting, dan container lifecycle. Desain ini fokus pada educational value sambil tetap functional.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Container Runtime Script                  │
├─────────────────────────────────────────────────────────────┤
│  CLI Interface (create, list, run, delete commands)         │
├─────────────────────────────────────────────────────────────┤
│  Container Manager                                          │
│  ├── Namespace Manager (PID, Mount, UTS, IPC, User)        │
│  ├── Network Manager (netns, veth pairs)                   │
│  ├── Cgroup Manager (memory, CPU limits)                   │
│  └── Process Manager (busybox integration)                 │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer                                              │
│  ├── Container Metadata (/tmp/containers/)                 │
│  ├── Busybox Binary Management                             │
│  └── Filesystem Isolation (bind mounts)                    │
├─────────────────────────────────────────────────────────────┤
│  Linux Kernel APIs                                         │
│  ├── Namespaces (unshare, nsenter)                        │
│  ├── Cgroups v2 (/sys/fs/cgroup/)                         │
│  └── Network (ip netns, veth)                             │
└─────────────────────────────────────────────────────────────┘
```

### Project Structure

```
pak-rt/
├── rt.sh                           # Main RT script (Rukun Tetangga)
├── Makefile                        # Development commands untuk macOS
├── docker-compose.yml              # Linux development environment
├── Dockerfile.dev                  # Development container
├── tests/                          # Test scripts
│   ├── unit-tests.sh
│   ├── integration-tests.sh
│   └── network-tests.sh
└── docs/                          # Documentation
    ├── README.md
    ├── ANALOGY.md                 # Penjelasan analogi perumahan
    └── TROUBLESHOOTING.md
```

### RT Script Structure

```
rt.sh
├── Global Variables & Configuration
├── Utility Functions (dengan analogi RT)
├── Namespace Management Functions
├── Network Management Functions  
├── Cgroup Management Functions
├── Container Lifecycle Functions
├── CLI Command Handlers
└── Main Entry Point
```

## Components and Interfaces

### 1. CLI Interface Module

**Purpose**: Menyediakan command-line interface yang user-friendly

**Functions**:
- `show_usage()`: Display help dan usage examples
- `parse_arguments()`: Parse command line arguments
- `validate_parameters()`: Validate input parameters

**Interface**:
```bash
# Command format (RT = Rukun Tetangga)
./rt.sh create <name> --ram=<MB> --cpu=<percentage>
./rt.sh list
./rt.sh run <name> [command]
./rt.sh delete <name>
./rt.sh cleanup-all
```

### 2. Namespace Manager

**Purpose**: Mengelola Linux namespaces untuk isolasi container

**Functions**:
- `create_namespaces()`: Create PID, mount, UTS, IPC, user namespaces
- `setup_mount_namespace()`: Setup isolated filesystem
- `setup_pid_namespace()`: Setup isolated process tree
- `cleanup_namespaces()`: Cleanup namespace resources

**Key Implementation Details**:
- Menggunakan `unshare` untuk membuat namespaces
- Mount `/proc` dan `/sys` di dalam namespace
- Setup user mapping untuk unprivileged containers
- Bind mount busybox dan essential directories

### 3. Network Manager

**Purpose**: Mengelola network isolation dan container-to communication

**Functions**:
- `create_network_namespace()`: Create isolated network stack
- `setup_veth_pair()`: Create virtual ethernet pair
- `configure_container_network()`: Assign IP dan setup routing
- `cleanup_network()`: Remove network interfaces dan namespaces

**Network Design**:
```
Container A (10.0.0.2/24) ←→ veth-a ←→ veth-b ←→ Container B (10.0.0.3/24)
```

**Implementation Details**:
- Menggunakan `ip netns` untuk network namespaces
- Create veth pair dengan `ip link add`
- Assign IP addresses dengan `ip addr add`
- Setup routing untuk direct communication

### 4. Cgroup Manager

**Purpose**: Mengelola resource limiting (RAM dan CPU)

**Functions**:
- `create_cgroup()`: Create cgroup untuk container
- `set_memory_limit()`: Set memory limit dalam bytes
- `set_cpu_limit()`: Set CPU percentage limit
- `add_process_to_cgroup()`: Add process ke cgroup
- `cleanup_cgroup()`: Remove cgroup

**Cgroup Hierarchy**:
```
/sys/fs/cgroup/
├── memory/container-<name>/
│   ├── memory.limit_in_bytes
│   └── cgroup.procs
└── cpu/container-<name>/
    ├── cpu.cfs_quota_us
    ├── cpu.cfs_period_us
    └── cgroup.procs
```

### 5. Container Process Manager

**Purpose**: Mengelola container processes menggunakan busybox

**Functions**:
- `download_busybox()`: Download busybox static binary jika belum ada
- `verify_busybox()`: Verify busybox binary integrity
- `start_container_process()`: Start busybox dalam namespace
- `exec_in_container()`: Execute command dalam running container

**Busybox Integration**:
- Download dari official busybox releases
- Verify dengan checksum
- Setup sebagai PID 1 dalam container
- Provide shell access untuk debugging

### 6. Storage and Metadata Manager

**Purpose**: Mengelola container metadata dan filesystem

**Functions**:
- `save_container_metadata()`: Save container configuration
- `load_container_metadata()`: Load container information
- `setup_container_rootfs()`: Setup minimal root filesystem
- `cleanup_container_data()`: Remove container data

**Storage Structure**:
```
/tmp/containers/
├── <container-name>/
│   ├── config.json          # Container configuration
│   ├── rootfs/              # Container root filesystem
│   │   ├── bin/             # Busybox symlinks
│   │   ├── proc/            # Mounted /proc
│   │   ├── sys/             # Mounted /sys
│   │   └── tmp/             # Temporary files
│   └── logs/                # Container logs
└── busybox                  # Shared busybox binary
```

## Data Models

### Container Configuration
```json
{
  "name": "container-name",
  "created": "2025-01-08T10:30:00Z",
  "status": "running|stopped|created",
  "resources": {
    "memory_mb": 512,
    "cpu_percentage": 50
  },
  "network": {
    "ip_address": "10.0.0.2",
    "veth_host": "veth-host-name",
    "veth_container": "veth-container-name"
  },
  "namespaces": {
    "pid": "/proc/12345/ns/pid",
    "net": "/proc/12345/ns/net",
    "mnt": "/proc/12345/ns/mnt"
  },
  "cgroups": {
    "memory": "/sys/fs/cgroup/memory/container-name",
    "cpu": "/sys/fs/cgroup/cpu/container-name"
  },
  "pid": 12345
}
```

## Error Handling

### Error Categories
1. **Permission Errors**: Insufficient privileges untuk namespace/cgroup operations
2. **Resource Errors**: Insufficient system resources
3. **Network Errors**: Network setup failures
4. **Filesystem Errors**: Mount atau filesystem operation failures
5. **Process Errors**: Container process startup failures

### Error Handling Strategy
- Comprehensive error checking setelah setiap system call
- Graceful cleanup pada error conditions
- Detailed error messages dengan troubleshooting hints
- Rollback mechanism untuk partial failures

### Example Error Handling
```bash
create_namespace() {
    if ! unshare --pid --mount --uts --ipc --user --map-root-user bash -c "$1"; then
        log_error "Failed to create namespace: $?"
        cleanup_partial_container "$container_name"
        exit 1
    fi
}
```

## Testing Strategy

### Unit Testing Approach
- Test setiap function secara individual
- Mock system calls untuk testing
- Validate error conditions
- Test resource cleanup

### Integration Testing
- Test complete container lifecycle
- Test network connectivity between containers
- Test resource limiting effectiveness
- Test concurrent container operations

### Test Scenarios
1. **Basic Container Operations**:
   - Create, start, stop, delete container
   - Verify namespace isolation
   - Verify resource limits

2. **Network Testing**:
   - Container-to communication
   - Network isolation dari host
   - Network cleanup

3. **Resource Testing**:
   - Memory limit enforcement
   - CPU limit enforcement
   - Resource monitoring

4. **Error Scenarios**:
   - Insufficient permissions
   - Resource exhaustion
   - Network conflicts
   - Partial cleanup scenarios

### Performance Considerations
- Minimize system calls dalam hot paths
- Efficient cleanup procedures
- Resource monitoring overhead
- Concurrent container handling

## Development Environment Design

### Docker Compose Setup untuk macOS

**Purpose**: Menyediakan Linux environment untuk development dan testing di macOS

**Components**:
- **Development Container**: Ubuntu/Alpine dengan Linux kernel features
- **Volume Mounting**: Code directory mounted untuk live development
- **Privileged Mode**: Required untuk namespace dan cgroup operations
- **Network Access**: Host network untuk testing

**Docker Compose Configuration**:
```yaml
version: '3.8'
services:
  rt-dev:
    build:
      context: .
      dockerfile: Dockerfile.dev
    privileged: true
    volumes:
      - .:/workspace
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    working_dir: /workspace
    command: /bin/bash
    stdin_open: true
    tty: true
```

### Makefile Commands

**Development Commands**:
- `make setup`: Initialize development environment
- `make dev`: Start interactive development container
- `make test`: Run all tests dalam Linux container
- `make test-unit`: Run unit tests only
- `make test-integration`: Run integration tests
- `make clean`: Cleanup containers dan volumes
- `make help`: Show available commands

**Implementation Strategy**:
- Makefile akan handle Docker Compose operations
- Automatic dependency checking (Docker, Docker Compose)
- Cross-platform compatibility (macOS focus)
- Easy onboarding untuk new developers

## Security Considerations

### Privilege Management
- Run dengan minimal required privileges
- Use user namespaces untuk unprivileged containers
- Validate all user inputs
- Secure temporary file handling

### Resource Isolation
- Strict cgroup limits enforcement
- Network isolation verification
- Filesystem access restrictions
- Process isolation validation

### Attack Surface Minimization
- Minimal busybox installation
- No unnecessary network services
- Secure default configurations
- Input sanitization

## Educational Features

### Namespace Analogy System
Script akan menggunakan analogi perumahan untuk menjelaskan namespace concepts:

**Analogi Perumahan untuk Linux Namespaces**:
```
🏘️ Kompleks Perumahan (Host System)
├── 🏠 Rumah A (Container A)
│   ├── 👨 Ayah (PID 1 - busybox)
│   ├── 👩 Ibu (PID 2 - shell)  
│   ├── 👦 Kakak (PID 3 - process)
│   └── 👧 Adik (PID 4 - process)
├── 🏠 Rumah B (Container B)  
│   ├── 👨 Ayah (PID 1 - busybox)
│   └── 👩 Ibu (PID 2 - shell)
├── 🏢 Kantor RT (Network Namespace)
│   └── 📞 Telepon Rumah (veth pairs)
└── 🏛️ Kantor RW (Host Network)
    └── 🌐 Internet Gateway
```

**Educational Explanations**:
- **PID Namespace**: "Setiap rumah punya penomoran sendiri, Ayah selalu nomor 1 di rumahnya"
- **Network Namespace**: "Setiap rumah punya telepon internal, bisa nelpon rumah lain tanpa lewat RT"
- **Mount Namespace**: "Setiap rumah punya rak buku sendiri, tidak bisa lihat rak tetangga"
- **UTS Namespace**: "Setiap rumah punya nama sendiri (hostname)"
- **IPC Namespace**: "Setiap rumah punya papan tulis keluarga sendiri"
- **User Namespace**: "Ayah di rumah A beda dengan Ayah di rumah B"

### Verbose Logging
- Step-by-step operation explanation dengan analogi
- Real-time resource monitoring ("Listrik dan air rumah")
- Network configuration display ("Sambungan telepon antar rumah")
- Namespace information ("Status penghuni rumah")

### Debug Mode
- Detailed system call tracing
- Resource usage statistics ("Tagihan listrik dan air")
- Network topology visualization ("Peta kompleks perumahan")
- Container internals inspection ("Inspeksi dalam rumah")

### Learning Resources
- Built-in help dengan examples dan analogi
- Common troubleshooting guide ("Panduan RT")
- Links ke relevant documentation
- Interactive exploration commands ("Jalan-jalan keliling kompleks")