#!/bin/bash

# Namespace Management System Tests
# Tests for RT Container Runtime namespace functionality

set -euo pipefail

# Source the main script to access functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../rt.sh"

# Test configuration
readonly TEST_CONTAINER_NAME="test-namespace-container"
readonly TEST_RESULTS_FILE="/tmp/namespace-test-results.log"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# TEST UTILITIES
# =============================================================================

# Initialize test environment
init_test_environment() {
    echo "=== Initializing Namespace Test Environment ==="
    
    # Clean up any previous test artifacts
    cleanup_test_environment
    
    # Create test directories
    create_directory "$CONTAINERS_DIR"
    create_directory "$(dirname "$TEST_RESULTS_FILE")"
    
    # Redirect logs to test results file
    exec 1> >(tee -a "$TEST_RESULTS_FILE")
    exec 2> >(tee -a "$TEST_RESULTS_FILE" >&2)
    
    echo "Test environment initialized"
    echo "Results will be logged to: $TEST_RESULTS_FILE"
    echo ""
}

# Clean up test environment
cleanup_test_environment() {
    echo "=== Cleaning Up Test Environment ==="
    
    # Remove test container if exists
    if [[ -d "$CONTAINERS_DIR/$TEST_CONTAINER_NAME" ]]; then
        # Clean up namespaces first
        cleanup_container_namespaces "$TEST_CONTAINER_NAME" 2>/dev/null || true
        rm -rf "$CONTAINERS_DIR/$TEST_CONTAINER_NAME"
        echo "Removed test container directory"
    fi
    
    echo "Test environment cleaned up"
    echo ""
}

# Run a test and track results
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo "--- Running Test: $test_name ---"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if $test_function; then
        echo "✅ PASSED: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAILED: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
}

# Print test summary
print_test_summary() {
    echo "=== Test Summary ==="
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "🎉 All tests passed!"
        return 0
    else
        echo "💥 Some tests failed!"
        return 1
    fi
}

# =============================================================================
# PID NAMESPACE TESTS
# =============================================================================

test_create_pid_namespace_success() {
    echo "Testing PID namespace creation..."
    
    if create_pid_namespace "$TEST_CONTAINER_NAME"; then
        local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
        
        # Check if configuration file was created
        if [[ -f "$ns_dir/pid.conf" ]]; then
            echo "PID namespace configuration created successfully"
            
            # Check configuration content
            source "$ns_dir/pid.conf"
            if [[ "$pid_namespace_enabled" == "true" ]] && \
               [[ "$init_process" == "/bin/busybox" ]] && \
               [[ "$init_args" == "sh" ]]; then
                echo "PID namespace configuration is correct"
                return 0
            else
                echo "PID namespace configuration is incorrect"
                return 1
            fi
        else
            echo "PID namespace configuration file not created"
            return 1
        fi
    else
        echo "PID namespace creation failed"
        return 1
    fi
}

# =============================================================================
# MOUNT NAMESPACE TESTS
# =============================================================================

test_create_mount_namespace_success() {
    echo "Testing mount namespace creation..."
    
    if create_mount_namespace "$TEST_CONTAINER_NAME"; then
        local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
        local container_rootfs="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/rootfs"
        
        # Check if configuration file was created
        if [[ -f "$ns_dir/mount.conf" ]]; then
            echo "Mount namespace configuration created successfully"
            
            # Check if essential directories were created
            local essential_dirs=("proc" "sys" "dev" "dev/pts" "tmp" "var/tmp")
            for dir in "${essential_dirs[@]}"; do
                if [[ ! -d "$container_rootfs/$dir" ]]; then
                    echo "Essential directory missing: $dir"
                    return 1
                fi
            done
            
            # Check configuration content
            source "$ns_dir/mount.conf"
            if [[ "$mount_namespace_enabled" == "true" ]] && \
               [[ "$rootfs_path" == "$container_rootfs" ]]; then
                echo "Mount namespace configuration is correct"
                return 0
            else
                echo "Mount namespace configuration is incorrect"
                return 1
            fi
        else
            echo "Mount namespace configuration file not created"
            return 1
        fi
    else
        echo "Mount namespace creation failed"
        return 1
    fi
}

