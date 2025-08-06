# RT Container Runtime - Docker Integration

## Overview

RT Container Runtime sekarang dapat dijalankan di dalam Docker container, memungkinkan Anda untuk menggunakan RT di macOS, Windows, atau sistem lain yang tidak mendukung Linux namespaces secara native.

## Quick Start

### 1. Menggunakan Helper Script (Recommended)

```bash
# Start development environment (privileged mode)
./run-rt-docker.sh dev

# Start rootless mode demonstration
./run-rt-docker.sh rootless

# Build Docker images
./run-rt-docker.sh build

# Clean up everything
./run-rt-docker.sh clean
```

### 2. Menggunakan Docker Compose Langsung

```bash
# Start development environment
docker-compose up -d rt-dev
docker-compose exec rt-dev /bin/bash

# Start rootless mode
docker-compose up -d rt-rootless
docker-compose exec rt-rootless /bin/bash

# Stop services
docker-compose down
```

## Available Services

### 🔧 rt-dev (Development Environment)
- **Mode**: Privileged (full capabilities)
- **User**: root
- **Features**: 
  - Full RT Container Runtime capabilities
  - Access to cgroups for resource management
  - Network namespace operations
  - All debugging tools available

```bash
# Inside rt-dev container
./rt.sh create-container webapp --ram=512 --cpu=50
./rt.sh run-container webapp
./rt.sh list-containers
./rt.sh monitor webapp 30
```

### 🆓 rt-rootless (Rootless Mode)
- **Mode**: Non-privileged
- **User**: developer
- **Features**:
  - Rootless container demonstration
  - User namespace isolation
  - Limited resource management
  - Educational purposes

```bash
# Inside rt-rootless container
./rt.sh --rootless create-container webapp
./rt.sh --rootless run-container webapp
./rt.sh --rootless list-containers
./demo-rootless.sh
```

## File Structure

```
pak-rt/
├── Dockerfile.dev              # Main development Dockerfile
├── Dockerfile.rt               # Standalone RT runtime Dockerfile
├── docker-compose.yml          # Main compose file
├── docker-compose.rt.yml       # Alternative compose file
├── run-rt-docker.sh           # Helper script
├── rt.sh                      # RT Container Runtime script
├── demo-rootless.sh           # Rootless demo script
└── README-DOCKER.md           # This file
```

## Environment Variables

### Development Environment
```bash
CONTAINER_RUNTIME_ENV=development
TERM=xterm-256color
VERBOSE_MODE=false
DEBUG_MODE=false
```

### Rootless Environment
```bash
CONTAINER_RUNTIME_ENV=rootless
TERM=xterm-256color
VERBOSE_MODE=true
ROOTLESS_MODE=true
```

## Volume Mounts

### rt-dev Service
- `.:/workspace` - Source code (read/write)
- `/sys/fs/cgroup:/sys/fs/cgroup:rw` - Cgroups access
- `rt-tmp:/tmp/containers` - Container storage

### rt-rootless Service
- `.:/workspace` - Source code (read/write)
- `rt-rootless-data:/home/developer/.local/share/rt-containers` - Rootless container storage

## Network Configuration

- **Network**: `rt-development-network` (bridge)
- **rt-dev**: Uses host network for full capabilities
- **rt-rootless**: Uses bridge network for isolation

## Usage Examples

### Example 1: Basic Container Operations

```bash
# Start development environment
./run-rt-docker.sh dev

# Inside container:
./rt.sh validate-system
./rt.sh create-container myapp --ram=256 --cpu=30
./rt.sh list-containers
./rt.sh run-container myapp
./rt.sh delete-container myapp
```

### Example 2: Rootless Mode Testing

```bash
# Start rootless environment
./run-rt-docker.sh rootless

# Inside container:
./demo-rootless.sh
./rt.sh --rootless create-container test
./rt.sh --rootless list-containers
./rt.sh --rootless delete-container test
```

### Example 3: Development Workflow

```bash
# Build fresh images
./run-rt-docker.sh build

# Start development
./run-rt-docker.sh dev

# Edit rt.sh on host, changes are reflected in container
# Test changes inside container
./rt.sh help
./rt.sh create-container test-changes

# Clean up when done
./run-rt-docker.sh clean
```

## Troubleshooting

### Docker Not Running
```bash
# Error: Cannot connect to Docker daemon
# Solution: Start Docker Desktop or Docker daemon
```

### Permission Issues
```bash
# Error: Permission denied
# Solution: Make sure Docker has proper permissions
sudo usermod -aG docker $USER
# Then logout and login again
```

### Container Build Fails
```bash
# Clean build
./run-rt-docker.sh clean
./run-rt-docker.sh build
```

### Rootless Mode Not Working
```bash
# Check inside rt-rootless container
./demo-rootless.sh
# This will show what's missing for rootless support
```

## Advanced Usage

### Custom Docker Compose

You can create your own docker-compose override:

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  rt-dev:
    environment:
      - DEBUG_MODE=true
      - VERBOSE_MODE=true
    volumes:
      - ./custom-configs:/etc/rt-configs
```

### Building Custom Images

```bash
# Build with custom tag
docker build -f Dockerfile.dev -t my-rt-runtime .

# Run custom image
docker run --privileged -it -v $(pwd):/workspace my-rt-runtime
```

## Comparison: Native vs Docker

| Feature | Native Linux | Docker on macOS/Windows |
|---------|-------------|-------------------------|
| Performance | Native | Slight overhead |
| Setup | Manual dependencies | Automated via Docker |
| Isolation | Host namespaces | Container + VM |
| Portability | Linux only | Cross-platform |
| Development | Direct editing | Volume mounts |

## Best Practices

1. **Use helper script** for common operations
2. **Mount source code** for live development
3. **Use rt-dev** for full feature testing
4. **Use rt-rootless** for security testing
5. **Clean up regularly** to save disk space

## Integration with IDEs

### VS Code
```bash
# Install Remote-Containers extension
# Open folder in container
code --folder-uri vscode-remote://attached-container+<container-id>/workspace
```

### IntelliJ/PyCharm
- Configure Docker as remote interpreter
- Set working directory to `/workspace`
- Map local files to container paths

## Analogi RT

Seperti **RT yang punya kantor sementara**:
- RT asli = Menjalankan langsung di kompleks (native Linux)
- RT di kantor sementara = Menjalankan di dalam container (Docker)
- Tetap bisa mengatur rumah warga, tapi melalui "kantor" yang terisolasi
- Semua fasilitas tersedia, dengan sedikit overhead administrasi
