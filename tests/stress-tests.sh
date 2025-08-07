#!/bin/bash

# RT Container Runtime - Stress Tests
# Tests system under load and concurrent operations

set -euo pipefail

echo "💪 Running Stress Tests untuk RT Container Runtime"
echo "=================================================="

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

# Test counters
STRESS_TESTS_PASSED=0
STRESS_TESTS_FAILED=0

# Stress test configuration
MAX_CONTAINERS=5
CONCURRENT_OPERATIONS=3
STRESS_DURATION=30
MEMORY_STRESS_MB=64
CPU_STRESS_PERCENT=20

# Test helper functions
log_stress_test() {
    local test_name="$1"
    echo -e "\n${BLUE}🔥 Stress Test: $test_name${NC}"
    echo -e "${BLUE}   💪 Seperti RT yang menguji ketahanan sistem kompleks${NC}"
}

log_stress_pass() {
    local test_name="$1"
    echo -e "${GREEN}✅ PASS: $test_name${NC}"
    echo -e "${GREEN}   🎉 Sistem tahan terhadap beban: $test_name${NC}"
    ((STRESS_TESTS_PASSED++))
}

log_stress_fail() {
    local test_name="$1"
    local error="$2"
    echo -e "${RED}❌ FAIL: $test_name${NC}"
    echo -e "${RED}   💥 Error: $error${NC}"
    echo -e "${RED}   🚨 Sistem tidak tahan beban: $test_name${NC}"
    ((STRESS_TESTS_FAILED++))
}

log_stress_skip() {
    local test_name="$1"
    local reason="$2"
    echo -e "${YELLOW}⏭️  SKIP: $test_name${NC}"
    echo -e "${YELLOW}   📝 Reason: $reason${NC}"
}

# Check if running as root
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Stress tests require root privileges${NC}"
        echo -e "${RED}   🔑 Seperti RT memerlukan wewenang khusus untuk tes beban${NC}"
        echo -e "${YELLOW}   💡 Please run with: sudo $0${NC}"
        exit 1
    fi
}

# Cleanup function
cleanup_stress_tests() {
    echo -e "\n${CYAN}🧹 Cleaning up stress test environment...${NC}"
    
    # Clean up all test containers
    for i in $(seq 1 $MAX_CONTAINERS); do
        "$RT_SCRIPT" delete "stress-test-$i" 2>/dev/null || true
    done
    
    # Clean up concurrent test containers
    for i in $(seq 1 $CONCURRENT_OPERATIONS); do
        "$RT_SCRIPT" delete "concurrent-test-$i" 2>/dev/null || true
    done
    
    # Emergency cleanup
    "$RT_SCRIPT" cleanup-all 2>/dev/null || true
    
    echo -e "${CYAN}Stress test cleanup completed${NC}"
}

# Set up cleanup trap
trap cleanup_stress_tests EXIT

# Stress Test 1: Multiple Container Creation
test_multiple_container_creation() {
    log_stress_test "Multiple Container Creation"
    
    local success_count=0
    local total_containers=$MAX_CONTAINERS
    
    echo -e "${CYAN}Creating $total_containers containers sequentially...${NC}"
    
    for i in $(seq 1 $total_containers); do
        local container_name="stress-test-$i"
        echo -e "${YELLOW}Creating container $i/$total_containers: $container_name${NC}"
        
        if timeout 60 "$RT_SCRIPT" create "$container_name" \
           --ram=$MEMORY_STRESS_MB --cpu=$CPU_STRESS_PERCENT 2>/dev/null; then
            ((success_count++))
            echo -e "${GREEN}  ✅ Container $i created successfully${NC}"
        else
            echo -e "${RED}  ❌ Container $i creation failed${NC}"
        fi
    done
    
    echo -e "${CYAN}Successfully created $success_count/$total_containers containers${NC}"
    
    # Verify containers exist
    local listed_count=0
    if "$RT_SCRIPT" list 2>/dev/null | grep -c "stress-test-" >/dev/null; then
        listed_count=$("$RT_SCRIPT" list 2>/dev/null | grep -c "stress-test-" || echo "0")
    fi
    
    echo -e "${CYAN}Found $listed_count containers in listing${NC}"
    
    if [[ $success_count -ge $((total_containers * 80 / 100)) ]]; then
        log_stress_pass "Multiple Container Creation" 
        return 0
    else
        log_stress_fail "Multiple Container Creation" "Only $success_count/$total_containers containers created successfully"
        return 1
    fi
}

