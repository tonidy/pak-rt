# Pak RT Container Runtime

Bash script container runtime yang mengimplementasikan container technology fundamentals menggunakan Linux namespaces dan cgroups.

## Overview

Pak RT (Rukun Tetangga) adalah educational container runtime yang dibuat untuk memahami bagaimana container bekerja di level sistem operasi. Script ini menggunakan analogi perumahan RT untuk menjelaskan konsep-konsep container technology.

## Features

- ✅ Linux Namespace Management (PID, Mount, UTS, IPC, User, Network)
- ✅ Cgroup Resource Management (Memory, CPU)
- ✅ Container-to-Container Networking
- ✅ Busybox Integration
- ✅ Educational Output dengan Analogi Perumahan
- ✅ Docker Compose Development Environment untuk macOS

## Quick Start

### Prerequisites

- macOS dengan Docker Desktop
- Docker Compose

### Development Setup

```bash
# Clone repository
git clone <repository-url>
cd pak-rt

# Setup development environment
make setup

# Start development container
make dev

# Run tests
make test
```

### Basic Usage

```bash
# Dalam development container
./rt.sh create-container rumah-a --ram=512 --cpu=50
./rt.sh list-containers
./rt.sh run-container rumah-a
./rt.sh delete-container rumah-a
```

## Development Commands

| Command | Description |
|---------|-------------|
| `make setup` | Setup development environment |
| `make dev` | Start interactive development container |
| `make test` | Run all tests |
| `make test-unit` | Run unit tests only |
| `make test-integration` | Run integration tests |
| `make clean` | Cleanup containers dan volumes |

## Project Structure

```
pak-rt/
├── rt.sh                    # Main RT script
├── Makefile                 # Development commands
├── docker-compose.yml       # Development environment
├── Dockerfile.dev          # Development container
├── tests/                  # Test scripts
│   ├── run-all-tests.sh
│   ├── unit-tests.sh
│   └── integration-tests.sh
└── docs/                   # Documentation
    ├── README.md
    ├── ANALOGY.md
    └── TROUBLESHOOTING.md
```

## Educational Analogy

Pak RT menggunakan analogi perumahan untuk menjelaskan container concepts:

- 🏘️ **Host System** = Kompleks Perumahan
- 🏠 **Container** = Rumah Individual
- 👨 **PID 1** = Ayah (kepala keluarga)
- 📞 **Network** = Telepon antar rumah
- 💡 **Resources** = Listrik dan air rumah

## Documentation

- [Analogy Guide](ANALOGY.md) - Detailed penjelasan analogi perumahan
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues dan solutions

## Contributing

1. Fork repository
2. Create feature branch
3. Make changes dalam development container
4. Run tests dengan `make test`
5. Submit pull request

## License

MIT License - see LICENSE file for details