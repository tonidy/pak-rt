# Requirements Document

## Introduction

Proyek ini bertujuan untuk membuat bash script yang mengimplementasikan container runtime sederhana menggunakan Linux namespaces dan cgroups. Script ini akan memberikan pemahaman mendalam tentang bagaimana container bekerja di level sistem operasi, dengan fokus pada isolasi proses, network, dan resource management menggunakan busybox sebagai base image.

## Requirements

### Requirement 1: Linux Namespace Management

**User Story:** Sebagai developer yang ingin memahami container internals, saya ingin script yang dapat membuat dan mengelola Linux namespaces, sehingga saya dapat melihat bagaimana isolasi proses bekerja di level kernel.

#### Acceptance Criteria

1. WHEN script dijalankan dengan parameter namespace THEN system SHALL create isolated PID, mount, UTS, IPC, dan user namespaces
2. WHEN namespace dibuat THEN script SHALL provide educational output yang menjelaskan setiap namespace yang dibuat
3. WHEN namespace aktif THEN proses di dalam namespace SHALL terisolasi dari host system
4. IF namespace creation gagal THEN script SHALL provide clear error message dan cleanup resources

### Requirement 2: Network Namespace dengan Container Communication

**User Story:** Sebagai developer yang ingin memahami container networking, saya ingin membuat network namespace yang memungkinkan 2 container berkomunikasi langsung tanpa melalui host, sehingga saya dapat memahami konsep container-to networking.

#### Acceptance Criteria

1. WHEN script membuat network namespace THEN system SHALL create isolated network stack untuk setiap container
2. WHEN 2 container dibuat THEN script SHALL setup virtual ethernet pair untuk menghubungkan kedua container
3. WHEN network setup selesai THEN kedua container SHALL dapat berkomunikasi langsung tanpa routing melalui host
4. WHEN container dihapus THEN script SHALL cleanup network interfaces dan namespaces
5. IF network setup gagal THEN script SHALL rollback network configuration dan provide error details

### Requirement 3: Cgroup Resource Management

**User Story:** Sebagai developer yang ingin memahami resource isolation, saya ingin script yang dapat membatasi RAM dan CPU usage untuk setiap container, sehingga saya dapat melihat bagaimana resource limiting bekerja di container.

#### Acceptance Criteria

1. WHEN container dibuat dengan parameter RAM THEN script SHALL create cgroup dengan memory limit sesuai parameter
2. WHEN container dibuat dengan parameter CPU THEN script SHALL create cgroup dengan CPU limit sesuai parameter  
3. WHEN container running THEN resource usage SHALL tidak melebihi limit yang ditetapkan
4. WHEN container dihapus THEN script SHALL cleanup cgroup resources
5. IF cgroup creation gagal THEN script SHALL provide error message dan tidak start container

### Requirement 4: Busybox Integration

**User Story:** Sebagai developer yang ingin container yang lightweight, saya ingin script menggunakan busybox static binary sebagai base image, sehingga container memiliki footprint minimal namun tetap functional.

#### Acceptance Criteria

1. WHEN script setup THEN system SHALL download atau verify busybox static binary
2. WHEN container dibuat THEN script SHALL use busybox sebagai init process dalam container
3. WHEN container running THEN busybox SHALL provide basic shell functionality
4. IF busybox tidak tersedia THEN script SHALL download atau provide instructions untuk mendapatkannya

### Requirement 5: Container Lifecycle Management dengan RT Script

**User Story:** Sebagai user yang ingin mengelola container seperti RT mengelola warga, saya ingin command-line interface yang mudah menggunakan script `rt.sh` untuk create, list, run, dan delete container, sehingga saya dapat mengelola container dengan mudah.

#### Acceptance Criteria

1. WHEN user menjalankan `./rt.sh create` command THEN script SHALL create container dengan nama, RAM, dan CPU limit yang ditentukan
2. WHEN user menjalankan `./rt.sh list` command THEN script SHALL show semua container yang ada dengan status dan resource usage
3. WHEN user menjalankan `./rt.sh run` command THEN script SHALL start container dan provide interactive shell
4. WHEN user menjalankan `./rt.sh delete` command THEN script SHALL cleanup semua resources (namespaces, cgroups, network)
5. IF command syntax salah THEN script SHALL show usage help dan examples

### Requirement 6: Educational Output dan Monitoring

**User Story:** Sebagai developer yang belajar container technology, saya ingin script memberikan output yang educational dan monitoring real-time, sehingga saya dapat memahami apa yang terjadi di setiap step.

#### Acceptance Criteria

1. WHEN setiap operation dijalankan THEN script SHALL provide verbose output yang menjelaskan setiap step
2. WHEN container running THEN script SHALL show real-time resource usage (RAM, CPU)
3. WHEN network setup THEN script SHALL show network configuration dan IP addresses
4. WHEN error terjadi THEN script SHALL provide detailed troubleshooting information
5. IF user request help THEN script SHALL show comprehensive usage guide dengan examples

### Requirement 7: Docker Compose Development Environment

**User Story:** Sebagai developer yang menggunakan macOS, saya ingin development environment yang mudah disetup menggunakan Docker Compose dan Makefile, sehingga saya dapat menjalankan dan test container runtime tanpa perlu setup Linux environment secara manual.

#### Acceptance Criteria

1. WHEN developer menjalankan `make setup` THEN system SHALL create Docker Compose environment dengan Linux container
2. WHEN developer menjalankan `make dev` THEN system SHALL start development container dengan volume mounting untuk code
3. WHEN developer menjalankan `make test` THEN system SHALL run automated tests dalam Linux environment
4. WHEN developer menjalankan `make clean` THEN system SHALL cleanup Docker containers dan volumes
5. IF Docker tidak tersedia THEN Makefile SHALL provide clear instructions untuk Docker installation
