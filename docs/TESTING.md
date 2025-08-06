# RT Container Runtime - Testing Framework

Dokumentasi lengkap untuk testing framework RT Container Runtime yang mendukung Docker Compose environment.

## Overview

Testing framework RT Container Runtime dirancang untuk menguji semua aspek container runtime dengan pendekatan yang komprehensif dan terstruktur. Framework ini mendukung berbagai jenis testing mulai dari unit tests hingga stress tests.

## Test Structure

```
tests/
├── run-all-tests.sh              # Main test runner
├── unit-tests.sh                 # Unit tests untuk individual functions
├── integration-tests.sh          # Integration tests untuk complete workflows
├── busybox-tests.sh              # Tests untuk busybox management system
├── namespace-tests.sh            # Tests untuk namespace functionality
├── cgroup-tests.sh               # Tests untuk cgroup resource management
├── network-tests.sh              # Tests untuk network connectivity
├── resource-validation-tests.sh  # Tests untuk resource limiting validation
├── stress-tests.sh               # Stress tests untuk concurrent operations
└── cleanup-verification-tests.sh # Tests untuk cleanup verification
```

## Test Categories

### 1. Unit Tests (`unit-tests.sh`)
- **Purpose**: Test individual functions dan components
- **Requirements**: Tidak memerlukan root privileges
- **Coverage**:
  - Development environment setup
  - Directory structure validation
  - Required tools availability
  - Cgroup filesystem access
  - RT script function validation

**Run Command**:
```bash
make test-unit
# atau
./tests/unit-tests.sh
```

### 2. Integration Tests (`integration-tests.sh`)
- **Purpose**: Test complete workflows dan system integration
- **Requirements**: Root privileges untuk container operations
- **Coverage**:
  - Complete container lifecycle
  - Container resource limits
  - Network connectivity antar containers
  - Concurrent container operations
  - Error recovery mechanisms

**Run Command**:
```bash
make test-integration
# atau
sudo ./tests/integration-tests.sh
```

### 3. Busybox Management Tests (`busybox-tests.sh`)
- **Purpose**: Test busybox management system functionality
- **Requirements**: Root privileges
- **Coverage**:
  - Busybox binary setup dan verification
  - Container filesystem initialization
  - Busybox functionality testing
  - System initialization procedures

**Run Command**:
```bash
make test-busybox
# atau
sudo ./tests/busybox-tests.sh
```

### 4. Namespace Tests (`namespace-tests.sh`)
- **Purpose**: Test namespace management functionality
- **Requirements**: Root privileges
- **Coverage**:
  - PID namespace creation
  - Mount namespace setup
  - UTS namespace configuration
  - IPC namespace management
  - User namespace mapping
  - Complete namespace setup dan cleanup

**Run Command**:
```bash
make test-namespace
# atau
sudo ./tests/namespace-tests.sh
```

### 5. Cgroup Tests (`cgroup-tests.sh`)
- **Purpose**: Test cgroup resource management
- **Requirements**: Root privileges
- **Coverage**:
  - Cgroup structure creation
  - Memory limit configuration
  - CPU limit configuration
  - Process assignment to cgroups
  - Resource usage monitoring
  - Cgroup cleanup procedures

**Run Command**:
```bash
make test-cgroup
# atau
sudo ./tests/cgroup-tests.sh
```

### 6. Network Tests (`network-tests.sh`)
- **Purpose**: Test network namespace dan container communication
- **Requirements**: Root privileges
- **Coverage**:
  - Network namespace creation
  - Veth pair setup
  - IP address assignment
  - Container-to-container connectivity
  - Network monitoring dan debugging
  - Network cleanup procedures

**Run Command**:
```bash
make test-network
# atau
sudo ./tests/network-tests.sh
```

### 7. Resource Validation Tests (`resource-validation-tests.sh`)
- **Purpose**: Test resource limiting validation yang compatible dengan Docker
- **Requirements**: Root privileges
- **Coverage**:
  - Memory limit validation (64MB - 8GB)
  - CPU limit validation (1% - 100%)
  - Invalid parameter rejection
  - Combined resource limits
  - Resource usage monitoring
  - Docker compatibility format

**Run Command**:
```bash
make test-resources
# atau
sudo ./tests/resource-validation-tests.sh
```