# =============================================================================
# UTS NAMESPACE TESTS
# =============================================================================

test_create_uts_namespace_success() {
    echo "Testing UTS namespace creation..."
    
    local test_hostname="test-container-host"
    
    if create_uts_namespace "$TEST_CONTAINER_NAME" "$test_hostname"; then
        local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
        local container_rootfs="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/rootfs"
        
        # Check if configuration file was created
        if [[ -f "$ns_dir/uts.conf" ]]; then
            echo "UTS namespace configuration created successfully"
            
            # Check configuration content
            source "$ns_dir/uts.conf"
            if [[ "$uts_namespace_enabled" == "true" ]] && \
               [[ "$hostname" == "$test_hostname" ]] && \
               [[ "$domainname" == "container.local" ]]; then
                echo "UTS namespace configuration is correct"
                
                # Check if hostname file was created
                if [[ -f "$container_rootfs/etc/hostname" ]]; then
                    local file_hostname=$(cat "$container_rootfs/etc/hostname")
                    if [[ "$file_hostname" == "$test_hostname" ]]; then
                        echo "Hostname file created correctly"
                        return 0
                    else
                        echo "Hostname file content incorrect: $file_hostname"
                        return 1
                    fi
                else
                    echo "Hostname file not created"
                    return 1
                fi
            else
                echo "UTS namespace configuration is incorrect"
                return 1
            fi
        else
            echo "UTS namespace configuration file not created"
            return 1
        fi
    else
        echo "UTS namespace creation failed"
        return 1
    fi
}

test_create_uts_namespace_default_hostname() {
    echo "Testing UTS namespace creation with default hostname..."
    
    if create_uts_namespace "$TEST_CONTAINER_NAME"; then
        local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
        
        # Check configuration content
        source "$ns_dir/uts.conf"
        if [[ "$hostname" == "$TEST_CONTAINER_NAME" ]]; then
            echo "Default hostname set correctly"
            return 0
        else
            echo "Default hostname incorrect: $hostname"
            return 1
        fi
    else
        echo "UTS namespace creation with default hostname failed"
        return 1
    fi
}

# =============================================================================
# IPC NAMESPACE TESTS
# =============================================================================

test_create_ipc_namespace_success() {
    echo "Testing IPC namespace creation..."
    
    if create_ipc_namespace "$TEST_CONTAINER_NAME"; then
        local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
        
        # Check if configuration files were created
        if [[ -f "$ns_dir/ipc.conf" ]] && [[ -f "$ns_dir/ipc_limits.conf" ]]; then
            echo "IPC namespace configuration files created successfully"
            
            # Check configuration content
            source "$ns_dir/ipc.conf"
            if [[ "$ipc_namespace_enabled" == "true" ]] && \
               [[ "$shared_memory_max" == "67108864" ]] && \
               [[ "$semaphore_max" == "32000" ]] && \
               [[ "$message_queue_max" == "16" ]]; then
                echo "IPC namespace configuration is correct"
                return 0
            else
                echo "IPC namespace configuration is incorrect"
                return 1
            fi
        else
            echo "IPC namespace configuration files not created"
            return 1
        fi
    else
        echo "IPC namespace creation failed"
        return 1
    fi
}

# =============================================================================
# USER NAMESPACE TESTS
# =============================================================================

