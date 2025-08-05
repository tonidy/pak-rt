#!/bin/bash
# Pak RT Container Runtime - Integration Tests
# Tests complete workflows dan system integration

set -e

echo "🔗 Running Integration Tests untuk Pak RT Container Runtime"
echo "=========================================================="

# Test configuration
TEST_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
INTEGRATION_TESTS_PASSED=0
INTEGRATION_TESTS_FAILED=0

# Test helper functions
run_integration_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "\n${YELLOW}Testing: $test_name${NC}"
    
    if $test_function; then
        echo -e "${GREEN}✅ $test_name PASSED${NC}"
        ((INTEGRATION_TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name FAILED${NC}"
        ((INTEGRATION_TESTS_FAILED++))
    fi
}

# Test 1: Development Environment Integration
test_development_environment() {
    # Check if we can create temporary directories
    local temp_dir="/tmp/rt-test-$$"
    
    if mkdir -p "$temp_dir" && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        return 0
    else
        return 1
    fi
}

# Test 2: Namespace Capabilities
test_namespace_capabilities() {
    # Test if we can create basic namespaces
    if unshare --pid --fork --mount-proc echo "namespace test" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Test 3: Network Namespace Capabilities
test_network_capabilities() {
    # Test if we can create network namespaces
    local test_ns="rt-test-ns-$$"
    
    if ip netns add "$test_ns" 2>/dev/null; then
        ip netns delete "$test_ns" 2>/dev/null
        return 0
    else
        return 1
    fi
}

# Test 4: Cgroup Access
test_cgroup_access() {
    # Test if we can access cgroup filesystem
    if [ -w "/sys/fs/cgroup" ] || [ -r "/sys/fs/cgroup/memory" ] || [ -r "/sys/fs/cgroup/cpu" ]; then
        return 0
    else
        return 1
    fi
}

# Test 5: File System Operations
test_filesystem_operations() {
    local test_dir="/tmp/rt-fs-test-$$"
    
    # Test directory creation, file operations, dan cleanup
    if mkdir -p "$test_dir/subdir" && \
       echo "test content" > "$test_dir/test.txt" && \
       [ -f "$test_dir/test.txt" ] && \
       rm -rf "$test_dir"; then
        return 0
    else
        return 1
    fi
}

# Run integration tests
run_integration_test "Development Environment Setup" "test_development_environment"
run_integration_test "Namespace Capabilities" "test_namespace_capabilities"
run_integration_test "Network Capabilities" "test_network_capabilities"
run_integration_test "Cgroup Access" "test_cgroup_access"
run_integration_test "Filesystem Operations" "test_filesystem_operations"

# Summary
echo -e "\n=========================================================="
echo -e "Integration Test Summary:"
echo -e "${GREEN}Passed: $INTEGRATION_TESTS_PASSED${NC}"
echo -e "${RED}Failed: $INTEGRATION_TESTS_FAILED${NC}"

if [ $INTEGRATION_TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All integration tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some integration tests failed!${NC}"
    exit 1
fi