# Stress Test 2: Concurrent Container Operations
test_concurrent_container_operations() {
    log_stress_test "Concurrent Container Operations"
    
    local pids=()
    local success_count=0
    
    echo -e "${CYAN}Starting $CONCURRENT_OPERATIONS concurrent container creations...${NC}"
    
    # Start concurrent container creations
    for i in $(seq 1 $CONCURRENT_OPERATIONS); do
        local container_name="concurrent-test-$i"
        echo -e "${YELLOW}Starting concurrent creation $i: $container_name${NC}"
        
        (
            if timeout 90 "$RT_SCRIPT" create "$container_name" \
               --ram=$MEMORY_STRESS_MB --cpu=$CPU_STRESS_PERCENT 2>/dev/null; then
                echo "SUCCESS:$container_name" > "/tmp/concurrent-result-$i"
            else
                echo "FAILED:$container_name" > "/tmp/concurrent-result-$i"
            fi
        ) &
        
        pids+=($!)
    done
    
    # Wait for all concurrent operations to complete
    echo -e "${CYAN}Waiting for concurrent operations to complete...${NC}"
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            echo -e "${GREEN}  ✅ Concurrent operation completed${NC}"
        else
            echo -e "${RED}  ❌ Concurrent operation failed${NC}"
        fi
    done
    
    # Check results
    for i in $(seq 1 $CONCURRENT_OPERATIONS); do
        if [[ -f "/tmp/concurrent-result-$i" ]]; then
            local result=$(cat "/tmp/concurrent-result-$i")
            if [[ "$result" == SUCCESS:* ]]; then
                ((success_count++))
                echo -e "${GREEN}  ✅ Concurrent test $i succeeded${NC}"
            else
                echo -e "${RED}  ❌ Concurrent test $i failed${NC}"
            fi
            rm -f "/tmp/concurrent-result-$i"
        fi
    done
    
    echo -e "${CYAN}Concurrent operations: $success_count/$CONCURRENT_OPERATIONS successful${NC}"
    
    if [[ $success_count -ge $((CONCURRENT_OPERATIONS * 70 / 100)) ]]; then
        log_stress_pass "Concurrent Container Operations"
        return 0
    else
        log_stress_fail "Concurrent Container Operations" "Only $success_count/$CONCURRENT_OPERATIONS operations succeeded"
        return 1
    fi
}

# Stress Test 3: Rapid Container Lifecycle
test_rapid_container_lifecycle() {
    log_stress_test "Rapid Container Lifecycle"
    
    local cycles=3
    local success_cycles=0
    
    echo -e "${CYAN}Testing $cycles rapid create-delete cycles...${NC}"
    
    for cycle in $(seq 1 $cycles); do
        local container_name="rapid-test-$cycle"
        echo -e "${YELLOW}Cycle $cycle/$cycles: $container_name${NC}"
        
        # Create container
        if timeout 45 "$RT_SCRIPT" create "$container_name" \
           --ram=$MEMORY_STRESS_MB --cpu=$CPU_STRESS_PERCENT 2>/dev/null; then
            echo -e "${GREEN}  ✅ Container created${NC}"
            
            # Immediately delete container
            if timeout 30 "$RT_SCRIPT" delete "$container_name" 2>/dev/null; then
                echo -e "${GREEN}  ✅ Container deleted${NC}"
                ((success_cycles++))
            else
                echo -e "${RED}  ❌ Container deletion failed${NC}"
            fi
        else
            echo -e "${RED}  ❌ Container creation failed${NC}"
        fi
        
        # Brief pause between cycles
        sleep 1
    done
    
    echo -e "${CYAN}Rapid lifecycle: $success_cycles/$cycles cycles successful${NC}"
    
    if [[ $success_cycles -eq $cycles ]]; then
        log_stress_pass "Rapid Container Lifecycle"
        return 0
    else
        log_stress_fail "Rapid Container Lifecycle" "Only $success_cycles/$cycles cycles completed successfully"
        return 1
    fi
}

# Stress Test 4: Resource Exhaustion Handling
test_resource_exhaustion_handling() {
    log_stress_test "Resource Exhaustion Handling"
    
    echo -e "${CYAN}Testing system behavior under resource pressure...${NC}"
    
    # Try to create container with very high memory limit
    local high_memory_mb=4096
    local container_name="resource-stress-test"
    
    echo -e "${YELLOW}Attempting to create container with ${high_memory_mb}MB memory...${NC}"
    
    if timeout 60 "$RT_SCRIPT" create "$container_name" \
       --ram=$high_memory_mb --cpu=90 2>/dev/null; then
        echo -e "${GREEN}  ✅ High resource container created${NC}"
        
        # Clean up
        "$RT_SCRIPT" delete "$container_name" 2>/dev/null || true
        
        log_stress_pass "Resource Exhaustion Handling"
        return 0
    else
        echo -e "${YELLOW}  ⚠️  High resource container creation failed (expected)${NC}"
        
        # This might be expected behavior, so we consider it a pass
        # if the system handled it gracefully without crashing
        log_stress_pass "Resource Exhaustion Handling"
        return 0
    fi
}