test_create_user_namespace_success() {
    echo "Testing user namespace creation..."
    
    local test_uid=1000
    local test_gid=1000
    
    if create_user_namespace "$TEST_CONTAINER_NAME" "$test_uid" "$test_gid"; then
        local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
        local container_rootfs="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/rootfs"
        
        # Check if configuration files were created
        if [[ -f "$ns_dir/user.conf" ]] && [[ -f "$ns_dir/uid_map" ]] && [[ -f "$ns_dir/gid_map" ]]; then
            echo "User namespace configuration files created successfully"
            
            # Check configuration content
            source "$ns_dir/user.conf"
            if [[ "$user_namespace_enabled" == "true" ]] && \
               [[ "$host_uid" == "$test_uid" ]] && \
               [[ "$host_gid" == "$test_gid" ]] && \
               [[ "$container_uid" == "0" ]] && \
               [[ "$container_gid" == "0" ]]; then
                echo "User namespace configuration is correct"
                
                # Check mapping files
                local uid_map_content=$(cat "$ns_dir/uid_map")
                local gid_map_content=$(cat "$ns_dir/gid_map")
                
                if [[ "$uid_map_content" == "0 $test_uid 1" ]] && \
                   [[ "$gid_map_content" == "0 $test_gid 1" ]]; then
                    echo "User mapping files are correct"
                    
                    # Check passwd and group files
                    if [[ -f "$container_rootfs/etc/passwd" ]] && [[ -f "$container_rootfs/etc/group" ]]; then
                        echo "Container passwd and group files created"
                        return 0
                    else
                        echo "Container passwd/group files not created"
                        return 1
                    fi
                else
                    echo "User mapping files are incorrect"
                    return 1
                fi
            else
                echo "User namespace configuration is incorrect"
                return 1
            fi
        else
            echo "User namespace configuration files not created"
            return 1
        fi
    else
        echo "User namespace creation failed"
        return 1
    fi
}

test_create_user_namespace_default_ids() {
    echo "Testing user namespace creation with default IDs..."
    
    if create_user_namespace "$TEST_CONTAINER_NAME"; then
        local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
        
        # Check configuration content
        source "$ns_dir/user.conf"
        local current_uid=$(id -u)
        local current_gid=$(id -g)
        
        if [[ "$host_uid" == "$current_uid" ]] && [[ "$host_gid" == "$current_gid" ]]; then
            echo "Default UID/GID set correctly"
            return 0
        else
            echo "Default UID/GID incorrect: $host_uid/$host_gid vs $current_uid/$current_gid"
            return 1
        fi
    else
        echo "User namespace creation with default IDs failed"
        return 1
    fi
}

# =============================================================================
# COMPLETE NAMESPACE SETUP TESTS
# =============================================================================

test_setup_container_namespaces_success() {
    echo "Testing complete container namespace setup..."
    
    local test_hostname="complete-test-host"
    local test_uid=1001
    local test_gid=1001
    
    if setup_container_namespaces "$TEST_CONTAINER_NAME" "$test_hostname" "$test_uid" "$test_gid"; then
        local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
        
        # Check if all namespace configuration files were created
        local ns_configs=("pid.conf" "mount.conf" "uts.conf" "ipc.conf" "user.conf")
        for config in "${ns_configs[@]}"; do
            if [[ ! -f "$ns_dir/$config" ]]; then
                echo "Namespace configuration missing: $config"
                return 1
            fi
        done
        
        # Check if container is tracked in active namespaces
        if [[ -n "${ACTIVE_NAMESPACES[$TEST_CONTAINER_NAME]:-}" ]]; then
            echo "Container tracked in active namespaces: ${ACTIVE_NAMESPACES[$TEST_CONTAINER_NAME]}"
            return 0
        else
            echo "Container not tracked in active namespaces"
            return 1
        fi
    else
        echo "Complete namespace setup failed"
        return 1
    fi
}

# =============================================================================
# NAMESPACE INFORMATION TESTS
# =============================================================================

test_get_namespace_info_success() {
    echo "Testing namespace information retrieval..."
    
    # Setup namespaces first
    setup_container_namespaces "$TEST_CONTAINER_NAME" || return 1
    
    local info_output
    if info_output=$(get_namespace_info "$TEST_CONTAINER_NAME"); then
        echo "Namespace info retrieved successfully"
        
        # Check if info contains expected sections
        if echo "$info_output" | grep -q "PID Namespace" && \
           echo "$info_output" | grep -q "Mount Namespace" && \
           echo "$info_output" | grep -q "UTS Namespace" && \
           echo "$info_output" | grep -q "IPC Namespace" && \
           echo "$info_output" | grep -q "User Namespace"; then
            echo "Namespace info contains all expected sections"
            return 0
        else
            echo "Namespace info missing expected sections"
            return 1
        fi
    else
        echo "Failed to get namespace info"
        return 1
    fi
}

test_get_namespace_info_missing_container() {
    echo "Testing namespace info for non-existent container..."
    
    local info_output
    if info_output=$(get_namespace_info "non-existent-container" 2>&1); then
        # Should return 1 but still produce output
        if echo "$info_output" | grep -q "No namespace configuration found"; then
            echo "Correctly handled missing container"
            return 0
        else
            echo "Unexpected output for missing container"
            return 1
        fi
    else
        echo "Function correctly returned error for missing container"
        return 0
    fi
}