### 8. Stress Tests (`stress-tests.sh`)
- **Purpose**: Test system under load dan concurrent operations
- **Requirements**: Root privileges
- **Coverage**:
  - Multiple container creation (up to 5 containers)
  - Concurrent operations (3 simultaneous)
  - Rapid container lifecycle testing
  - Resource exhaustion handling
  - Network stress testing
  - Resource limit stress testing

**Run Command**:
```bash
make test-stress
# atau
sudo ./tests/stress-tests.sh
```

### 9. Cleanup Verification Tests (`cleanup-verification-tests.sh`)
- **Purpose**: Test cleanup verification dan integrate dengan `make test`
- **Requirements**: Root privileges
- **Coverage**:
  - Single container cleanup verification
  - Multiple container cleanup
  - Cleanup-all command testing
  - Orphaned resource cleanup
  - Graceful shutdown cleanup
  - Make test integration

**Run Command**:
```bash
make test-cleanup
# atau
sudo ./tests/cleanup-verification-tests.sh
```

## Running Tests

### Prerequisites

1. **Docker Desktop** (untuk macOS development)
2. **Docker Compose**
3. **Root privileges** (untuk sebagian besar tests)

### Quick Start

```bash
# Setup development environment
make setup

# Run all tests dalam Docker container
make test

# Run specific test categories
make test-unit           # Unit tests only
make test-integration    # Integration tests only
make test-stress         # Stress tests only
make test-resources      # Resource validation tests
make test-cleanup        # Cleanup verification tests
```

### Manual Test Execution

```bash
# Run all tests
sudo ./tests/run-all-tests.sh

# Run individual test suites
sudo ./tests/unit-tests.sh
sudo ./tests/integration-tests.sh
sudo ./tests/stress-tests.sh
sudo ./tests/resource-validation-tests.sh
sudo ./tests/cleanup-verification-tests.sh

# Run specific component tests
sudo ./tests/busybox-tests.sh
sudo ./tests/namespace-tests.sh
sudo ./tests/cgroup-tests.sh
sudo ./tests/network-tests.sh
```

### Docker Environment Testing

Untuk development di macOS, semua tests dijalankan dalam Linux container:

```bash
# Start development container
make dev

# Dalam container, run tests
./tests/run-all-tests.sh

# Atau run specific tests
./tests/stress-tests.sh all
./tests/resource-validation-tests.sh all
```

## Test Configuration

### Resource Limits Testing
- **Memory Limits**: 64MB, 128MB, 256MB, 512MB
- **CPU Limits**: 10%, 25%, 50%, 75%
- **Invalid Values**: Tested untuk proper rejection

### Stress Testing Configuration
- **Max Containers**: 5 containers simultaneously
- **Concurrent Operations**: 3 parallel operations
- **Test Duration**: 30 seconds per stress test
- **Memory per Container**: 64MB (stress tests)
- **CPU per Container**: 20% (stress tests)

### Network Testing
- **Container Network**: 10.0.0.0/24
- **Test Containers**: 2 containers untuk connectivity tests
- **IP Range**: 10.0.0.10 - 10.0.0.11

## Test Results dan Reporting

### Exit Codes
- **0**: All tests passed
- **1**: Some tests failed
- **130**: Tests interrupted (Ctrl+C)

### Output Format
Tests menggunakan color-coded output:
- 🟢 **Green**: Tests passed
- 🔴 **Red**: Tests failed
- 🟡 **Yellow**: Tests skipped atau warnings
- 🔵 **Blue**: Test information
- 🟦 **Cyan**: Cleanup dan setup messages

### Test Summary
Setiap test suite memberikan summary:
```
Tests Passed: 15
Tests Failed: 0
Tests Skipped: 2
Total Tests: 17
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Solution: Run dengan sudo
   sudo ./tests/run-all-tests.sh
   ```

2. **Docker Not Available**
   ```bash
   # Solution: Install Docker Desktop dan start daemon
   make setup
   ```

3. **Cgroups Not Available**
   ```bash
   # Check cgroup availability
   ls -la /sys/fs/cgroup/
   
   # Ensure cgroup v1 is available
   mount | grep cgroup
   ```

4. **Network Namespace Issues**
   ```bash
   # Check namespace support
   unshare --help
   ip netns help
   ```

5. **Test Timeouts**
   - Default timeout: 300 seconds per test suite
   - Individual container operations: 60 seconds
   - Stress tests: 120 seconds

### Debug Mode

