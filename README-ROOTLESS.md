# RT Container Runtime - Mode Rootless

## Penjelasan Mode Rootless

**Mode Rootless** memungkinkan Anda menjalankan RT Container Runtime tanpa menggunakan `sudo` atau privilege root. Mode ini menggunakan **User Namespaces** Linux untuk memberikan isolasi container yang aman tanpa memerlukan akses administrator.

## Perbedaan dengan Mode Normal

### Mode Normal (Perlu Sudo)
```bash
# Perlu sudo untuk semua operasi
sudo ./rt.sh create-container rumah-a
sudo ./rt.sh run-container rumah-a
sudo ./rt.sh list-containers
```

**Mengapa perlu sudo?**
- Akses langsung ke cgroups (`/sys/fs/cgroup`)
- Membuat network namespaces
- Mount filesystem
- Mengatur resource limits

### Mode Rootless (Tanpa Sudo)
```bash
# Tidak perlu sudo
./rt.sh --rootless create-container rumah-a
./rt.sh --rootless run-container rumah-a
./rt.sh --rootless list-containers
```

**Bagaimana bisa tanpa sudo?**
- Menggunakan User Namespaces
- Container disimpan di `~/.local/share/rt-containers`
- Resource limits mungkin terbatas
- Isolasi tetap aman melalui namespaces

## Persyaratan Sistem

### 1. User Namespaces Harus Diaktifkan
```bash
# Cek apakah user namespaces aktif
cat /proc/sys/kernel/unprivileged_userns_clone

# Jika output "1" = aktif
# Jika output "0" = tidak aktif, perlu diaktifkan:
echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone
```

### 2. Tools yang Diperlukan
```bash
# Ubuntu/Debian
sudo apt install uidmap

# CentOS/RHEL
sudo yum install shadow-utils

# Arch Linux
sudo pacman -S shadow
```

### 3. Konfigurasi subuid/subgid (Opsional)
Beberapa distro memerlukan konfigurasi manual:

```bash
# Tambahkan ke /etc/subuid
echo "$(whoami):100000:65536" | sudo tee -a /etc/subuid

# Tambahkan ke /etc/subgid  
echo "$(whoami):100000:65536" | sudo tee -a /etc/subgid
```

## Cara Penggunaan

### 1. Cek Dukungan Sistem
```bash
# Jalankan demo untuk cek kompatibilitas
./demo-rootless.sh

# Atau cek manual dengan validate-system
./rt.sh --rootless validate-system
```

### 2. Operasi Container Dasar
```bash
# Buat container
./rt.sh --rootless create-container webapp

# Jalankan container
./rt.sh --rootless run-container webapp

# List semua container
./rt.sh --rootless list-containers

# Hapus container
./rt.sh --rootless delete-container webapp
```

### 3. Dengan Opsi Tambahan
```bash
# Mode verbose
./rt.sh --rootless --verbose create-container webapp

# Mode debug
./rt.sh --rootless --debug create-container webapp

# Kombinasi opsi
./rt.sh --rootless --verbose --debug create-container webapp
```

## Keterbatasan Mode Rootless

### ❌ Fitur yang Tidak Tersedia
1. **Resource Limits (cgroups)**
   - Memory limits mungkin tidak berfungsi
   - CPU limits mungkin tidak berfungsi
   - Tergantung dukungan cgroups v2

2. **Network Features**
   - Beberapa fitur network mungkin terbatas
   - Tidak bisa bind ke port < 1024

3. **Filesystem**
   - Tidak bisa mount filesystem tertentu
   - Beberapa operasi mount mungkin gagal

### ✅ Fitur yang Tetap Tersedia
1. **Isolasi Proses** - PID namespaces tetap berfungsi
2. **Isolasi Filesystem** - Mount namespaces tetap berfungsi  
3. **Isolasi Network** - Network namespaces tetap berfungsi
4. **Isolasi Hostname** - UTS namespaces tetap berfungsi

## Troubleshooting

### Error: "user_namespaces_not_available"
```bash
# Solusi: Aktifkan user namespaces
echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone

# Atau tambahkan ke /etc/sysctl.conf untuk permanen
echo "kernel.unprivileged_userns_clone=1" | sudo tee -a /etc/sysctl.conf
```

### Error: "newuidmap_missing" atau "newgidmap_missing"
```bash
# Ubuntu/Debian
sudo apt install uidmap

# CentOS/RHEL  
sudo yum install shadow-utils
```

### Error: "subuid_mapping_missing"
```bash
# Tambahkan mapping untuk user Anda
echo "$(whoami):100000:65536" | sudo tee -a /etc/subuid
echo "$(whoami):100000:65536" | sudo tee -a /etc/subgid
```

### Container Tidak Bisa Akses Network
```bash
# Cek apakah network namespace dibuat
./rt.sh --rootless debug network

# Restart container jika perlu
./rt.sh --rootless delete-container nama-container
./rt.sh --rootless create-container nama-container
```

## Perbandingan dengan Docker Rootless

| Fitur | RT Rootless | Docker Rootless |
|-------|-------------|-----------------|
| Setup | Manual flag `--rootless` | Perlu instalasi khusus |
| Storage | `~/.local/share/rt-containers` | `~/.local/share/docker` |
| Resource Limits | Terbatas | Terbatas |
| Network | User namespaces | User namespaces |
| Kompatibilitas | Linux dengan user namespaces | Linux dengan user namespaces |

## Contoh Lengkap

```bash
# 1. Cek dukungan sistem
./demo-rootless.sh

# 2. Buat dan jalankan container
./rt.sh --rootless create-container myapp
./rt.sh --rootless run-container myapp

# 3. Monitor (jika didukung)
./rt.sh --rootless monitor myapp 30

# 4. Cleanup
./rt.sh --rootless delete-container myapp
```

## Analogi RT

Seperti **RT yang bekerja dengan wewenang terbatas**:
- RT normal = Ketua RT dengan akses penuh ke fasilitas kompleks
- RT rootless = Wakil RT yang bisa mengatur rumah tapi dengan batasan tertentu
- Tetap bisa mengatur rumah warga, tapi tidak bisa mengubah infrastruktur utama kompleks

Mode rootless memberikan keseimbangan antara **keamanan** dan **kemudahan penggunaan** untuk pengembangan dan testing container.
