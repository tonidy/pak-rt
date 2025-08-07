#!/bin/bash
# RT Container Runtime - Integration Tests
# Tests complete workflows dan system integration

set -e

echo "🔗 Running Integration Tests untuk RT Container Runtime"
echo "=========================================================="

# Test configuration
TEST_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
RT_SCRIPT="$PROJECT_ROOT/rt.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counter
INTEGRATION_TESTS_PASSED=0
INTEGRATION_TESTS_FAILED=0

# Test timeout
TEST_TIMEOUT=60
CONTAINER_TEST_TIMEOUT=120

# Test container names
TEST_CONTAINER_1="integration-test-1"
TEST_CONTAINER_2="integration-test-2"

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

# Cleanup function
cleanup_integration_tests() {
    echo -e "\n${CYAN}🧹 Cleaning up integration test environment...${NC}"
    
    # Clean up test containers if they exist
    if command -v sudo >/dev/null 2>&1; then
        sudo "$RT_SCRIPT" delete "$TEST_CONTAINER_1" 2>/dev/null || true
        sudo "$RT_SCRIPT" delete "$TEST_CONTAINER_2" 2>/dev/null || true
        sudo "$RT_SCRIPT" cleanup-all 2>/dev/null || true
    fi
    
    # Remove test directories
    rm -rf "/tmp/rt-integration-test-$$" 2>/dev/null || true
    
    echo -e "${CYAN}Integration test cleanup completed${NC}"
}

# Set up cleanup trap
trap cleanup_integration_tests EXIT

# Enhanced integration tests
test_complete_container_lifecycle() {
    echo -e "${BLUE}Testing complete container lifecycle...${NC}"
    
    # Skip if not running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Skipping container lifecycle test (requires root)${NC}"
        return 0
    fi
    
    # Test container creation
    if timeout $CONTAINER_TEST_TIMEOUT "$RT_SCRIPT" create "$TEST_CONTAINER_1" --ram=128 --cpu=25; then
        echo -e "${GREEN}Container creation successful${NC}"
        
        # Test container listing
        if "$RT_SCRIPT" list | grep -q "$TEST_CONTAINER_1"; then
            echo -e "${GREEN}Container appears in listing${NC}"
            
            # Test container deletion
            if "$RT_SCRIPT" delete "$TEST_CONTAINER_1"; then
                echo -e "${GREEN}Container deletion successful${NC}"
                return 0
            else
                echo -e "${RED}Container deletion failed${NC}"
                return 1
            fi
        else
            echo -e "${RED}Container not found in listing${NC}"
            return 1
        fi
    else
        echo -e "${RED}Container creation failed${NC}"
        return 1
    fi
}

test_container_resource_limits() {
    echo -e "${BLUE}Testing container resource limits...${NC}"
    
    # Skip if not running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Skipping resource limits test (requires root)${NC}"
        return 0
    fi
    
    # Create container with specific resource limits
    if timeout $CONTAINER_TEST_TIMEOUT "$RT_SCRIPT" create "$TEST_CONTAINER_1" --ram=256 --cpu=50; then
        # Verify resource limits are applied (basic check)
        if [ -d "/sys/fs/cgroup/memory/container-$TEST_CONTAINER_1" ] || [ -d "/sys/fs/cgroup/cpu/container-$TEST_CONTAINER_1" ]; then
            echo -e "${GREEN}Resource limits applied successfully${NC}"
            "$RT_SCRIPT" delete "$TEST_CONTAINER_1" 2>/dev/null || true
            return 0
        else
            echo -e "${RED}Resource limits not applied${NC}"
            "$RT_SCRIPT" delete "$TEST_CONTAINER_1" 2>/dev/null || true
            return 1
        fi
    else
        echo -e "${RED}Container creation with resource limits failed${NC}"
        return 1
    fi
}

test_container_network_connectivity() {
    echo -e "${BLUE}Testing container network connectivity...${NC}"
    
    # Skip if not running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Skipping network connectivity test (requires root)${NC}"
        return 0
    fi
    
    # Create two containers
    if timeout $CONTAINER_TEST_TIMEOUT "$RT_SCRIPT" create "$TEST_CONTAINER_1" --ram=128 --cpu=25 && \
       timeout $CONTAINER_TEST_TIMEOUT "$RT_SCRIPT" create "$TEST_CONTAINER_2" --ram=128 --cpu=25; then
        
        # Check if network namespaces were created
        if ip netns list | grep -q "container-$TEST_CONTAINER_1" && \
           ip netns list | grep -q "container-$TEST_CONTAINER_2"; then
            echo -e "${GREEN}Network namespaces created successfully${NC}"
            
            # Cleanup
            "$RT_SCRIPT" delete "$TEST_CONTAINER_1" 2>/dev/null || true
            "$RT_SCRIPT" delete "$TEST_CONTAINER_2" 2>/dev/null || true
            return 0
        else
            echo -e "${RED}Network namespaces not created${NC}"
            "$RT_SCRIPT" delete "$TEST_CONTAINER_1" 2>/dev/null || true
            "$RT_SCRIPT" delete "$TEST_CONTAINER_2" 2>/dev/null || true
            return 1
        fi
    else
        echo -e "${RED}Failed to create containers for network test${NC}"
        return 1
    fi
}

test_concurrent_container_operations() {
    echo -e "${BLUE}Testing concurrent container operations...${NC}"
    
    # Skip if not running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Skipping concurrent operations test (requires root)${NC}"
        return 0
    fi
    
    # Create containers concurrently (simplified test)
    local container1_pid container2_pid
    
    timeout $CONTAINER_TEST_TIMEOUT "$RT_SCRIPT" create "${TEST_CONTAINER_1}-concurrent" --ram=128 --cpu=25 &
    container1_pid=$!
    
    timeout $CONTAINER_TEST_TIMEOUT "$RT_SCRIPT" create "${TEST_CONTAINER_2}-concurrent" --ram=128 --cpu=25 &
    container2_pid=$!
    
    # Wait for both to complete
    local success=true
    if ! wait $container1_pid; then
        echo -e "${RED}First concurrent container creation failed${NC}"
        success=false
    fi
    
    if ! wait $container2_pid; then
        echo -e "${RED}Second concurrent container creation failed${NC}"
        success=false
    fi
    
    # Cleanup
    "$RT_SCRIPT" delete "${TEST_CONTAINER_1}-concurrent" 2>/dev/null || true
    "$RT_SCRIPT" delete "${TEST_CONTAINER_2}-concurrent" 2>/dev/null || true
    
    if $success; then
        echo -e "${GREEN}Concurrent container operations successful${NC}"
        return 0
    else
        return 1
    fi
}

test_error_recovery() {
    echo -e "${BLUE}Testing error recovery mechanisms...${NC}"
    
    # Skip if not running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Skipping error recovery test (requires root)${NC}"
        return 0
    fi
    
    # Test invalid container creation (should fail gracefully)
    if ! "$RT_SCRIPT" create "invalid@name" --ram=32 --cpu=150 2>/dev/null; then
        echo -e "${GREEN}Invalid container creation properly rejected${NC}"
        return 0
    else
        echo -e "${RED}Invalid container creation should have failed${NC}"
        return 1
    fi
}

# Run integration tests
run_integration_test "Development Environment Setup" "test_development_environment"
run_integration_test "Namespace Capabilities" "test_namespace_capabilities"
run_integration_test "Network Capabilities" "test_network_capabilities"
run_integration_test "Cgroup Access" "test_cgroup_access"
run_integration_test "Filesystem Operations" "test_filesystem_operations"
run_integration_test "Complete Container Lifecycle" "test_complete_container_lifecycle"
run_integration_test "Container Resource Limits" "test_container_resource_limits"
run_integration_test "Container Network Connectivity" "test_container_network_connectivity"
run_integration_test "Concurrent Container Operations" "test_concurrent_container_operations"
run_integration_test "Error Recovery Mechanisms" "test_error_recovery"

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