Enable verbose output untuk debugging:
```bash
# Set debug environment variables
export VERBOSE_MODE=true
export DEBUG_MODE=true

# Run tests dengan debug info
sudo ./tests/run-all-tests.sh
```

### Individual Test Debugging

Run specific test functions:
```bash
# Example: Run only memory validation
sudo ./tests/resource-validation-tests.sh memory_validation

# Example: Run only stress test for concurrent operations
sudo ./tests/stress-tests.sh concurrent_ops

# Example: Run only single container cleanup test
sudo ./tests/cleanup-verification-tests.sh single_cleanup
```

## Integration dengan CI/CD

### GitHub Actions Example
```yaml
name: RT Container Runtime Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup Docker
      run: |
        sudo apt-get update
        sudo apt-get install -y docker.io docker-compose
    - name: Run Tests
      run: |
        make setup
        make test
```

### Local Development Workflow
```bash
# 1. Setup environment
make setup

# 2. Development cycle
make dev                    # Start development container
# ... make changes ...
./tests/run-all-tests.sh   # Run tests
exit                       # Exit container

# 3. Quick validation
make test-unit             # Fast unit tests
make test-integration      # Integration tests

# 4. Full validation before commit
make test                  # All tests dalam Docker
```

## Test Coverage

### Functional Coverage
- ✅ Container lifecycle management
- ✅ Resource limiting (memory, CPU)
- ✅ Network namespace dan connectivity
- ✅ Filesystem isolation
- ✅ Process isolation
- ✅ Cleanup dan recovery
- ✅ Error handling
- ✅ Concurrent operations
- ✅ Stress testing

### Compatibility Coverage
- ✅ Docker-compatible resource formats
- ✅ Linux namespace features
- ✅ Cgroup v1 compatibility
- ✅ Busybox compatibility
- ✅ Network tools compatibility

### Platform Coverage
- ✅ macOS development (via Docker)
- ✅ Linux runtime environment
- ✅ Docker container environment
- ✅ Various Linux distributions (Ubuntu, Alpine)

## Best Practices

### Writing New Tests
1. **Follow naming convention**: `test_function_name()`
2. **Use helper functions**: `log_test_start()`, `log_test_pass()`, `log_test_fail()`
3. **Include cleanup**: Always cleanup resources after tests
4. **Add timeouts**: Use `timeout` command untuk prevent hanging
5. **Provide clear error messages**: Include context dalam error messages

### Test Organization
1. **Group related tests**: Keep similar functionality together
2. **Use descriptive names**: Test names should explain what they test
3. **Include requirements**: Document privilege requirements
4. **Add analogies**: Use RT housing analogies untuk educational value

### Performance Considerations
1. **Parallel execution**: Tests can run concurrently where safe
2. **Resource cleanup**: Always cleanup to prevent resource leaks
3. **Timeout management**: Set appropriate timeouts untuk different operations
4. **Memory usage**: Monitor memory usage dalam stress tests

## Contributing

Untuk menambah tests baru:

1. **Create test file**: Follow naming convention `*-tests.sh`
2. **Add to run-all-tests.sh**: Include dalam appropriate phase
3. **Update Makefile**: Add make target untuk new test
4. **Document**: Update this documentation
5. **Test**: Verify new tests work dalam Docker environment

### Example New Test Structure
```bash
#!/bin/bash
# RT Container Runtime - New Feature Tests

set -euo pipefail

# Test configuration
TEST_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
RT_SCRIPT="$PROJECT_ROOT/rt.sh"

# Colors dan counters
# ... (standard setup)

# Test functions
test_new_feature() {
    log_test_start "New Feature Test"
    
    # Test implementation
    if new_feature_works; then
        log_test_pass "New Feature Test"
        return 0
    else
        log_test_fail "New Feature Test" "Feature not working"
        return 1
    fi
}

# Main execution
main() {
    check_root_privileges
    cleanup_test_environment
    
    run_test "New Feature" test_new_feature
    
    cleanup_test_environment
    print_test_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Conclusion

Testing framework RT Container Runtime menyediakan comprehensive coverage untuk semua aspek container runtime functionality. Framework ini dirancang untuk:

- **Educational purposes**: Dengan RT housing analogies
- **Development efficiency**: Quick feedback loops
- **Production readiness**: Thorough validation
- **Cross-platform support**: macOS development, Linux runtime
- **CI/CD integration**: Automated testing support

Untuk pertanyaan atau issues, silakan check troubleshooting section atau create issue dalam repository.