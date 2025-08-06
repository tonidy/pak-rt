# RT Container Runtime

🏘️ **Educational container runtime implementation using Linux namespaces and cgroups**

RT (Rukun Tetangga) adalah bash script container runtime yang dibuat untuk memahami bagaimana container bekerja di level sistem operasi. Script ini menggunakan analogi RT di dalam perumahan untuk menjelaskan konsep-konsep container technology dengan cara yang mudah dipahami.

## 🌟 Features

- ✅ **Linux Namespace Management** - PID, Mount, UTS, IPC, User, Network isolation
- ✅ **Cgroup Resource Management** - Memory dan CPU limiting dengan monitoring
- ✅ **Container-to-Container Networking** - Direct communication tanpa host routing
- ✅ **Busybox Integration** - Lightweight container base dengan static binary
- ✅ **Educational Output** - Step-by-step explanations dengan analogi perumahan
- ✅ **Comprehensive Error Handling** - Recovery mechanisms dan troubleshooting
- ✅ **Security Features** - Input sanitization dan privilege management
- ✅ **Docker Compose Development** - Easy setup untuk macOS developers

## 🚀 Quick Start

### Prerequisites

- **macOS** dengan Docker Desktop installed
- **Docker Compose** (included dengan Docker Desktop)
- **Git** untuk cloning repository

### Development Setup

```bash
# Clone repository
git clone <repository-url>
cd pak-rt

# Setup development environment
make setup

# Start development container (Linux environment)
make dev

# Dalam development container, test basic functionality
./rt.sh create-container rumah-a --ram=512 --cpu=50
./rt.sh list-containers
./rt.sh run-container rumah-a
./rt.sh delete-container rumah-a
```

### Basic Usage Examples

```bash
# Create container dengan resource limits
./rt.sh create-container rumah-jakarta --ram=256 --cpu=25

# List semua containers dengan status
./rt.sh list-containers

# Run container dengan interactive shell
./rt.sh run-container rumah-jakarta

# Create multiple containers untuk networking test
./rt.sh create-container rumah-bandung --ram=512 --cpu=50
./rt.sh create-container rumah-surabaya --ram=256 --cpu=30

# Test container-to-container communication
./rt.sh run-container rumah-bandung
# Dalam container: ping 10.0.0.3 (IP rumah-surabaya)

# Cleanup containers
./rt.sh delete-container rumah-jakarta
./rt.sh cleanup-all  # Delete semua containers
```

## 🛠️ Development Commands

| Command | Description | Analogi RT |
|---------|-------------|------------|
| `make setup` | Setup development environment | Menyiapkan kantor RT |
| `make dev` | Start interactive development container | Masuk ke kantor RT |
| `make test` | Run all tests dalam Linux environment | Tes semua sistem kompleks |
| `make test-unit` | Run unit tests only | Tes komponen individual |
| `make test-integration` | Run integration tests | Tes integrasi antar sistem |
| `make test-network` | Run network connectivity tests | Tes sambungan telepon antar rumah |
| `make test-stress` | Run stress tests | Tes beban maksimal kompleks |
| `make clean` | Cleanup containers dan volumes | Bersih-bersih kantor RT |

### Demo Scenarios

| Command | Description | Analogi RT |
|---------|-------------|------------|
| `make demo` | Show available demo scenarios | Lihat demo yang tersedia |
| `make demo-basic` | Basic container lifecycle demo | Demo dasar kelola rumah |
| `make demo-namespace` | Namespace isolation demo | Demo isolasi antar rumah |
| `make demo-resources` | Resource management demo | Demo pembagian listrik |
| `make demo-network` | Container networking demo | Demo telepon antar rumah |
| `make demo-multi` | Multi-container application demo | Demo kompleks lengkap |
| `make demo-tour` | Complete educational tour | Tur lengkap kompleks |
| `make demo-all` | Run all demo scenarios | Jalankan semua demo |

### Advanced Testing Commands

```bash
# Test specific components
make test-busybox      # Test busybox management
make test-namespace    # Test namespace isolation
make test-cgroup       # Test resource limiting
make test-network      # Test container networking

# Performance and reliability tests
make test-stress       # Concurrent operations test
make test-resources    # Resource validation test
make test-cleanup      # Cleanup verification test
```

## 📁 Project Structure

