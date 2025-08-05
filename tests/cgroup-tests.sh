#!/bin/bash

# RT Container Runtime - Cgroup Resource Management Tests
# Educational test suite for cgroup functionality with RT housing analogies
# Author: Container Learning Project
# Version: 1.0

set -euo pipefail

# Test configuration
readonly TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RT_SCRIPT="$TEST_SCRIPT_DIR/../rt.sh"
readonly TEST_CONTAINER_NAME="test-cgroup-container"
readonly CGROUP_ROOT="/sys/fs/cgroup"

# Colors for test output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# TEST UTILITY FUNCTIONS
# =============================================================================

# Test logging functions
log_test_start() {
    local test_name=$1
    echo -e "\n${COLOR_BLUE}🧪 Testing: $test_name${COLOR_RESET}"
    echo -e "${COLOR_BLUE}   🏠 Seperti RT yang menguji sistem rumah baru${COLOR_RESET}"
    ((TESTS_RUN++))
}

log_test_pass() {
    local test_name=$1
    echo -e "${COLOR_GREEN}✅ PASS: $test_name${COLOR_RESET}"
    echo -e "${COLOR_GREEN}   🎉 Seperti sistem rumah yang berfungsi dengan baik${COLOR_RESET}"
    ((TESTS_PASSED++))
}

log_test_fail() {
    local test_name=$1
    local error_msg=$2
    echo -e "${COLOR_RED}❌ FAIL: $test_name${COLOR_RESET}"
    echo -e "${COLOR_RED}   💥 Error: $error_msg${COLOR_RESET}"
    echo -e "${COLOR_RED}   🚨 Seperti sistem rumah yang bermasalah${COLOR_RESET}"
    ((TESTS_FAILED++))
}

log_test_skip() {
    local test_name=$1
    local reason=$2
    echo -e "${COLOR_YELLOW}⏭️  SKIP: $test_name${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   📝 Reason: $reason${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   🏗️  Seperti rumah yang belum siap untuk dites${COLOR_RESET}"
}

# Check if running as root
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${COLOR_RED}❌ These tests require root privileges for cgroup operations${COLOR_RESET}"
        echo -e "${COLOR_RED}   🔑 Seperti RT memerlukan wewenang khusus untuk mengatur kompleks${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   💡 Please run with: sudo $0${COLOR_RESET}"
        exit 1
    fi
}

# Check if cgroups are available
check_cgroup_availability() {
    if [[ ! -d "$CGROUP_ROOT" ]]; then
        echo -e "${COLOR_RED}❌ Cgroups not available on this system${COLOR_RESET}"
        echo -e "${COLOR_RED}   🏗️  Seperti kompleks yang belum punya sistem pembatasan${COLOR_RESET}"
        exit 1
    fi
    
    if [[ ! -d "$CGROUP_ROOT/memory" ]] || [[ ! -d "$CGROUP_ROOT/cpu" ]]; then
        echo -e "${COLOR_RED}❌ Memory or CPU cgroups not available${COLOR_RESET}"
        echo -e "${COLOR_RED}   ⚡ Seperti meteran listrik atau pembagi waktu belum terpasang${COLOR_RESET}"
        exit 1
    fi
}

# Source RT script functions
source_rt_functions() {
    if [[ ! -f "$RT_SCRIPT" ]]; then
        echo -e "${COLOR_RED}❌ RT script not found: $RT_SCRIPT${COLOR_RESET}"
        exit 1
    fi
    
    # Source the RT script to get access to functions
    source "$RT_SCRIPT"
}

# Cleanup test environment
cleanup_test_environment() {
    echo -e "\n${COLOR_CYAN}🧹 Cleaning up test environment${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   🏠 Seperti RT yang membersihkan rumah setelah tes${COLOR_RESET}"
    
    # Cleanup test container cgroups if they exist
    if [[ -d "$CGROUP_ROOT/memory/container-$TEST_CONTAINER_NAME" ]]; then
        echo "Cleaning up memory cgroup..."
        cleanup_container_cgroups "$TEST_CONTAINER_NAME" 2>/dev/null || true
    fi
    
    # Remove test container directory if it exists
    if [[ -d "/tmp/containers/$TEST_CONTAINER_NAME" ]]; then
        echo "Removing test container directory..."
        rm -rf "/tmp/containers/$TEST_CONTAINER_NAME" 2>/dev/null || true
    fi
}

# =============================================================================
# CGROUP STRUCTURE TESTS
# =============================================================================

test_create_cgroup_structure() {
    log_test_start "Create Cgroup Structure"
    
    local memory_mb=256
    local cpu_percent=25
    
    # Test cgroup structure creation
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "$memory_mb" "$cpu_percent"; then
        # Verify memory cgroup was created
        local memory_cgroup="$CGROUP_ROOT/memory/container-$TEST_CONTAINER_NAME"
        if [[ -d "$memory_cgroup" ]]; then
            # Verify CPU cgroup was created
            local cpu_cgroup="$CGROUP_ROOT/cpu/container-$TEST_CONTAINER_NAME"
            if [[ -d "$cpu_cgroup" ]]; then
                # Verify configuration file was created
                local config_file="/tmp/containers/$TEST_CONTAINER_NAME/cgroups/paths.conf"
                if [[ -f "$config_file" ]]; then
                    log_test_pass "Create Cgroup Structure"
                else
                    log_test_fail "Create Cgroup Structure" "Configuration file not created"
                fi
            else
                log_test_fail "Create Cgroup Structure" "CPU cgroup directory not created"
            fi
        else
            log_test_fail "Create Cgroup Structure" "Memory cgroup directory not created"
        fi
    else
        log_test_fail "Create Cgroup Structure" "Function returned error"
    fi
}

test_create_cgroup_structure_invalid_params() {
    log_test_start "Create Cgroup Structure with Invalid Parameters"
    
    # Test with invalid memory limit
    if ! create_cgroup_structure "$TEST_CONTAINER_NAME-invalid" "32" "50" 2>/dev/null; then
        # Test with invalid CPU percentage
        if ! create_cgroup_structure "$TEST_CONTAINER_NAME-invalid2" "256" "150" 2>/dev/null; then
            log_test_pass "Create Cgroup Structure with Invalid Parameters"
        else
            log_test_fail "Create Cgroup Structure with Invalid Parameters" "Invalid CPU percentage accepted"
        fi
    else
        log_test_fail "Create Cgroup Structure with Invalid Parameters" "Invalid memory limit accepted"
    fi
}

# =============================================================================
# MEMORY LIMIT TESTS
# =============================================================================

test_set_memory_limit() {
    log_test_start "Set Memory Limit"
    
    local memory_mb=512
    
    # First create the cgroup structure
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "$memory_mb" "50"; then
        # Test setting memory limit
        if set_memory_limit "$TEST_CONTAINER_NAME" "$memory_mb"; then
            # Verify the limit was set correctly
            local memory_cgroup="$CGROUP_ROOT/memory/container-$TEST_CONTAINER_NAME"
            local limit_file="$memory_cgroup/memory.limit_in_bytes"
            
            if [[ -f "$limit_file" ]]; then
                local actual_limit
                actual_limit=$(cat "$limit_file")
                local expected_limit=$((memory_mb * 1024 * 1024))
                
                # Allow some tolerance for kernel adjustments
                if [[ $actual_limit -ge $expected_limit ]] && [[ $actual_limit -le $((expected_limit + 4096)) ]]; then
                    log_test_pass "Set Memory Limit"
                else
                    log_test_fail "Set Memory Limit" "Limit mismatch: expected ~$expected_limit, got $actual_limit"
                fi
            else
                log_test_fail "Set Memory Limit" "Limit file not found"
            fi
        else
            log_test_fail "Set Memory Limit" "Function returned error"
        fi
    else
        log_test_fail "Set Memory Limit" "Failed to create cgroup structure"
    fi
}

test_set_memory_limit_invalid() {
    log_test_start "Set Memory Limit with Invalid Values"
    
    # Create cgroup structure first
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "256" "50"; then
        # Test with invalid memory values
        if ! set_memory_limit "$TEST_CONTAINER_NAME" "32" 2>/dev/null; then  # Too low
            if ! set_memory_limit "$TEST_CONTAINER_NAME" "10000" 2>/dev/null; then  # Too high
                if ! set_memory_limit "$TEST_CONTAINER_NAME" "abc" 2>/dev/null; then  # Non-numeric
                    log_test_pass "Set Memory Limit with Invalid Values"
                else
                    log_test_fail "Set Memory Limit with Invalid Values" "Non-numeric value accepted"
                fi
            else
                log_test_fail "Set Memory Limit with Invalid Values" "Too high value accepted"
            fi
        else
            log_test_fail "Set Memory Limit with Invalid Values" "Too low value accepted"
        fi
    else
        log_test_skip "Set Memory Limit with Invalid Values" "Failed to create cgroup structure"
    fi
}

# =============================================================================
# CPU LIMIT TESTS
# =============================================================================

test_set_cpu_limit() {
    log_test_start "Set CPU Limit"
    
    local cpu_percent=30
    
    # First create the cgroup structure
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "256" "$cpu_percent"; then
        # Test setting CPU limit
        if set_cpu_limit "$TEST_CONTAINER_NAME" "$cpu_percent"; then
            # Verify the limit was set correctly
            local cpu_cgroup="$CGROUP_ROOT/cpu/container-$TEST_CONTAINER_NAME"
            local quota_file="$cpu_cgroup/cpu.cfs_quota_us"
            local period_file="$cpu_cgroup/cpu.cfs_period_us"
            
            if [[ -f "$quota_file" ]] && [[ -f "$period_file" ]]; then
                local actual_quota actual_period
                actual_quota=$(cat "$quota_file")
                actual_period=$(cat "$period_file")
                
                local expected_quota=$((actual_period * cpu_percent / 100))
                
                if [[ $actual_quota -eq $expected_quota ]]; then
                    log_test_pass "Set CPU Limit"
                else
                    log_test_fail "Set CPU Limit" "Quota mismatch: expected $expected_quota, got $actual_quota"
                fi
            else
                log_test_fail "Set CPU Limit" "CFS files not found"
            fi
        else
            log_test_fail "Set CPU Limit" "Function returned error"
        fi
    else
        log_test_fail "Set CPU Limit" "Failed to create cgroup structure"
    fi
}

test_set_cpu_limit_invalid() {
    log_test_start "Set CPU Limit with Invalid Values"
    
    # Create cgroup structure first
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "256" "50"; then
        # Test with invalid CPU values
        if ! set_cpu_limit "$TEST_CONTAINER_NAME" "0" 2>/dev/null; then  # Too low
            if ! set_cpu_limit "$TEST_CONTAINER_NAME" "150" 2>/dev/null; then  # Too high
                if ! set_cpu_limit "$TEST_CONTAINER_NAME" "xyz" 2>/dev/null; then  # Non-numeric
                    log_test_pass "Set CPU Limit with Invalid Values"
                else
                    log_test_fail "Set CPU Limit with Invalid Values" "Non-numeric value accepted"
                fi
            else
                log_test_fail "Set CPU Limit with Invalid Values" "Too high value accepted"
            fi
        else
            log_test_fail "Set CPU Limit with Invalid Values" "Too low value accepted"
        fi
    else
        log_test_skip "Set CPU Limit with Invalid Values" "Failed to create cgroup structure"
    fi
}

# =============================================================================
# PROCESS ASSIGNMENT TESTS
# =============================================================================

test_assign_process_to_cgroups() {
    log_test_start "Assign Process to Cgroups"
    
    # Create cgroup structure first
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "256" "50"; then
        if set_memory_limit "$TEST_CONTAINER_NAME" "256" && set_cpu_limit "$TEST_CONTAINER_NAME" "50"; then
            # Start a test process (sleep in background)
            sleep 30 &
            local test_pid=$!
            
            # Test assigning the process to cgroups
            if assign_process_to_cgroups "$TEST_CONTAINER_NAME" "$test_pid"; then
                # Verify the process was assigned to memory cgroup
                local memory_cgroup="$CGROUP_ROOT/memory/container-$TEST_CONTAINER_NAME"
                local cpu_cgroup="$CGROUP_ROOT/cpu/container-$TEST_CONTAINER_NAME"
                
                local memory_procs cpu_procs
                memory_procs=$(cat "$memory_cgroup/cgroup.procs" 2>/dev/null | grep "^$test_pid$" || true)
                cpu_procs=$(cat "$cpu_cgroup/cgroup.procs" 2>/dev/null | grep "^$test_pid$" || true)
                
                if [[ -n "$memory_procs" ]] && [[ -n "$cpu_procs" ]]; then
                    log_test_pass "Assign Process to Cgroups"
                else
                    log_test_fail "Assign Process to Cgroups" "Process not found in cgroup.procs files"
                fi
            else
                log_test_fail "Assign Process to Cgroups" "Function returned error"
            fi
            
            # Cleanup test process
            kill "$test_pid" 2>/dev/null || true
            wait "$test_pid" 2>/dev/null || true
        else
            log_test_skip "Assign Process to Cgroups" "Failed to set limits"
        fi
    else
        log_test_skip "Assign Process to Cgroups" "Failed to create cgroup structure"
    fi
}

test_assign_invalid_process() {
    log_test_start "Assign Invalid Process to Cgroups"
    
    # Create cgroup structure first
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "256" "50"; then
        # Test with invalid PID
        if ! assign_process_to_cgroups "$TEST_CONTAINER_NAME" "99999" 2>/dev/null; then
            if ! assign_process_to_cgroups "$TEST_CONTAINER_NAME" "abc" 2>/dev/null; then
                if ! assign_process_to_cgroups "$TEST_CONTAINER_NAME" "-1" 2>/dev/null; then
                    log_test_pass "Assign Invalid Process to Cgroups"
                else
                    log_test_fail "Assign Invalid Process to Cgroups" "Negative PID accepted"
                fi
            else
                log_test_fail "Assign Invalid Process to Cgroups" "Non-numeric PID accepted"
            fi
        else
            log_test_fail "Assign Invalid Process to Cgroups" "Non-existent PID accepted"
        fi
    else
        log_test_skip "Assign Invalid Process to Cgroups" "Failed to create cgroup structure"
    fi
}

# =============================================================================
# RESOURCE USAGE REPORTING TESTS
# =============================================================================

test_get_container_resource_usage() {
    log_test_start "Get Container Resource Usage"
    
    # Create cgroup structure and set limits
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "256" "50"; then
        if set_memory_limit "$TEST_CONTAINER_NAME" "256" && set_cpu_limit "$TEST_CONTAINER_NAME" "50"; then
            # Test getting resource usage
            if get_container_resource_usage "$TEST_CONTAINER_NAME" >/dev/null 2>&1; then
                log_test_pass "Get Container Resource Usage"
            else
                log_test_fail "Get Container Resource Usage" "Function returned error"
            fi
        else
            log_test_skip "Get Container Resource Usage" "Failed to set limits"
        fi
    else
        log_test_skip "Get Container Resource Usage" "Failed to create cgroup structure"
    fi
}

test_get_resource_usage_nonexistent() {
    log_test_start "Get Resource Usage for Nonexistent Container"
    
    # Test with non-existent container
    if ! get_container_resource_usage "nonexistent-container" >/dev/null 2>&1; then
        log_test_pass "Get Resource Usage for Nonexistent Container"
    else
        log_test_fail "Get Resource Usage for Nonexistent Container" "Function should have failed"
    fi
}

# =============================================================================
# CLEANUP TESTS
# =============================================================================

test_cleanup_container_cgroups() {
    log_test_start "Cleanup Container Cgroups"
    
    # Create cgroup structure first
    if create_cgroup_structure "$TEST_CONTAINER_NAME" "256" "50"; then
        if set_memory_limit "$TEST_CONTAINER_NAME" "256" && set_cpu_limit "$TEST_CONTAINER_NAME" "50"; then
            # Start a test process and assign it
            sleep 10 &
            local test_pid=$!
            assign_process_to_cgroups "$TEST_CONTAINER_NAME" "$test_pid" 2>/dev/null || true
            
            # Test cleanup
            if cleanup_container_cgroups "$TEST_CONTAINER_NAME"; then
                # Verify cgroups were removed
                local memory_cgroup="$CGROUP_ROOT/memory/container-$TEST_CONTAINER_NAME"
                local cpu_cgroup="$CGROUP_ROOT/cpu/container-$TEST_CONTAINER_NAME"
                
                if [[ ! -d "$memory_cgroup" ]] && [[ ! -d "$cpu_cgroup" ]]; then
                    log_test_pass "Cleanup Container Cgroups"
                else
                    log_test_fail "Cleanup Container Cgroups" "Cgroup directories still exist"
                fi
            else
                log_test_fail "Cleanup Container Cgroups" "Function returned error"
            fi
            
            # Cleanup test process if still running
            kill "$test_pid" 2>/dev/null || true
            wait "$test_pid" 2>/dev/null || true
        else
            log_test_skip "Cleanup Container Cgroups" "Failed to set limits"
        fi
    else
        log_test_skip "Cleanup Container Cgroups" "Failed to create cgroup structure"
    fi
}

# =============================================================================
# INTEGRATION TESTS
# =============================================================================

test_complete_cgroup_workflow() {
    log_test_start "Complete Cgroup Workflow"
    
    local memory_mb=128
    local cpu_percent=25
    
    # Test complete workflow: create -> set limits -> assign process -> monitor -> cleanup
    if setup_container_cgroups "$TEST_CONTAINER_NAME" "$memory_mb" "$cpu_percent"; then
        # Start a test process
        sleep 15 &
        local test_pid=$!
        
        # Assign process to cgroups
        if assign_process_to_cgroups "$TEST_CONTAINER_NAME" "$test_pid"; then
            # Get resource usage
            if get_container_resource_usage "$TEST_CONTAINER_NAME" >/dev/null 2>&1; then
                # Cleanup
                if cleanup_container_cgroups "$TEST_CONTAINER_NAME"; then
                    log_test_pass "Complete Cgroup Workflow"
                else
                    log_test_fail "Complete Cgroup Workflow" "Cleanup failed"
                fi
            else
                log_test_fail "Complete Cgroup Workflow" "Resource usage reporting failed"
            fi
        else
            log_test_fail "Complete Cgroup Workflow" "Process assignment failed"
        fi
        
        # Cleanup test process
        kill "$test_pid" 2>/dev/null || true
        wait "$test_pid" 2>/dev/null || true
    else
        log_test_fail "Complete Cgroup Workflow" "Setup failed"
    fi
}

# =============================================================================
# TEST RUNNER
# =============================================================================

run_all_tests() {
    echo -e "${COLOR_CYAN}🏠 RT Container Runtime - Cgroup Tests${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   🧪 Seperti RT yang menguji semua sistem pembatasan rumah${COLOR_RESET}"
    echo -e "${COLOR_CYAN}======================================================${COLOR_RESET}"
    
    # Setup
    check_root_privileges
    check_cgroup_availability
    source_rt_functions
    
    # Run structure tests
    echo -e "\n${COLOR_BLUE}📋 CGROUP STRUCTURE TESTS${COLOR_RESET}"
    cleanup_test_environment
    test_create_cgroup_structure
    cleanup_test_environment
    test_create_cgroup_structure_invalid_params
    cleanup_test_environment
    
    # Run memory limit tests
    echo -e "\n${COLOR_BLUE}💡 MEMORY LIMIT TESTS${COLOR_RESET}"
    test_set_memory_limit
    cleanup_test_environment
    test_set_memory_limit_invalid
    cleanup_test_environment
    
    # Run CPU limit tests
    echo -e "\n${COLOR_BLUE}⚡ CPU LIMIT TESTS${COLOR_RESET}"
    test_set_cpu_limit
    cleanup_test_environment
    test_set_cpu_limit_invalid
    cleanup_test_environment
    
    # Run process assignment tests
    echo -e "\n${COLOR_BLUE}👥 PROCESS ASSIGNMENT TESTS${COLOR_RESET}"
    test_assign_process_to_cgroups
    cleanup_test_environment
    test_assign_invalid_process
    cleanup_test_environment
    
    # Run resource usage tests
    echo -e "\n${COLOR_BLUE}📊 RESOURCE USAGE TESTS${COLOR_RESET}"
    test_get_container_resource_usage
    cleanup_test_environment
    test_get_resource_usage_nonexistent
    cleanup_test_environment
    
    # Run cleanup tests
    echo -e "\n${COLOR_BLUE}🧹 CLEANUP TESTS${COLOR_RESET}"
    test_cleanup_container_cgroups
    cleanup_test_environment
    
    # Run integration tests
    echo -e "\n${COLOR_BLUE}🔄 INTEGRATION TESTS${COLOR_RESET}"
    test_complete_cgroup_workflow
    cleanup_test_environment
    
    # Final cleanup
    cleanup_test_environment
    
    # Print summary
    echo -e "\n${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN}🏠 RT Cgroup Test Summary${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   📊 Seperti laporan RT tentang hasil tes sistem rumah${COLOR_RESET}"
    echo -e "${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "Tests Run: $TESTS_RUN"
    echo -e "${COLOR_GREEN}Tests Passed: $TESTS_PASSED${COLOR_RESET}"
    echo -e "${COLOR_RED}Tests Failed: $TESTS_FAILED${COLOR_RESET}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${COLOR_GREEN}🎉 All tests passed! Cgroup system is working correctly.${COLOR_RESET}"
        echo -e "${COLOR_GREEN}   ✅ Seperti semua sistem pembatasan rumah berfungsi sempurna${COLOR_RESET}"
        exit 0
    else
        echo -e "\n${COLOR_RED}❌ Some tests failed. Please check the cgroup implementation.${COLOR_RESET}"
        echo -e "${COLOR_RED}   🚨 Seperti ada sistem rumah yang perlu diperbaiki RT${COLOR_RESET}"
        exit 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Show usage if no arguments
if [[ $# -eq 0 ]]; then
    echo "RT Container Runtime - Cgroup Tests"
    echo "Usage: $0 [test_name|all]"
    echo ""
    echo "Available tests:"
    echo "  all                              - Run all tests"
    echo "  create_structure                 - Test cgroup structure creation"
    echo "  memory_limits                    - Test memory limit functionality"
    echo "  cpu_limits                       - Test CPU limit functionality"
    echo "  process_assignment               - Test process assignment to cgroups"
    echo "  resource_usage                   - Test resource usage reporting"
    echo "  cleanup                          - Test cgroup cleanup"
    echo "  integration                      - Test complete workflow"
    echo ""
    echo "🏠 Seperti RT yang menyediakan berbagai tes untuk sistem rumah"
    exit 0
fi

# Parse command line arguments
case "$1" in
    "all")
        run_all_tests
        ;;
    "create_structure")
        check_root_privileges
        check_cgroup_availability
        source_rt_functions
        cleanup_test_environment
        test_create_cgroup_structure
        test_create_cgroup_structure_invalid_params
        cleanup_test_environment
        ;;
    "memory_limits")
        check_root_privileges
        check_cgroup_availability
        source_rt_functions
        cleanup_test_environment
        test_set_memory_limit
        test_set_memory_limit_invalid
        cleanup_test_environment
        ;;
    "cpu_limits")
        check_root_privileges
        check_cgroup_availability
        source_rt_functions
        cleanup_test_environment
        test_set_cpu_limit
        test_set_cpu_limit_invalid
        cleanup_test_environment
        ;;
    "process_assignment")
        check_root_privileges
        check_cgroup_availability
        source_rt_functions
        cleanup_test_environment
        test_assign_process_to_cgroups
        test_assign_invalid_process
        cleanup_test_environment
        ;;
    "resource_usage")
        check_root_privileges
        check_cgroup_availability
        source_rt_functions
        cleanup_test_environment
        test_get_container_resource_usage
        test_get_resource_usage_nonexistent
        cleanup_test_environment
        ;;
    "cleanup")
        check_root_privileges
        check_cgroup_availability
        source_rt_functions
        cleanup_test_environment
        test_cleanup_container_cgroups
        cleanup_test_environment
        ;;
    "integration")
        check_root_privileges
        check_cgroup_availability
        source_rt_functions
        cleanup_test_environment
        test_complete_cgroup_workflow
        cleanup_test_environment
        ;;
    *)
        echo -e "${COLOR_RED}❌ Unknown test: $1${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}💡 Use '$0' without arguments to see available tests${COLOR_RESET}"
        exit 1
        ;;
esac