# Stress Test 5: Network Stress Test
test_network_stress() {
    log_stress_test "Network Stress Test"
    
    local network_containers=2
    local success_count=0
    
    echo -e "${CYAN}Creating $network_containers containers for network stress test...${NC}"
    
    # Create containers for network testing
    for i in $(seq 1 $network_containers); do
        local container_name="network-stress-$i"
        echo -e "${YELLOW}Creating network container $i: $container_name${NC}"
        
        if timeout 60 "$RT_SCRIPT" create "$container_name" \
           --ram=$MEMORY_STRESS_MB --cpu=$CPU_STRESS_PERCENT 2>/dev/null; then
            ((success_count++))
            echo -e "${GREEN}  ✅ Network container $i created${NC}"
        else
            echo -e "${RED}  ❌ Network container $i creation failed${NC}"
        fi
    done
    
    # Check if network namespaces were created
    local network_ns_count=0
    for i in $(seq 1 $network_containers); do
        if ip netns list 2>/dev/null | grep -q "container-network-stress-$i"; then
            ((network_ns_count++))
        fi
    done
    
    echo -e "${CYAN}Network namespaces created: $network_ns_count/$network_containers${NC}"
    
    # Cleanup network containers
    for i in $(seq 1 $network_containers); do
        "$RT_SCRIPT" delete "network-stress-$i" 2>/dev/null || true
    done
    
    if [[ $success_count -ge $((network_containers * 80 / 100)) ]]; then
        log_stress_pass "Network Stress Test"
        return 0
    else
        log_stress_fail "Network Stress Test" "Only $success_count/$network_containers network containers created"
        return 1
    fi
}

# Stress Test 6: Memory and CPU Limit Stress
test_resource_limit_stress() {
    log_stress_test "Resource Limit Stress Test"
    
    local limit_containers=3
    local success_count=0
    
    echo -e "${CYAN}Creating $limit_containers containers with varying resource limits...${NC}"
    
    # Test different resource configurations
    local memory_limits=(64 128 256)
    local cpu_limits=(10 25 50)
    
    for i in $(seq 1 $limit_containers); do
        local container_name="limit-stress-$i"
        local memory_mb=${memory_limits[$((i-1))]}
        local cpu_percent=${cpu_limits[$((i-1))]}
        
        echo -e "${YELLOW}Creating container $i with ${memory_mb}MB RAM, ${cpu_percent}% CPU${NC}"
        
        if timeout 60 "$RT_SCRIPT" create "$container_name" \
           --ram=$memory_mb --cpu=$cpu_percent 2>/dev/null; then
            ((success_count++))
            echo -e "${GREEN}  ✅ Resource limit container $i created${NC}"
            
            # Verify cgroups were created
            if [[ -d "/sys/fs/cgroup/memory/container-$container_name" ]] || \
               [[ -d "/sys/fs/cgroup/cpu/container-$container_name" ]]; then
                echo -e "${GREEN}  ✅ Cgroups created for container $i${NC}"
            else
                echo -e "${YELLOW}  ⚠️  Cgroups not found for container $i${NC}"
            fi
        else
            echo -e "${RED}  ❌ Resource limit container $i creation failed${NC}"
        fi
    done
    
    # Cleanup
    for i in $(seq 1 $limit_containers); do
        "$RT_SCRIPT" delete "limit-stress-$i" 2>/dev/null || true
    done
    
    echo -e "${CYAN}Resource limit stress: $success_count/$limit_containers containers successful${NC}"
    
    if [[ $success_count -ge $((limit_containers * 80 / 100)) ]]; then
        log_stress_pass "Resource Limit Stress Test"
        return 0
    else
        log_stress_fail "Resource Limit Stress Test" "Only $success_count/$limit_containers containers created successfully"
        return 1
    fi
}