```
pak-rt/
├── rt.sh                           # 🏠 Main RT script (Rukun Tetangga)
├── demo-scenarios.sh               # 🎬 Educational demo scenarios
├── Makefile                        # 🔧 Development commands untuk macOS
├── docker-compose.yml              # 🐳 Linux development environment
├── Dockerfile.dev                  # 📦 Development container setup
├── README.md                       # 📖 This documentation
├── docs/                          # 📚 Additional documentation
│   ├── README.md                  # Project overview
│   ├── ANALOGY.md                 # 🏘️ Detailed housing analogy
│   ├── TROUBLESHOOTING.md         # 🔍 Common issues dan solutions
│   ├── SECURITY.md                # 🔒 Security considerations
│   └── TESTING.md                 # 🧪 Testing methodology
└── tests/                         # 🧪 Comprehensive test suite
    ├── run-all-tests.sh           # Main test runner
    ├── unit-tests.sh              # Unit tests
    ├── integration-tests.sh       # Integration tests
    ├── busybox-tests.sh           # Busybox management tests
    ├── namespace-tests.sh         # Namespace isolation tests
    ├── cgroup-tests.sh            # Resource management tests
    ├── network-tests.sh           # Network connectivity tests
    ├── security-tests.sh          # Security feature tests
    ├── stress-tests.sh            # Performance stress tests
    ├── resource-validation-tests.sh # Resource limiting tests
    └── cleanup-verification-tests.sh # Cleanup verification tests
```

## 🏘️ Educational Analogy

RT menggunakan analogi perumahan untuk menjelaskan konsep container technology:

### Konsep Dasar
- 🏘️ **Host System** = Kompleks Perumahan yang dikelola RT
- 🏠 **Container** = Rumah Individual dengan penghuni
- 👨 **PID 1 (busybox)** = Ayah sebagai kepala keluarga (nomor 1 di rumah)
- 👩 **Shell Process** = Ibu yang mengelola aktivitas rumah
- 👦👧 **Child Processes** = Anak-anak dalam keluarga

### Namespace Isolation
- **PID Namespace**: Setiap rumah punya penomoran sendiri, Ayah selalu nomor 1
- **Network Namespace**: Setiap rumah punya telepon internal, bisa nelpon rumah lain
- **Mount Namespace**: Setiap rumah punya rak buku sendiri, tidak bisa lihat rak tetangga
- **UTS Namespace**: Setiap rumah punya nama sendiri (hostname)
- **IPC Namespace**: Setiap rumah punya papan tulis keluarga sendiri
- **User Namespace**: Ayah di rumah A berbeda dengan Ayah di rumah B

### Resource Management
- 💡 **Memory Limit** = Kuota listrik bulanan untuk setiap rumah
- ⚡ **CPU Limit** = Pembagian daya listrik yang adil
- 📊 **Resource Monitoring** = Tagihan listrik dan air real-time
- 🚨 **Resource Alerts** = Peringatan jika mendekati batas kuota

### Network Communication
- 📞 **Container-to-Container** = Telepon langsung antar rumah
- 🌐 **Host Network** = Telepon umum kompleks untuk internet
- 🔌 **veth pairs** = Kabel telepon yang menghubungkan rumah
- 📍 **IP Addresses** = Nomor telepon setiap rumah (10.0.0.x)

## 🎬 Demo Scenarios

RT Container Runtime menyediakan demo scenarios yang interaktif untuk pembelajaran:

### Quick Demo

```bash
# Start development environment
make dev

# Run basic demo
make demo-basic

# Run complete educational tour
make demo-tour

# Run all demos
make demo-all
```

### Available Demo Scenarios

1. **Basic Lifecycle** (`make demo-basic`)
   - Container creation, running, dan deletion
   - Seperti RT yang menunjukkan siklus hidup rumah

2. **Namespace Isolation** (`make demo-namespace`)
   - PID dan Mount namespace demonstration
   - Seperti RT yang menunjukkan isolasi antar rumah

3. **Resource Management** (`make demo-resources`)
   - Memory dan CPU limiting
   - Seperti RT yang menunjukkan pembagian listrik

4. **Container Networking** (`make demo-network`)
   - Container-to-container communication
   - Seperti RT yang menunjukkan sistem telepon

5. **Multi-Container** (`make demo-multi`)
   - Multiple containers working together
   - Seperti RT yang mengelola kompleks lengkap

6. **Educational Tour** (`make demo-tour`)
   - Complete guided tour of all features
   - Seperti RT yang memberikan tur lengkap kompleks

## 🎯 Use Cases

### 1. Learning Container Technology
```bash
# Understand namespace isolation
./rt.sh create-container belajar-namespace --ram=128 --cpu=25
./rt.sh run-container belajar-namespace
# Dalam container: ps aux  # Lihat PID isolation
# Dalam container: mount   # Lihat filesystem isolation
```

### 2. Network Learning
```bash
# Create multiple containers untuk network testing
./rt.sh create-container server --ram=256 --cpu=30
./rt.sh create-container client --ram=128 --cpu=20

# Test direct container communication
./rt.sh run-container server
# Dalam server: nc -l -p 8080  # Start simple server

# Dari container lain
./rt.sh run-container client
# Dalam client: nc 10.0.0.2 8080  # Connect ke server
```

### 3. Resource Management Learning
```bash
# Create container dengan memory limit
./rt.sh create-container memory-test --ram=64 --cpu=10

# Monitor resource usage
./rt.sh run-container memory-test
# Dalam container: stress --vm 1 --vm-bytes 100M  # Test memory limit
```

## 🔧 Advanced Configuration

### Environment Variables

```bash
# Enable verbose educational output
export VERBOSE_MODE=true
./rt.sh create-container verbose-demo --ram=256 --cpu=25

# Enable debug mode untuk detailed system information
export DEBUG_MODE=true
./rt.sh list-containers

# Enable resource monitoring
export MONITORING_ENABLED=true
./rt.sh run-container monitoring-demo
```

### Custom Resource Limits

```bash
# High-performance container
./rt.sh create-container high-perf --ram=1024 --cpu=80

# Minimal resource container
./rt.sh create-container minimal --ram=64 --cpu=5

# Balanced container
./rt.sh create-container balanced --ram=512 --cpu=50
```

## 🧪 Testing and Validation

### Running Tests

```bash
# Full test suite (requires Linux environment)
make test

# Quick validation
make test-unit

# Network functionality test
make test-network

# Performance validation
make test-stress
```

### Manual Testing Scenarios

```bash
# Scenario 1: Basic container lifecycle
./rt.sh create-container test1 --ram=256 --cpu=25
./rt.sh list-containers
./rt.sh run-container test1
./rt.sh delete-container test1

# Scenario 2: Multi-container networking
./rt.sh create-container web --ram=512 --cpu=50
./rt.sh create-container db --ram=256 --cpu=30
# Test ping between containers

# Scenario 3: Resource limiting
./rt.sh create-container limited --ram=128 --cpu=10
# Monitor resource usage dalam container
```

## 🔍 Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Ensure running dalam Docker container dengan privileged mode
   make dev
   ```

2. **Container Creation Fails**
   ```bash
   # Check system resources
   ./rt.sh debug system
   
   # Verify busybox availability
   ./rt.sh debug busybox
   ```

3. **Network Issues**
   ```bash
   # Check network configuration
   ./rt.sh debug network
   
   # Cleanup orphaned network interfaces
   ./rt.sh cleanup-all
   ```

### Debug Commands

```bash
# System information
./rt.sh debug system

# Container status
./rt.sh debug containers

# Network topology
./rt.sh debug network

# Resource usage
./rt.sh debug resources

# Recovery from corrupted state
./rt.sh recover-state
```

## 📚 Documentation

- **[ANALOGY.md](docs/ANALOGY.md)** - Detailed penjelasan analogi perumahan RT
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues dan solutions
- **[SECURITY.md](docs/SECURITY.md)** - Security considerations dan best practices
- **[TESTING.md](docs/TESTING.md)** - Testing methodology dan test scenarios

## 🤝 Contributing

1. Fork repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Make changes dalam development container: `make dev`
4. Run tests: `make test`
5. Commit changes: `git commit -m 'Add amazing feature'`
6. Push to branch: `git push origin feature/amazing-feature`
7. Submit pull request

### Development Guidelines

- Follow bash scripting best practices
- Add educational analogies untuk new features
- Include comprehensive error handling
- Write tests untuk new functionality
- Update documentation accordingly

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Linux kernel developers untuk namespace dan cgroup features
- Busybox project untuk lightweight container base
- Docker community untuk container technology inspiration
- Indonesian RT system untuk educational analogy inspiration

---

**🏠 Seperti RT yang melayani warga kompleks, script ini melayani developer yang ingin memahami container technology dengan cara yang mudah dan menyenangkan!**