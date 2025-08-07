#!/bin/bash

# RT Container Runtime - Resource Validation Tests
# Tests resource limiting validation yang compatible dengan Docker

set -euo pipefail

echo "📊 Running Resource Validation Tests untuk RT Container Runtime"
echo "=============================================================="

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
RESOURCE_TESTS_PASSED=0
RESOURCE_TESTS_FAILED=0

# Test container names
TEST_CONTAINER_MEMORY="resource-memory-test"
TEST_CONTAINER_CPU="resource-cpu-test"
TEST_CONTAINER_COMBINED="resource-combined-test"

# Resource test values
TEST_MEMORY_LIMITS=(64 128 256 512)
TEST_CPU_LIMITS=(10 25 50 75)
INVALID_MEMORY_LIMITS=(32 0 -1 "abc" 10000)
INVALID_CPU_LIMITS=(0 -1 150 "xyz")

# Test helper functions
log_resource_test() {
    local test_name="$1"
    echo -e "\n${BLUE}📊 Resource Test: $test_name${NC}"
    echo -e "${BLUE}   🏠 Seperti RT yang menguji pembatasan sumber daya rumah${NC}"
}

log_resource_pass() {
    local test_name="$1"
    echo -e "${GREEN}✅ PASS: $test_name${NC}"
    echo -e "${GREEN}   🎉 Pembatasan sumber daya berfungsi: $test_name${NC}"
    ((RESOURCE_TESTS_PASSED++))
}

log_resource_fail() {
    local test_name="$1"
    local error="$2"
    echo -e "${RED}❌ FAIL: $test_name${NC}"
    echo -e "${RED}   💥 Error: $error${NC}"
    echo -e "${RED}   🚨 Pembatasan sumber daya bermasalah: $test_name${NC}"
    ((RESOURCE_TESTS_FAILED++))
}

log_resource_skip() {
    local test_name="$1"
    local reason="$2"
    echo -e "${YELLOW}⏭️  SKIP: $test_name${NC}"
    echo -e "${YELLOW}   📝 Reason: $reason${NC}"
}

# Check if running as root
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Resource validation tests require root privileges${NC}"
        echo -e "${RED}   🔑 Seperti RT memerlukan wewenang khusus untuk mengatur sumber daya${NC}"
        echo -e "${YELLOW}   💡 Please run with: sudo $0${NC}"
        exit 1
    fi
}

# Cleanup function
cleanup_resource_tests() {
    echo -e "\n${CYAN}🧹 Cleaning up resource test environment...${NC}"
    
    # Clean up test containers
    "$RT_SCRIPT" delete "$TEST_CONTAINER_MEMORY" 2>/dev/null || true
    "$RT_SCRIPT" delete "$TEST_CONTAINER_CPU" 2>/dev/null || true
    "$RT_SCRIPT" delete "$TEST_CONTAINER_COMBINED" 2>/dev/null || true
    
    # Clean up any leftover test containers
    for memory in "${TEST_MEMORY_LIMITS[@]}"; do
        "$RT_SCRIPT" delete "memory-test-${memory}mb" 2>/dev/null || true
    done
    
    for cpu in "${TEST_CPU_LIMITS[@]}"; do
        "$RT_SCRIPT" delete "cpu-test-${cpu}pct" 2>/dev/null || true
    done
    
    # Emergency cleanup
    "$RT_SCRIPT" cleanup-all 2>/dev/null || true
    
    echo -e "${CYAN}Resource test cleanup completed${NC}"
}

# Set up cleanup trap
trap cleanup_resource_tests EXIT

# Resource Test 1: Memory Limit Validation
test_memory_limit_validation() {
    log_resource_test "Memory Limit Validation"
    
    local success_count=0
    local total_tests=${#TEST_MEMORY_LIMITS[@]}
    
    echo -e "${CYAN}Testing valid memory limits: ${TEST_MEMORY_LIMITS[*]}MB${NC}"
    
    for memory_mb in "${TEST_MEMORY_LIMITS[@]}"; do
        local container_name="memory-test-${memory_mb}mb"
        echo -e "${YELLOW}Testing ${memory_mb}MB memory limit...${NC}"
        
        if timeout 60 "$RT_SCRIPT" create "$container_name" \
           --ram="$memory_mb" --cpu=25 2>/dev/null; then
            
            # Verify memory cgroup was created and configured
            local memory_cgroup="/sys/fs/cgroup/memory/container-$container_name"
            if [[ -d "$memory_cgroup" ]]; then
                local limit_file="$memory_cgroup/memory.limit_in_bytes"
                if [[ -f "$limit_file" ]]; then
                    local actual_limit=$(cat "$limit_file")
                    local expected_limit=$((memory_mb * 1024 * 1024))
                    
                    # Allow some tolerance for kernel adjustments
                    if [[ $actual_limit -ge $expected_limit ]] && \
                       [[ $actual_limit -le $((expected_limit + 4096)) ]]; then
                        echo -e "${GREEN}  ✅ ${memory_mb}MB limit set correctly${NC}"
                        ((success_count++))
                    else
                        echo -e "${RED}  ❌ ${memory_mb}MB limit incorrect: expected ~$expected_limit, got $actual_limit${NC}"
                    fi
                else
                    echo -e "${RED}  ❌ Memory limit file not found for ${memory_mb}MB${NC}"
                fi
            else
                echo -e "${RED}  ❌ Memory cgroup not created for ${memory_mb}MB${NC}"
            fi
            
            # Cleanup
            "$RT_SCRIPT" delete "$container_name" 2>/dev/null || true
        else
            echo -e "${RED}  ❌ Failed to create container with ${memory_mb}MB limit${NC}"
        fi
    done
    
    echo -e "${CYAN}Memory limit validation: $success_count/$total_tests successful${NC}"
    
    if [[ $success_count -eq $total_tests ]]; then
        log_resource_pass "Memory Limit Validation"
        return 0
    else
        log_resource_fail "Memory Limit Validation" "Only $success_count/$total_tests memory limits validated successfully"
        return 1
    fi
}

# Resource Test 2: CPU Limit Validation
test_cpu_limit_validation() {
    log_resource_test "CPU Limit Validation"
    
    local success_count=0
    local total_tests=${#TEST_CPU_LIMITS[@]}
    
    echo -e "${CYAN}Testing valid CPU limits: ${TEST_CPU_LIMITS[*]}%${NC}"
    
    for cpu_percent in "${TEST_CPU_LIMITS[@]}"; do
        local container_name="cpu-test-${cpu_percent}pct"
        echo -e "${YELLOW}Testing ${cpu_percent}% CPU limit...${NC}"
        
        if timeout 60 "$RT_SCRIPT" create "$container_name" \
           --ram=128 --cpu="$cpu_percent" 2>/dev/null; then
            
            # Verify CPU cgroup was created and configured
            local cpu_cgroup="/sys/fs/cgroup/cpu/container-$container_name"
            if [[ -d "$cpu_cgroup" ]]; then
                local quota_file="$cpu_cgroup/cpu.cfs_quota_us"
                local period_file="$cpu_cgroup/cpu.cfs_period_us"
                
                if [[ -f "$quota_file" ]] && [[ -f "$period_file" ]]; then
                    local actual_quota=$(cat "$quota_file")
                    local actual_period=$(cat "$period_file")
                    local expected_quota=$((actual_period * cpu_percent / 100))
                    
                    if [[ $actual_quota -eq $expected_quota ]]; then
                        echo -e "${GREEN}  ✅ ${cpu_percent}% CPU limit set correctly${NC}"
                        ((success_count++))
                    else
                        echo -e "${RED}  ❌ ${cpu_percent}% CPU limit incorrect: expected $expected_quota, got $actual_quota${NC}"
                    fi
                else
                    echo -e "${RED}  ❌ CPU CFS files not found for ${cpu_percent}%${NC}"
                fi
            else
                echo -e "${RED}  ❌ CPU cgroup not created for ${cpu_percent}%${NC}"
            fi
            
            # Cleanup
            "$RT_SCRIPT" delete "$container_name" 2>/dev/null || true
        else
            echo -e "${RED}  ❌ Failed to create container with ${cpu_percent}% CPU limit${NC}"
        fi
    done
    
    echo -e "${CYAN}CPU limit validation: $success_count/$total_tests successful${NC}"
    
    if [[ $success_count -eq $total_tests ]]; then
        log_resource_pass "CPU Limit Validation"
        return 0
    else
        log_resource_fail "CPU Limit Validation" "Only $success_count/$total_tests CPU limits validated successfully"
        return 1
    fi
}

# Resource Test 3: Invalid Memory Limit Rejection
test_invalid_memory_limit_rejection() {
    log_resource_test "Invalid Memory Limit Rejection"
    
    local rejection_count=0
    local total_tests=${#INVALID_MEMORY_LIMITS[@]}
    
    echo -e "${CYAN}Testing invalid memory limits: ${INVALID_MEMORY_LIMITS[*]}${NC}"
    
    for invalid_memory in "${INVALID_MEMORY_LIMITS[@]}"; do
        local container_name="invalid-memory-test-$$"
        echo -e "${YELLOW}Testing invalid memory limit: $invalid_memory${NC}"
        
        if ! timeout 30 "$RT_SCRIPT" create "$container_name" \
           --ram="$invalid_memory" --cpu=25 2>/dev/null; then
            echo -e "${GREEN}  ✅ Invalid memory limit '$invalid_memory' properly rejected${NC}"
            ((rejection_count++))
        else
            echo -e "${RED}  ❌ Invalid memory limit '$invalid_memory' was accepted${NC}"
            # Cleanup if container was created
            "$RT_SCRIPT" delete "$container_name" 2>/dev/null || true
        fi
    done
    
    echo -e "${CYAN}Invalid memory rejection: $rejection_count/$total_tests properly rejected${NC}"
    
    if [[ $rejection_count -eq $total_tests ]]; then
        log_resource_pass "Invalid Memory Limit Rejection"
        return 0
    else
        log_resource_fail "Invalid Memory Limit Rejection" "Only $rejection_count/$total_tests invalid limits were rejected"
        return 1
    fi
}

# Resource Test 4: Invalid CPU Limit Rejection
test_invalid_cpu_limit_rejection() {
    log_resource_test "Invalid CPU Limit Rejection"
    
    local rejection_count=0
    local total_tests=${#INVALID_CPU_LIMITS[@]}
    
    echo -e "${CYAN}Testing invalid CPU limits: ${INVALID_CPU_LIMITS[*]}${NC}"
    
    for invalid_cpu in "${INVALID_CPU_LIMITS[@]}"; do
        local container_name="invalid-cpu-test-$$"
        echo -e "${YELLOW}Testing invalid CPU limit: $invalid_cpu${NC}"
        
        if ! timeout 30 "$RT_SCRIPT" create "$container_name" \
           --ram=128 --cpu="$invalid_cpu" 2>/dev/null; then
            echo -e "${GREEN}  ✅ Invalid CPU limit '$invalid_cpu' properly rejected${NC}"
            ((rejection_count++))
        else
            echo -e "${RED}  ❌ Invalid CPU limit '$invalid_cpu' was accepted${NC}"
            # Cleanup if container was created
            "$RT_SCRIPT" delete "$container_name" 2>/dev/null || true
        fi
    done
    
    echo -e "${CYAN}Invalid CPU rejection: $rejection_count/$total_tests properly rejected${NC}"
    
    if [[ $rejection_count -eq $total_tests ]]; then
        log_resource_pass "Invalid CPU Limit Rejection"
        return 0
    else
        log_resource_fail "Invalid CPU Limit Rejection" "Only $rejection_count/$total_tests invalid limits were rejected"
        return 1
    fi
}

# Resource Test 5: Combined Resource Limits
test_combined_resource_limits() {
    log_resource_test "Combined Resource Limits"
    
    local test_combinations=(
        "64:10"
        "128:25"
        "256:50"
        "512:75"
    )
    
    local success_count=0
    local total_tests=${#test_combinations[@]}
    
    echo -e "${CYAN}Testing combined memory:CPU limits${NC}"
    
    for combination in "${test_combinations[@]}"; do
        local memory_mb="${combination%:*}"
        local cpu_percent="${combination#*:}"
        local container_name="combined-test-${memory_mb}mb-${cpu_percent}cpu"
        
        echo -e "${YELLOW}Testing ${memory_mb}MB + ${cpu_percent}% CPU...${NC}"
        
        if timeout 60 "$RT_SCRIPT" create "$container_name" \
           --ram="$memory_mb" --cpu="$cpu_percent" 2>/dev/null; then
            
            # Verify both memory and CPU cgroups
            local memory_cgroup="/sys/fs/cgroup/memory/container-$container_name"
            local cpu_cgroup="/sys/fs/cgroup/cpu/container-$container_name"
            
            local memory_ok=false
            local cpu_ok=false
            
            # Check memory cgroup
            if [[ -d "$memory_cgroup" ]] && [[ -f "$memory_cgroup/memory.limit_in_bytes" ]]; then
                local actual_limit=$(cat "$memory_cgroup/memory.limit_in_bytes")
                local expected_limit=$((memory_mb * 1024 * 1024))
                if [[ $actual_limit -ge $expected_limit ]] && \
                   [[ $actual_limit -le $((expected_limit + 4096)) ]]; then
                    memory_ok=true
                fi
            fi
            
            # Check CPU cgroup
            if [[ -d "$cpu_cgroup" ]] && [[ -f "$cpu_cgroup/cpu.cfs_quota_us" ]] && \
               [[ -f "$cpu_cgroup/cpu.cfs_period_us" ]]; then
                local actual_quota=$(cat "$cpu_cgroup/cpu.cfs_quota_us")
                local actual_period=$(cat "$cpu_cgroup/cpu.cfs_period_us")
                local expected_quota=$((actual_period * cpu_percent / 100))
                if [[ $actual_quota -eq $expected_quota ]]; then
                    cpu_ok=true
                fi
            fi
            
            if [[ "$memory_ok" == "true" ]] && [[ "$cpu_ok" == "true" ]]; then
                echo -e "${GREEN}  ✅ Combined limits ${memory_mb}MB + ${cpu_percent}% set correctly${NC}"
                ((success_count++))
            else
                echo -e "${RED}  ❌ Combined limits not set correctly (memory: $memory_ok, cpu: $cpu_ok)${NC}"
            fi
            
            # Cleanup
            "$RT_SCRIPT" delete "$container_name" 2>/dev/null || true
        else
            echo -e "${RED}  ❌ Failed to create container with combined limits${NC}"
        fi
    done
    
    echo -e "${CYAN}Combined resource limits: $success_count/$total_tests successful${NC}"
    
    if [[ $success_count -eq $total_tests ]]; then
        log_resource_pass "Combined Resource Limits"
        return 0
    else
        log_resource_fail "Combined Resource Limits" "Only $success_count/$total_tests combinations worked correctly"
        return 1
    fi
}

# Resource Test 6: Resource Usage Monitoring
test_resource_usage_monitoring() {
    log_resource_test "Resource Usage Monitoring"
    
    local container_name="monitoring-test"
    
    echo -e "${CYAN}Testing resource usage monitoring capabilities...${NC}"
    
    if timeout 60 "$RT_SCRIPT" create "$container_name" \
       --ram=256 --cpu=25 2>/dev/null; then
        
        # Test if we can get resource usage information
        if "$RT_SCRIPT" show-resources "$container_name" >/dev/null 2>&1; then
            echo -e "${GREEN}  ✅ Resource usage monitoring available${NC}"
            
            # Test if resource information contains expected fields
            local resource_info
            resource_info=$("$RT_SCRIPT" show-resources "$container_name" 2>/dev/null || echo "")
            
            if echo "$resource_info" | grep -q "Memory" && \
               echo "$resource_info" | grep -q "CPU"; then
                echo -e "${GREEN}  ✅ Resource information contains memory and CPU data${NC}"
                
                # Cleanup
                "$RT_SCRIPT" delete "$container_name" 2>/dev/null || true
                
                log_resource_pass "Resource Usage Monitoring"
                return 0
            else
                echo -e "${RED}  ❌ Resource information missing expected fields${NC}"
            fi
        else
            echo -e "${RED}  ❌ Resource usage monitoring not available${NC}"
        fi
        
        # Cleanup
        "$RT_SCRIPT" delete "$container_name" 2>/dev/null || true
    else
        echo -e "${RED}  ❌ Failed to create container for monitoring test${NC}"
    fi
    
    log_resource_fail "Resource Usage Monitoring" "Resource monitoring functionality not working"
    return 1
}

# Resource Test 7: Docker Compatibility Check
test_docker_compatibility() {
    log_resource_test "Docker Compatibility Check"
    
    echo -e "${CYAN}Testing Docker-compatible resource limit format...${NC}"
    
    # Test Docker-style memory format (if supported)
    local container_name="docker-compat-test"
    local docker_style_tests=0
    local docker_style_passed=0
    
    # Test standard format (should work)
    echo -e "${YELLOW}Testing standard format: --ram=128${NC}"
    if timeout 60 "$RT_SCRIPT" create "${container_name}-1" \
       --ram=128 --cpu=25 2>/dev/null; then
        echo -e "${GREEN}  ✅ Standard format works${NC}"
        ((docker_style_tests++))
        ((docker_style_passed++))
        "$RT_SCRIPT" delete "${container_name}-1" 2>/dev/null || true
    else
        echo -e "${RED}  ❌ Standard format failed${NC}"
        ((docker_style_tests++))
    fi
    
    # Test memory format compatibility
    echo -e "${YELLOW}Testing memory format compatibility...${NC}"
    if timeout 60 "$RT_SCRIPT" create "${container_name}-2" \
       --memory=128 --cpu=25 2>/dev/null; then
        echo -e "${GREEN}  ✅ --memory format works${NC}"
        ((docker_style_tests++))
        ((docker_style_passed++))
        "$RT_SCRIPT" delete "${container_name}-2" 2>/dev/null || true
    else
        echo -e "${YELLOW}  ⚠️  --memory format not supported (expected)${NC}"
        ((docker_style_tests++))
    fi
    
    echo -e "${CYAN}Docker compatibility: $docker_style_passed/$docker_style_tests formats supported${NC}"
    
    if [[ $docker_style_passed -ge 1 ]]; then
        log_resource_pass "Docker Compatibility Check"
        return 0
    else
        log_resource_fail "Docker Compatibility Check" "No compatible formats working"
        return 1
    fi
}

# Main resource validation test execution
run_resource_validation_tests() {
    echo -e "${CYAN}🏠 RT Container Runtime - Resource Validation Tests${NC}"
    echo -e "${CYAN}   📊 Seperti RT yang menguji sistem pembatasan sumber daya kompleks${NC}"
    echo -e "${CYAN}=============================================================${NC}"
    
    # Check prerequisites
    check_root_privileges
    
    # Initial cleanup
    cleanup_resource_tests
    
    echo -e "\n${BLUE}📋 RESOURCE VALIDATION TEST CONFIGURATION${NC}"
    echo -e "Valid Memory Limits: ${TEST_MEMORY_LIMITS[*]}MB"
    echo -e "Valid CPU Limits: ${TEST_CPU_LIMITS[*]}%"
    echo -e "Invalid Memory Limits: ${INVALID_MEMORY_LIMITS[*]}"
    echo -e "Invalid CPU Limits: ${INVALID_CPU_LIMITS[*]}"
    
    # Run resource validation tests
    echo -e "\n${BLUE}📊 RUNNING RESOURCE VALIDATION TESTS${NC}"
    
    # Test 1: Memory Limit Validation
    if test_memory_limit_validation; then
        echo -e "${GREEN}Memory limit validation test passed${NC}"
    else
        echo -e "${RED}Memory limit validation test failed${NC}"
    fi
    cleanup_resource_tests
    
    # Test 2: CPU Limit Validation
    if test_cpu_limit_validation; then
        echo -e "${GREEN}CPU limit validation test passed${NC}"
    else
        echo -e "${RED}CPU limit validation test failed${NC}"
    fi
    cleanup_resource_tests
    
    # Test 3: Invalid Memory Limit Rejection
    if test_invalid_memory_limit_rejection; then
        echo -e "${GREEN}Invalid memory limit rejection test passed${NC}"
    else
        echo -e "${RED}Invalid memory limit rejection test failed${NC}"
    fi
    cleanup_resource_tests
    
    # Test 4: Invalid CPU Limit Rejection
    if test_invalid_cpu_limit_rejection; then
        echo -e "${GREEN}Invalid CPU limit rejection test passed${NC}"
    else
        echo -e "${RED}Invalid CPU limit rejection test failed${NC}"
    fi
    cleanup_resource_tests
    
    # Test 5: Combined Resource Limits
    if test_combined_resource_limits; then
        echo -e "${GREEN}Combined resource limits test passed${NC}"
    else
        echo -e "${RED}Combined resource limits test failed${NC}"
    fi
    cleanup_resource_tests
    
    # Test 6: Resource Usage Monitoring
    if test_resource_usage_monitoring; then
        echo -e "${GREEN}Resource usage monitoring test passed${NC}"
    else
        echo -e "${RED}Resource usage monitoring test failed${NC}"
    fi
    cleanup_resource_tests
    
    # Test 7: Docker Compatibility
    if test_docker_compatibility; then
        echo -e "${GREEN}Docker compatibility test passed${NC}"
    else
        echo -e "${RED}Docker compatibility test failed${NC}"
    fi
    cleanup_resource_tests
    
    # Final cleanup
    cleanup_resource_tests
    
    # Print summary
    echo -e "\n${CYAN}=============================================================${NC}"
    echo -e "${CYAN}🏠 RT Resource Validation Test Summary${NC}"
    echo -e "${CYAN}   📊 Seperti laporan RT tentang sistem pembatasan sumber daya${NC}"
    echo -e "${CYAN}=============================================================${NC}"
    echo -e "Tests Passed: ${GREEN}$RESOURCE_TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$RESOURCE_TESTS_FAILED${NC}"
    
    if [[ $RESOURCE_TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All resource validation tests passed!${NC}"
        echo -e "${GREEN}   📊 Seperti sistem pembatasan RT yang berfungsi sempurna${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some resource validation tests failed.${NC}"
        echo -e "${RED}   🚨 Seperti sistem pembatasan RT yang perlu diperbaiki${NC}"
        exit 1
    fi
}

# Show usage if no arguments
if [[ $# -eq 0 ]]; then
    echo "RT Container Runtime - Resource Validation Tests"
    echo "Usage: $0 [test_name|all]"
    echo ""
    echo "Available tests:"
    echo "  all                    - Run all resource validation tests"
    echo "  memory_validation      - Test memory limit validation"
    echo "  cpu_validation         - Test CPU limit validation"
    echo "  invalid_memory         - Test invalid memory limit rejection"
    echo "  invalid_cpu            - Test invalid CPU limit rejection"
    echo "  combined_limits        - Test combined resource limits"
    echo "  usage_monitoring       - Test resource usage monitoring"
    echo "  docker_compatibility   - Test Docker compatibility"
    echo ""
    echo "📊 Seperti RT yang menyediakan berbagai tes pembatasan sumber daya"
    exit 0
fi

# Parse command line arguments
case "$1" in
    "all")
        run_resource_validation_tests
        ;;
    "memory_validation")
        check_root_privileges
        cleanup_resource_tests
        test_memory_limit_validation
        cleanup_resource_tests
        ;;
    "cpu_validation")
        check_root_privileges
        cleanup_resource_tests
        test_cpu_limit_validation
        cleanup_resource_tests
        ;;
    "invalid_memory")
        check_root_privileges
        cleanup_resource_tests
        test_invalid_memory_limit_rejection
        cleanup_resource_tests
        ;;
    "invalid_cpu")
        check_root_privileges
        cleanup_resource_tests
        test_invalid_cpu_limit_rejection
        cleanup_resource_tests
        ;;
    "combined_limits")
        check_root_privileges
        cleanup_resource_tests
        test_combined_resource_limits
        cleanup_resource_tests
        ;;
    "usage_monitoring")
        check_root_privileges
        cleanup_resource_tests
        test_resource_usage_monitoring
        cleanup_resource_tests
        ;;
    "docker_compatibility")
        check_root_privileges
        cleanup_resource_tests
        test_docker_compatibility
        cleanup_resource_tests
        ;;
    *)
        echo -e "${RED}❌ Unknown test: $1${NC}"
        echo -e "${YELLOW}💡 Use '$0' without arguments to see available tests${NC}"
        exit 1
        ;;
esac