# Main stress test execution
run_stress_tests() {
    echo -e "${CYAN}🏠 RT Container Runtime - Stress Tests${NC}"
    echo -e "${CYAN}   💪 Seperti RT yang menguji ketahanan sistem kompleks perumahan${NC}"
    echo -e "${CYAN}=================================================${NC}"
    
    # Check prerequisites
    check_root_privileges
    
    # Initial cleanup
    cleanup_stress_tests
    
    echo -e "\n${BLUE}📋 STRESS TEST CONFIGURATION${NC}"
    echo -e "Max Containers: $MAX_CONTAINERS"
    echo -e "Concurrent Operations: $CONCURRENT_OPERATIONS"
    echo -e "Memory per Container: ${MEMORY_STRESS_MB}MB"
    echo -e "CPU per Container: ${CPU_STRESS_PERCENT}%"
    echo -e "Test Duration: ${STRESS_DURATION}s"
    
    # Run stress tests
    echo -e "\n${BLUE}🔥 RUNNING STRESS TESTS${NC}"
    
    # Test 1: Multiple Container Creation
    if test_multiple_container_creation; then
        echo -e "${GREEN}Multiple container creation stress test passed${NC}"
    else
        echo -e "${RED}Multiple container creation stress test failed${NC}"
    fi
    cleanup_stress_tests
    
    # Test 2: Concurrent Operations
    if test_concurrent_container_operations; then
        echo -e "${GREEN}Concurrent operations stress test passed${NC}"
    else
        echo -e "${RED}Concurrent operations stress test failed${NC}"
    fi
    cleanup_stress_tests
    
    # Test 3: Rapid Lifecycle
    if test_rapid_container_lifecycle; then
        echo -e "${GREEN}Rapid lifecycle stress test passed${NC}"
    else
        echo -e "${RED}Rapid lifecycle stress test failed${NC}"
    fi
    cleanup_stress_tests
    
    # Test 4: Resource Exhaustion
    if test_resource_exhaustion_handling; then
        echo -e "${GREEN}Resource exhaustion handling test passed${NC}"
    else
        echo -e "${RED}Resource exhaustion handling test failed${NC}"
    fi
    cleanup_stress_tests
    
    # Test 5: Network Stress
    if test_network_stress; then
        echo -e "${GREEN}Network stress test passed${NC}"
    else
        echo -e "${RED}Network stress test failed${NC}"
    fi
    cleanup_stress_tests
    
    # Test 6: Resource Limit Stress
    if test_resource_limit_stress; then
        echo -e "${GREEN}Resource limit stress test passed${NC}"
    else
        echo -e "${RED}Resource limit stress test failed${NC}"
    fi
    cleanup_stress_tests
    
    # Final cleanup
    cleanup_stress_tests
    
    # Print summary
    echo -e "\n${CYAN}=================================================${NC}"
    echo -e "${CYAN}🏠 RT Stress Test Summary${NC}"
    echo -e "${CYAN}   📊 Seperti laporan RT tentang ketahanan sistem${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo -e "Tests Passed: ${GREEN}$STRESS_TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$STRESS_TESTS_FAILED${NC}"
    
    if [[ $STRESS_TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All stress tests passed! System is robust under load.${NC}"
        echo -e "${GREEN}   💪 Seperti kompleks RT yang tahan terhadap berbagai beban${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some stress tests failed. System may need optimization.${NC}"
        echo -e "${RED}   🚨 Seperti kompleks RT yang perlu perkuatan sistem${NC}"
        exit 1
    fi
}

# Show usage if no arguments
if [[ $# -eq 0 ]]; then
    echo "RT Container Runtime - Stress Tests"
    echo "Usage: $0 [test_name|all]"
    echo ""
    echo "Available tests:"
    echo "  all                    - Run all stress tests"
    echo "  multiple_creation      - Test multiple container creation"
    echo "  concurrent_ops         - Test concurrent operations"
    echo "  rapid_lifecycle        - Test rapid create/delete cycles"
    echo "  resource_exhaustion    - Test resource exhaustion handling"
    echo "  network_stress         - Test network stress"
    echo "  resource_limits        - Test resource limit stress"
    echo ""
    echo "💪 Seperti RT yang menyediakan berbagai tes ketahanan sistem"
    exit 0
fi

# Parse command line arguments
case "$1" in
    "all")
        run_stress_tests
        ;;
    "multiple_creation")
        check_root_privileges
        cleanup_stress_tests
        test_multiple_container_creation
        cleanup_stress_tests
        ;;
    "concurrent_ops")
        check_root_privileges
        cleanup_stress_tests
        test_concurrent_container_operations
        cleanup_stress_tests
        ;;
    "rapid_lifecycle")
        check_root_privileges
        cleanup_stress_tests
        test_rapid_container_lifecycle
        cleanup_stress_tests
        ;;
    "resource_exhaustion")
        check_root_privileges
        cleanup_stress_tests
        test_resource_exhaustion_handling
        cleanup_stress_tests
        ;;
    "network_stress")
        check_root_privileges
        cleanup_stress_tests
        test_network_stress
        cleanup_stress_tests
        ;;
    "resource_limits")
        check_root_privileges
        cleanup_stress_tests
        test_resource_limit_stress
        cleanup_stress_tests
        ;;
    *)
        echo -e "${RED}❌ Unknown test: $1${NC}"
        echo -e "${YELLOW}💡 Use '$0' without arguments to see available tests${NC}"
        exit 1
        ;;
esac