# =============================================================================
# NAMESPACE CLEANUP TESTS
# =============================================================================

test_cleanup_container_namespaces_success() {
    echo "Testing namespace cleanup..."
    
    # Setup namespaces first
    setup_container_namespaces "$TEST_CONTAINER_NAME" || return 1
    
    # Verify setup
    local ns_dir="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/namespaces"
    if [[ ! -d "$ns_dir" ]]; then
        echo "Namespace directory not found after setup"
        return 1
    fi
    
    # Test cleanup
    if cleanup_container_namespaces "$TEST_CONTAINER_NAME"; then
        # Check if namespace directory was removed
        if [[ ! -d "$ns_dir" ]]; then
            echo "Namespace directory removed successfully"
            
            # Check if container was removed from active tracking
            if [[ -z "${ACTIVE_NAMESPACES[$TEST_CONTAINER_NAME]:-}" ]]; then
                echo "Container removed from active namespaces tracking"
                return 0
            else
                echo "Container still tracked in active namespaces"
                return 1
            fi
        else
            echo "Namespace directory not removed"
            return 1
        fi
    else
        echo "Namespace cleanup failed"
        return 1
    fi
}

# =============================================================================
# NAMESPACE LISTING TESTS
# =============================================================================

test_list_container_namespaces_empty() {
    echo "Testing namespace listing with no containers..."
    
    local list_output
    if list_output=$(list_container_namespaces); then
        if echo "$list_output" | grep -q "No containers found"; then
            echo "Correctly handled empty container list"
            return 0
        else
            echo "Unexpected output for empty container list"
            return 1
        fi
    else
        echo "Failed to list containers"
        return 1
    fi
}

test_list_container_namespaces_with_containers() {
    echo "Testing namespace listing with containers..."
    
    # Setup a container with namespaces
    setup_container_namespaces "$TEST_CONTAINER_NAME" || return 1
    
    local list_output
    if list_output=$(list_container_namespaces); then
        if echo "$list_output" | grep -q "$TEST_CONTAINER_NAME" && \
           echo "$list_output" | grep -q "Namespaces:" && \
           echo "$list_output" | grep -q "Total Containers: 1"; then
            echo "Container listing shows expected information"
            return 0
        else
            echo "Container listing missing expected information"
            echo "Output: $list_output"
            return 1
        fi
    else
        echo "Failed to list containers"
        return 1
    fi
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main() {
    echo "Starting Namespace Management System Tests"
    echo "=========================================="
    
    # Initialize test environment
    init_test_environment
    
    # Run PID namespace tests
    run_test "Create PID Namespace Success" test_create_pid_namespace_success
    
    # Run mount namespace tests
    run_test "Create Mount Namespace Success" test_create_mount_namespace_success
    
    # Run UTS namespace tests
    run_test "Create UTS Namespace Success" test_create_uts_namespace_success
    run_test "Create UTS Namespace Default Hostname" test_create_uts_namespace_default_hostname
    
    # Run IPC namespace tests
    run_test "Create IPC Namespace Success" test_create_ipc_namespace_success
    
    # Run user namespace tests
    run_test "Create User Namespace Success" test_create_user_namespace_success
    run_test "Create User Namespace Default IDs" test_create_user_namespace_default_ids
    
    # Run complete setup tests
    run_test "Setup Container Namespaces Success" test_setup_container_namespaces_success
    
    # Run information tests
    run_test "Get Namespace Info Success" test_get_namespace_info_success
    run_test "Get Namespace Info Missing Container" test_get_namespace_info_missing_container
    
    # Run cleanup tests
    run_test "Cleanup Container Namespaces Success" test_cleanup_container_namespaces_success
    
    # Run listing tests
    run_test "List Container Namespaces Empty" test_list_container_namespaces_empty
    run_test "List Container Namespaces With Containers" test_list_container_namespaces_with_containers
    
    # Clean up test environment
    cleanup_test_environment
    
    # Print summary and exit with appropriate code
    if print_test_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi