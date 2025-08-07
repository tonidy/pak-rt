#!/bin/bash

# Network functionality tests for RT Container Runtime
# Tests the network namespace and container communication implementation

set -euo pipefail

# Test configuration
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RT_SCRIPT="$TEST_DIR/../rt.sh"
readonly TEST_CONTAINER_1="test-net-container-1"
readonly TEST_CONTAINER_2="test-net-container-2"

# Colors for test output
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RESET='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
    echo -e "${COLOR_YELLOW}[TEST]${COLOR_RESET} $1"
}

log_pass() {
    echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $1"
    ((TESTS_FAILED++))
}

# Test runner
run_test() {
    local test_name=$1
    local test_function=$2
    
    ((TESTS_RUN++))
    log_test "Running: $test_name"
    
    if $test_function; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Cleanup function
cleanup_test_environment() {
    echo "Cleaning up test environment..."
    
    # Cleanup test containers
    sudo "$RT_SCRIPT" cleanup-test-network &>/dev/null || true
    
    # Additional cleanup for any leftover resources
    sudo ip netns delete "container-$TEST_CONTAINER_1" 2>/dev/null || true
    sudo ip netns delete "container-$TEST_CONTAINER_2" 2>/dev/null || true
    sudo ip link delete "veth-$TEST_CONTAINER_1" 2>/dev/null || true
    sudo ip link delete "veth-$TEST_CONTAINER_2" 2>/dev/null || true
    
    # Remove test directories
    sudo rm -rf "/tmp/containers/$TEST_CONTAINER_1" 2>/dev/null || true
    sudo rm -rf "/tmp/containers/$TEST_CONTAINER_2" 2>/dev/null || true
    
    echo "Cleanup completed."
}

# Test 1: Basic network functionality test
test_basic_network_functionality() {
    sudo "$RT_SCRIPT" test-network &>/dev/null
}

# Test 2: Create test network setup
test_create_test_network() {
    sudo "$RT_SCRIPT" create-test-network "$TEST_CONTAINER_1" "$TEST_CONTAINER_2" &>/dev/null
}

# Test 3: Verify network namespaces exist
test_network_namespaces_exist() {
    ip netns list | grep -q "container-$TEST_CONTAINER_1" && \
    ip netns list | grep -q "container-$TEST_CONTAINER_2"
}

# Test 4: Verify veth pairs exist
test_veth_pairs_exist() {
    ip link show | grep -q "veth-$TEST_CONTAINER_1" && \
    ip link show | grep -q "veth-$TEST_CONTAINER_2"
}

# Test 5: Verify IP addresses assigned
test_ip_addresses_assigned() {
    ip netns exec "container-$TEST_CONTAINER_1" ip addr show | grep -q "10.0.0.10" && \
    ip netns exec "container-$TEST_CONTAINER_2" ip addr show | grep -q "10.0.0.11"
}

# Test 6: Test container connectivity
test_container_connectivity() {
    sudo "$RT_SCRIPT" test-connectivity "$TEST_CONTAINER_1" "$TEST_CONTAINER_2" &>/dev/null
}

# Test 7: Test network information display
test_network_info_display() {
    sudo "$RT_SCRIPT" show-network "$TEST_CONTAINER_1" &>/dev/null
}

# Test 8: Test network debugging
test_network_debugging() {
    sudo "$RT_SCRIPT" debug-network "$TEST_CONTAINER_1" &>/dev/null
}

# Test 9: Test network monitoring (short duration)
test_network_monitoring() {
    timeout 5 sudo "$RT_SCRIPT" monitor-network "$TEST_CONTAINER_1" 3 &>/dev/null
}

# Test 10: Test network cleanup
test_network_cleanup() {
    sudo "$RT_SCRIPT" cleanup-test-network &>/dev/null
    
    # Verify cleanup worked
    ! ip netns list | grep -q "container-$TEST_CONTAINER_1" && \
    ! ip netns list | grep -q "container-$TEST_CONTAINER_2" && \
    ! ip link show | grep -q "veth-$TEST_CONTAINER_1" && \
    ! ip link show | grep -q "veth-$TEST_CONTAINER_2"
}

# Main test execution
main() {
    echo "=========================================="
    echo "RT Container Runtime - Network Tests"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "Error: Network tests require root privileges"
        echo "Please run with: sudo $0"
        exit 1
    fi
    
    # Check if RT script exists
    if [[ ! -f "$RT_SCRIPT" ]]; then
        echo "Error: RT script not found at $RT_SCRIPT"
        exit 1
    fi
    
    # Setup cleanup trap
    trap cleanup_test_environment EXIT
    
    # Initial cleanup
    cleanup_test_environment
    
    echo "Starting network functionality tests..."
    echo ""
    
    # Run tests
    run_test "Basic network functionality" test_basic_network_functionality
    run_test "Create test network setup" test_create_test_network
    run_test "Network namespaces exist" test_network_namespaces_exist
    run_test "Veth pairs exist" test_veth_pairs_exist
    run_test "IP addresses assigned" test_ip_addresses_assigned
    run_test "Container connectivity" test_container_connectivity
    run_test "Network information display" test_network_info_display
    run_test "Network debugging" test_network_debugging
    run_test "Network monitoring" test_network_monitoring
    run_test "Network cleanup" test_network_cleanup
    
    # Test summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Tests Run: $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${COLOR_GREEN}All tests passed!${COLOR_RESET}"
        echo ""
        echo "Network namespace implementation is working correctly."
        echo "Container-to communication is functional."
        exit 0
    else
        echo -e "${COLOR_RED}Some tests failed!${COLOR_RESET}"
        echo ""
        echo "Please check the implementation and try again."
        exit 1
    fi
}

# Run main function
main "$@"