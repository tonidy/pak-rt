# Pak-RT Container Runtime - Development Backlog

## 🎯 Current Status
Pak-RT is a functional container runtime with basic container operations working correctly. The core features like container creation, filesystem isolation, network connectivity, and basic exec functionality are operational.

## 🚀 High Priority Items

### 1. CPU Limiting Implementation
**Priority:** High  
**Complexity:** Medium  
**Description:** Implement CPU resource limiting for containers using cgroup v2 CPU controller.

**Tasks:**
- [ ] Implement CPU percentage limiting in cgroup setup
- [ ] Add CPU usage monitoring and reporting
- [ ] Test CPU throttling with stress tests
- [ ] Validate CPU limits are enforced correctly

**Expected Outcome:** Containers respect CPU percentage limits (e.g., 25% CPU usage)

### 2. Container-to-Container Network Communication
**Priority:** High  
**Complexity:** Medium  
**Description:** Enable network communication between containers on the same host.

**Tasks:**
- [ ] Implement container network bridge setup
- [ ] Add routing between container networks
- [ ] Test ping/connectivity between containers
- [ ] Add network isolation options
- [ ] Implement port forwarding/mapping

**Expected Outcome:** Containers can communicate with each other via IP addresses

### 3. Memory Accounting Deep Dive
**Priority:** Medium  
**Complexity:** High  
**Description:** Fix memory usage tracking and OOM testing for proper resource management.

**Root Cause:** Process exec not properly tracked in cgroup v2, memory accounting shows 0 usage

**Tasks:**
- [ ] Research cgroup v2 memory controller delegation
- [ ] Fix process tree management for exec processes
- [ ] Implement proper memory controller activation
- [ ] Create effective memory stress tests
- [ ] Validate OOM killer functionality
- [ ] Add memory usage monitoring and alerts

**Technical Details:**
- Current issue: `nsenter` spawned processes not tracked in container cgroup
- Memory usage always shows 0 despite file creation
- OOM events never triggered even with 80MB allocation on 64MB limit
- Need proper cgroup delegation and process assignment

## 🔧 Medium Priority Items

### 4. Container Lifecycle Management
**Priority:** Medium  
**Complexity:** Low-Medium

**Tasks:**
- [ ] Implement container pause/resume functionality
- [ ] Add container restart policies
- [ ] Implement graceful container shutdown
- [ ] Add container health checks
- [ ] Implement container logs collection

### 5. Storage and Volumes
**Priority:** Medium  
**Complexity:** Medium

**Tasks:**
- [ ] Implement bind mounts for containers
- [ ] Add volume management (create/delete/list)
- [ ] Implement persistent storage for containers
- [ ] Add storage quota management
- [ ] Support for different filesystem backends

### 6. Security Enhancements
**Priority:** Medium  
**Complexity:** High

**Tasks:**
- [ ] Implement user namespace isolation
- [ ] Add seccomp profiles for containers
- [ ] Implement capability dropping
- [ ] Add SELinux/AppArmor integration
- [ ] Implement container image verification

## 🎨 Low Priority Items

### 7. Container Images and Registry
**Priority:** Low  
**Complexity:** High

**Tasks:**
- [ ] Implement basic container image format
- [ ] Add image layering support
- [ ] Implement image pull/push from registry
- [ ] Add image caching and management
- [ ] Support for OCI image format

### 8. Advanced Networking
**Priority:** Low  
**Complexity:** High

**Tasks:**
- [ ] Implement overlay networks
- [ ] Add DNS resolution for containers
- [ ] Implement network policies
- [ ] Add load balancing capabilities
- [ ] Support for external network plugins

### 9. Monitoring and Observability
**Priority:** Low  
**Complexity:** Medium

**Tasks:**
- [ ] Implement metrics collection (CPU, memory, network, disk)
- [ ] Add container performance monitoring
- [ ] Implement log aggregation
- [ ] Add alerting capabilities
- [ ] Create monitoring dashboard

### 10. CLI and UX Improvements
**Priority:** Low  
**Complexity:** Low

**Tasks:**
- [ ] Add bash completion for rt.sh commands
- [ ] Implement JSON output format for scripting
- [ ] Add progress bars for long operations
- [ ] Improve error messages and help text
- [ ] Add configuration file support

## 🐛 Known Issues

### Memory Accounting (High Priority)
- **Issue:** Memory usage tracking not working correctly
- **Impact:** Cannot enforce memory limits or trigger OOM
- **Root Cause:** cgroup v2 process assignment issues
- **Status:** Under investigation

### Network Setup Errors (Medium Priority)
- **Issue:** Occasional veth pair creation failures
- **Impact:** Container networking may fail
- **Workaround:** Retry container creation
- **Status:** Partially fixed with unique naming

## 📋 Technical Debt

### Code Organization
- [ ] Refactor large functions into smaller modules
- [ ] Improve error handling consistency
- [ ] Add comprehensive unit tests
- [ ] Improve logging and debugging capabilities
- [ ] Add code documentation and comments

### Performance Optimization
- [ ] Optimize container startup time
- [ ] Reduce memory footprint of runtime
- [ ] Improve network setup performance
- [ ] Add caching for frequently accessed data

## 🎯 Next Sprint Goals

**Sprint Focus:** CPU Limiting and Network Communication

**Primary Goals:**
1. Implement CPU percentage limiting with cgroup v2
2. Enable container-to-container communication
3. Add CPU usage monitoring and reporting

**Secondary Goals:**
1. Investigate memory accounting issues
2. Improve error handling and user experience
3. Add more comprehensive testing

**Success Criteria:**
- Containers respect CPU limits (e.g., 25% max usage)
- Containers can ping each other by IP address
- CPU usage is accurately reported in container list
- Memory investigation provides clear next steps

---

**Last Updated:** 2025-08-07  
**Version:** 1.0  
**Maintainer:** Pak-RT Development Team
