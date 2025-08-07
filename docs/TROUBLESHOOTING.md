# 🔍 RT Container Runtime - Troubleshooting Guide

**Panduan mengatasi masalah umum dalam RT Container Runtime**

## 📋 Daftar Isi

- [🚨 Masalah Umum](#-masalah-umum)
- [🔧 Diagnostic Commands](#-diagnostic-commands)
- [🏠 Container Issues](#-container-issues)
- [📞 Network Problems](#-network-problems)
- [💡 Resource Issues](#-resource-issues)
- [🔒 Permission Problems](#-permission-problems)
- [🐳 Docker Environment Issues](#-docker-environment-issues)
- [🧪 Testing Problems](#-testing-problems)
- [🔄 Recovery Procedures](#-recovery-procedures)

## 🚨 Masalah Umum

### 1. Script Tidak Bisa Dijalankan

**Gejala:**
```bash
$ ./rt.sh create test
bash: ./rt.sh: Permission denied
```

**Penyebab:** File tidak executable

**Solusi:**
```bash
# Berikan permission execute
chmod +x rt.sh

# Atau jalankan dengan bash
bash rt.sh create test
```

**Analogi RT:** Seperti kunci kantor RT yang harus dibuka dulu sebelum bisa masuk

### 2. Command Not Found Errors

**Gejala:**
```bash
$ ./rt.sh create test
./rt.sh: line 45: unshare: command not found
```

**Penyebab:** Missing system dependencies

**Solusi:**
```bash
# Check dependencies
./rt.sh debug system

# Install missing tools (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install util-linux iproute2 coreutils

# Install missing tools (CentOS/RHEL)
sudo yum install util-linux iproute2 coreutils
```

**Analogi RT:** Seperti RT yang butuh peralatan lengkap untuk mengelola kompleks

### 3. Root Privileges Required

**Gejala:**
```bash
$ ./rt.sh create test
ERROR: Root privileges required for namespace operations
```

**Penyebab:** Container operations memerlukan root access

**Solusi:**
```bash
# Jalankan dengan sudo
sudo ./rt.sh create test

# Atau dalam development container
make dev  # Sudah privileged mode
```

**Analogi RT:** Seperti RT yang butuh wewenang khusus untuk mengatur kompleks

## 🔧 Diagnostic Commands

### System Information

```bash
# Check system capabilities
./rt.sh debug system

# Expected output:
🔍 RT melakukan inspeksi kompleks...
================================
🏘️ Kondisi Kompleks:
├── 💾 Disk Space: 15GB / 50GB available ✅
├── 🧠 Memory: 2GB / 8GB used ✅
├── ⚡ CPU Load: 1.5 / 4.0 cores ✅
└── 🌐 Network: eth0 up, docker0 up ✅
```

### Container Status

```bash
# Check all containers
./rt.sh debug containers

# Check specific container
./rt.sh debug container rumah-test
```

### Network Diagnostics

```bash
# Check network configuration
./rt.sh debug network

# Test network connectivity
./rt.sh test-network rumah-a rumah-b
```

### Resource Monitoring

```bash
# Check resource usage
./rt.sh debug resources

# Monitor specific container
./rt.sh monitor-resources rumah-test
```

## 🏠 Container Issues

### 1. Container Creation Fails

**Gejala:**
```bash
$ ./rt.sh create test --ram=512 --cpu=50
ERROR: Failed to create namespace: 1
```

**Kemungkinan Penyebab:**
- Insufficient privileges
- Missing kernel features
- Disk space full
- Invalid parameters

**Diagnostic Steps:**
```bash
# Check system requirements
./rt.sh debug system

# Check available space
df -h /tmp

# Check kernel features
ls /proc/sys/kernel/ns_last_pid  # PID namespace support
ls /sys/fs/cgroup/               # Cgroup support

# Check parameters
./rt.sh create test --ram=abc --cpu=50  # Invalid RAM
```

**Solusi:**
```bash
# Ensure running as root
sudo ./rt.sh create test --ram=512 --cpu=50

# Free up disk space
./rt.sh cleanup-all
rm -rf /tmp/containers/old-*

# Use valid parameters
./rt.sh create test --ram=256 --cpu=25
```

**Analogi RT:** Seperti RT yang tidak bisa bangun rumah karena lahan penuh atau izin tidak lengkap

### 2. Container Won't Start

**Gejala:**
```bash
$ ./rt.sh run test
ERROR: Container process failed to start
```

**Diagnostic Steps:**
```bash
# Check container status
./rt.sh list

# Check container files
ls -la /tmp/containers/test/

# Check busybox
./rt.sh debug busybox

# Check logs
cat /tmp/containers/test/logs/container.log
```

**Solusi:**
```bash
# Recreate container
./rt.sh delete test
./rt.sh create test --ram=256 --cpu=25

# Fix busybox if missing
./rt.sh setup-busybox

# Check and fix permissions
sudo chown -R root:root /tmp/containers/test/
sudo chmod -R 755 /tmp/containers/test/
```

**Analogi RT:** Seperti rumah yang tidak bisa dihuni karena listrik belum nyala atau kunci rusak

### 3. Container Becomes Unresponsive

**Gejala:**
- Container listed as RUNNING tapi tidak respond
- Process exists tapi tidak bisa diakses

**Diagnostic Steps:**
```bash
# Check process status
ps aux | grep container-test

# Check namespaces
lsns | grep container-test

# Check cgroups
cat /sys/fs/cgroup/memory/container-test/cgroup.procs
```

**Solusi:**
```bash
# Force cleanup
./rt.sh delete test --force

# Or manual cleanup
sudo kill -9 $(cat /tmp/containers/test/container.pid)
sudo rm -rf /tmp/containers/test/
```

**Analogi RT:** Seperti rumah yang ditinggal penghuni tapi listrik masih nyala

## 📞 Network Problems

### 1. Container Cannot Communicate

**Gejala:**
```bash
# Dalam container A
$ ping 10.0.0.3
ping: bad address '10.0.0.3'
```

**Diagnostic Steps:**
```bash
# Check network configuration
./rt.sh debug network

# Check IP addresses
./rt.sh run rumah-a
$ ip addr show

# Check routing
$ ip route show

# Check veth pairs
ip link show | grep veth
```

**Solusi:**
```bash
# Recreate network
./rt.sh delete rumah-a
./rt.sh delete rumah-b
./rt.sh cleanup-all
./rt.sh create rumah-a --ram=256 --cpu=25
./rt.sh create rumah-b --ram=256 --cpu=25

# Manual network fix
sudo ip link add veth-a type veth peer name veth-a-host
sudo ip link set veth-a netns container-rumah-a
sudo ip netns exec container-rumah-a ip addr add 10.0.0.2/24 dev veth-a
sudo ip netns exec container-rumah-a ip link set veth-a up
```

**Analogi RT:** Seperti telepon rumah yang tidak nyambung karena kabel putus

### 2. IP Address Conflicts

**Gejala:**
```bash
ERROR: IP address 10.0.0.2 already in use
```

**Diagnostic Steps:**
```bash
# Check existing IP assignments
./rt.sh debug network

# Check network namespaces
ip netns list

# Check for orphaned interfaces
ip link show | grep veth
```

**Solusi:**
```bash
# Cleanup orphaned network interfaces
./rt.sh cleanup-all

# Manual cleanup
sudo ip netns delete container-old-name
sudo ip link delete veth-orphan
```

**Analogi RT:** Seperti dua rumah yang dikasih nomor telepon sama

### 3. Network Namespace Issues

**Gejala:**
```bash
ERROR: Cannot create network namespace
```

**Diagnostic Steps:**
```bash
# Check namespace support
ls /proc/sys/user/max_net_namespaces

# Check current namespaces
ip netns list | wc -l

# Check permissions
ls -la /var/run/netns/
```

**Solusi:**
```bash
# Increase namespace limit
echo 1024 | sudo tee /proc/sys/user/max_net_namespaces

# Cleanup old namespaces
sudo ip netns delete old-namespace

# Fix permissions
sudo mkdir -p /var/run/netns
sudo chmod 755 /var/run/netns
```

**Analogi RT:** Seperti kompleks yang sudah penuh dan tidak bisa pasang telepon baru

## 💡 Resource Issues

### 1. Memory Limit Exceeded

**Gejala:**
```bash
# Dalam container
$ stress --vm 1 --vm-bytes 600M
Killed
```

**Diagnostic Steps:**
```bash
# Check memory usage
./rt.sh monitor-resources container-name

# Check cgroup limits
cat /sys/fs/cgroup/memory/container-name/memory.limit_in_bytes
cat /sys/fs/cgroup/memory/container-name/memory.usage_in_bytes
```

**Solusi:**
```bash
# Increase memory limit
./rt.sh delete test
./rt.sh create test --ram=1024 --cpu=50

# Or optimize application memory usage
# Reduce memory-intensive operations
```

**Analogi RT:** Seperti rumah yang kelebihan pemakaian listrik dan otomatis diputus

### 2. CPU Throttling

**Gejala:**
- Container terasa lambat
- CPU usage terbatas meski ada resource available

**Diagnostic Steps:**
```bash
# Check CPU limits
cat /sys/fs/cgroup/cpu/container-name/cpu.cfs_quota_us
cat /sys/fs/cgroup/cpu/container-name/cpu.cfs_period_us

# Monitor CPU usage
./rt.sh monitor-resources container-name
```

**Solusi:**
```bash
# Increase CPU limit
./rt.sh delete test
./rt.sh create test --ram=512 --cpu=75

# Check if throttling is necessary
# Maybe reduce CPU-intensive operations
```

**Analogi RT:** Seperti rumah yang dibatasi pemakaian daya listriknya

### 3. Disk Space Issues

**Gejala:**
```bash
ERROR: No space left on device
```

**Diagnostic Steps:**
```bash
# Check disk usage
df -h /tmp
du -sh /tmp/containers/*

# Check for large files
find /tmp/containers -type f -size +100M
```

**Solusi:**
```bash
# Cleanup old containers
./rt.sh cleanup-all

# Remove large files
sudo rm -rf /tmp/containers/old-container/
sudo rm -f /tmp/containers/*/logs/*.log

# Move to different location with more space
export CONTAINERS_DIR="/var/lib/rt"
mkdir -p "$CONTAINERS_DIR"
```

**Analogi RT:** Seperti kompleks yang kehabisan lahan untuk bangun rumah baru

## 🔒 Permission Problems

### 1. Cgroup Permission Denied

**Gejala:**
```bash
ERROR: Permission denied writing to cgroup
```

**Diagnostic Steps:**
```bash
# Check cgroup permissions
ls -la /sys/fs/cgroup/memory/
ls -la /sys/fs/cgroup/cpu/

# Check if cgroup v2 is used
mount | grep cgroup
```

**Solusi:**
```bash
# Ensure running as root
sudo ./rt.sh create test

# Fix cgroup permissions (if needed)
sudo chown -R root:root /sys/fs/cgroup/
sudo chmod -R 755 /sys/fs/cgroup/

# For cgroup v2 systems
sudo mkdir -p /sys/fs/cgroup/rt
echo "+memory +cpu" | sudo tee /sys/fs/cgroup/rt/cgroup.subtree_control
```

**Analogi RT:** Seperti RT yang tidak punya izin untuk mengatur meteran listrik

### 2. Namespace Creation Permission Denied

**Gejala:**
```bash
ERROR: unshare: Operation not permitted
```

**Diagnostic Steps:**
```bash
# Check user capabilities
id
capsh --print

# Check kernel support
ls /proc/sys/kernel/unprivileged_userns_clone
```

**Solusi:**
```bash
# Run as root
sudo ./rt.sh create test

# Enable unprivileged namespaces (if supported)
echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone

# Use development container (already privileged)
make dev
```

**Analogi RT:** Seperti RT yang tidak punya wewenang untuk membuat rumah baru

## 🐳 Docker Environment Issues

### 1. Docker Not Running

**Gejala:**
```bash
$ make dev
ERROR: Docker daemon tidak running
```

**Solusi:**
```bash
# Start Docker Desktop (macOS)
open -a Docker

# Wait for Docker to start
docker info

# Then try again
make dev
```

**Analogi RT:** Seperti kantor RT yang belum buka

### 2. Docker Compose Issues

**Gejala:**
```bash
$ make dev
ERROR: Docker Compose tidak ditemukan
```

**Solusi:**
```bash
# Install Docker Compose
brew install docker-compose

# Or use Docker Desktop (includes Compose)
# Download from https://docker.com/products/docker-desktop
```

### 3. Privileged Mode Issues

**Gejala:**
```bash
# Dalam container
$ ./rt.sh create test
ERROR: Operation not permitted
```

**Diagnostic Steps:**
```bash
# Check if running in privileged container
cat /proc/1/status | grep CapEff

# Check Docker Compose configuration
cat docker-compose.yml | grep privileged
```

**Solusi:**
```bash
# Ensure docker-compose.yml has privileged: true
services:
  rt-dev:
    privileged: true  # This is required!

# Rebuild container
make clean
make setup
make dev
```

**Analogi RT:** Seperti RT yang tidak punya wewenang penuh untuk mengelola kompleks

## 🧪 Testing Problems

### 1. Tests Fail Due to Permissions

**Gejala:**
```bash
$ make test
❌ Namespace Management Tests FAILED
```

**Solusi:**
```bash
# Ensure running in privileged Docker container
make dev

# Then run tests inside container
./tests/run-all-tests.sh

# Or run specific test
sudo ./tests/namespace-tests.sh
```

### 2. Tests Timeout

**Gejala:**
```bash
❌ Integration Tests FAILED (timeout)
```

**Solusi:**
```bash
# Increase timeout in test scripts
# Edit tests/run-all-tests.sh
timeout 600 bash "$test_script"  # Increase from 300 to 600

# Or run tests individually
./tests/unit-tests.sh
./tests/integration-tests.sh
```

### 3. Resource Tests Fail

**Gejala:**
```bash
❌ Resource Validation Tests FAILED
```

**Diagnostic Steps:**
```bash
# Check available resources
free -h
df -h

# Check cgroup support
ls /sys/fs/cgroup/memory/
ls /sys/fs/cgroup/cpu/
```

**Solusi:**
```bash
# Ensure sufficient resources
# At least 2GB RAM, 10GB disk space

# Run in clean environment
make clean
make setup
make dev
```

## 🔄 Recovery Procedures

### 1. Complete System Recovery

**Ketika semua rusak dan tidak tahu harus mulai dari mana:**

```bash
# Step 1: Stop semua yang berjalan
sudo pkill -f "rt.sh"
sudo pkill -f "busybox"

# Step 2: Cleanup semua container
./rt.sh cleanup-all

# Step 3: Manual cleanup jika perlu
sudo rm -rf /tmp/containers/*
sudo ip netns list | xargs -I {} sudo ip netns delete {}
sudo ip link show | grep veth | cut -d: -f2 | xargs -I {} sudo ip link delete {}

# Step 4: Cleanup cgroups
find /sys/fs/cgroup -name "container-*" -type d | xargs sudo rmdir 2>/dev/null || true

# Step 5: Restart dari awal
./rt.sh create test --ram=256 --cpu=25
```

**Analogi RT:** Seperti RT yang melakukan renovasi total kompleks

### 2. Recover Corrupted Container

```bash
# Check for corruption
./rt.sh recover-state

# Manual recovery for specific container
./rt.sh recover container-name

# If recovery fails, recreate
./rt.sh delete container-name --force
./rt.sh create container-name --ram=512 --cpu=50
```

### 3. Network Recovery

```bash
# Cleanup all network interfaces
sudo ip link show | grep veth | cut -d: -f2 | xargs -I {} sudo ip link delete {} 2>/dev/null || true

# Cleanup network namespaces
sudo ip netns list | xargs -I {} sudo ip netns delete {} 2>/dev/null || true

# Recreate containers with networking
./rt.sh create rumah-a --ram=256 --cpu=25
./rt.sh create rumah-b --ram=256 --cpu=25
```

## 📞 Getting Help

### Debug Information to Collect

Ketika meminta bantuan, sertakan informasi berikut:

```bash
# System information
uname -a
cat /etc/os-release

# RT debug information
./rt.sh debug system
./rt.sh debug containers
./rt.sh debug network

# Error logs
cat /tmp/containers/*/logs/*.log

# Docker environment (jika menggunakan)
docker version
docker-compose version
```

### Common Error Patterns

| Error Message | Likely Cause | Quick Fix |
|---------------|--------------|-----------|
| `Permission denied` | Not running as root | `sudo ./rt.sh ...` |
| `Command not found` | Missing dependencies | Install util-linux, iproute2 |
| `No space left` | Disk full | `./rt.sh cleanup-all` |
| `Operation not permitted` | Missing capabilities | Run in privileged container |
| `Address already in use` | IP conflict | `./rt.sh cleanup-all` |
| `Cannot create namespace` | Kernel limitation | Check namespace limits |

### Emergency Commands

```bash
# Nuclear option - cleanup everything
sudo ./rt.sh cleanup-all --force

# Kill all RT processes
sudo pkill -f rt.sh

# Remove all containers
sudo rm -rf /tmp/containers/*

# Reset network
sudo ip netns list | xargs -I {} sudo ip netns delete {}
```

**🏠 Seperti RT yang punya prosedur darurat untuk mengatasi berbagai masalah kompleks, panduan ini membantu menyelesaikan masalah RT Container Runtime dengan sistematis!**