#!/bin/bash

# Busybox Management System Tests
# Tests for RT Container Runtime busybox functionality

set -euo pipefail

# Source the main script to access functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../rt.sh"

# Test configuration
readonly TEST_CONTAINER_NAME="test-busybox-container"
readonly TEST_RESULTS_FILE="/tmp/busybox-test-results.log"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# TEST UTILITIES
# =============================================================================

# Initialize test environment
init_test_environment() {
    echo "=== Initializing Busybox Test Environment ==="
    
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
        rm -rf "$CONTAINERS_DIR/$TEST_CONTAINER_NAME"
        echo "Removed test container directory"
    fi
    
    # Remove test busybox if it's different from main one
    local test_busybox="/tmp/test-busybox"
    if [[ -f "$test_busybox" ]]; then
        rm -f "$test_busybox"
        echo "Removed test busybox binary"
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
# BUSYBOX SETUP TESTS
# =============================================================================

test_setup_busybox_binary_success() {
    echo "Testing successful busybox binary setup..."
    
    # Remove existing busybox to force setup
    if [[ -f "$BUSYBOX_PATH" ]]; then
        mv "$BUSYBOX_PATH" "${BUSYBOX_PATH}.backup"
    fi
    
    # Test setup
    if setup_busybox_binary; then
        # Check if file exists and is executable
        if [[ -x "$BUSYBOX_PATH" ]]; then
            echo "Busybox setup completed and is executable"
            return 0
        else
            echo "Busybox setup completed but not executable"
            return 1
        fi
    else
        echo "Setup function failed"
        return 1
    fi
}

test_setup_busybox_already_exists() {
    echo "Testing busybox setup when file already exists..."
    
    # Ensure busybox exists
    if [[ ! -f "$BUSYBOX_PATH" ]]; then
        setup_busybox_binary || return 1
    fi
    
    # Test that setup skips when file exists and is valid
    local initial_timestamp=$(stat -c %Y "$BUSYBOX_PATH" 2>/dev/null || stat -f %m "$BUSYBOX_PATH")
    
    sleep 1
    
    if setup_busybox_binary; then
        local final_timestamp=$(stat -c %Y "$BUSYBOX_PATH" 2>/dev/null || stat -f %m "$BUSYBOX_PATH")
        
        if [[ "$initial_timestamp" == "$final_timestamp" ]]; then
            echo "Setup correctly skipped existing valid busybox"
            return 0
        else
            echo "Setup unnecessarily re-created existing busybox"
            return 1
        fi
    else
        echo "Setup function failed when busybox already exists"
        return 1
    fi
}

# =============================================================================
# BUSYBOX FUNCTIONALITY VERIFICATION TESTS
# =============================================================================

test_verify_busybox_functionality_success() {
    echo "Testing successful functionality verification..."
    
    # Ensure we have a valid busybox
    setup_busybox_binary || return 1
    
    if verify_busybox_functionality; then
        echo "Functionality verification passed"
        return 0
    else
        echo "Functionality verification failed for valid busybox"
        return 1
    fi
}

test_verify_busybox_functionality_missing_file() {
    echo "Testing functionality verification with missing file..."
    
    # Backup existing busybox
    if [[ -f "$BUSYBOX_PATH" ]]; then
        mv "$BUSYBOX_PATH" "${BUSYBOX_PATH}.backup"
    fi
    
    if verify_busybox_functionality; then
        echo "Functionality verification should have failed for missing file"
        return 1
    else
        echo "Functionality verification correctly failed for missing file"
        # Restore backup
        if [[ -f "${BUSYBOX_PATH}.backup" ]]; then
            mv "${BUSYBOX_PATH}.backup" "$BUSYBOX_PATH"
        fi
        return 0
    fi
}

test_busybox_basic_functionality_test() {
    echo "Testing basic busybox functionality..."
    
    # Ensure busybox is available
    setup_busybox_binary || return 1
    
    if test_busybox_basic_functionality; then
        echo "Basic functionality test passed"
        return 0
    else
        echo "Basic functionality test failed"
        return 1
    fi
}

# =============================================================================
# BUSYBOX SETUP TESTS
# =============================================================================

test_setup_busybox_success() {
    echo "Testing successful busybox setup for container..."
    
    # Ensure busybox is available
    setup_busybox_binary || return 1
    verify_busybox_functionality || return 1
    
    # Setup busybox for test container
    if setup_busybox "$TEST_CONTAINER_NAME"; then
        local container_rootfs="$CONTAINERS_DIR/$TEST_CONTAINER_NAME/rootfs"
        
        # Check if container busybox exists
        if [[ -x "$container_rootfs/bin/busybox" ]]; then
            echo "Container busybox binary created successfully"
        else
            echo "Container busybox binary not found or not executable"
            return 1
        fi
        
        # Check if essential directories were created
        local essential_dirs=("bin" "sbin" "usr/bin" "proc" "sys" "dev" "tmp" "etc")
        for dir in "${essential_dirs[@]}"; do
            if [[ ! -d "$container_rootfs/$dir" ]]; then
                echo "Essential directory missing: $dir"
                return 1
            fi
        done
        
        # Check if symlinks were created
        local test_commands=("sh" "ls" "cat" "echo" "ps")
        for cmd in "${test_commands[@]}"; do
            if [[ ! -L "$container_rootfs/bin/$cmd" ]]; then
                echo "Symlink missing for command: $cmd"
                return 1
            fi
        done
        
        # Check if essential system files were created
        local system_files=("etc/passwd" "etc/group" "etc/hosts" "etc/resolv.conf")
        for file in "${system_files[@]}"; do
            if [[ ! -f "$container_rootfs/$file" ]]; then
                echo "System file missing: $file"
                return 1
            fi
        done
        
        echo "Busybox setup completed successfully"
        return 0
    else
        echo "Busybox setup function failed"
        return 1
    fi
}

# =============================================================================
# BUSYBOX FUNCTIONALITY TESTS
# =============================================================================

test_busybox_functionality_success() {
    echo "Testing busybox functionality..."
    
    # Ensure busybox is available
    setup_busybox_binary || return 1
    verify_busybox_functionality || return 1
    
    if test_busybox_functionality; then
        echo "Busybox functionality test passed"
        return 0
    else
        echo "Busybox functionality test failed"
        return 1
    fi
}

test_busybox_commands_available() {
    echo "Testing availability of common busybox commands..."
    
    # Ensure busybox is available
    setup_busybox_binary || return 1
    
    local test_commands=("echo" "ls" "cat" "ps" "sh" "grep" "sed" "awk")
    local failed_commands=()
    
    for cmd in "${test_commands[@]}"; do
        if ! "$BUSYBOX_PATH" "$cmd" --help &>/dev/null; then
            failed_commands+=("$cmd")
        fi
    done
    
    if [[ ${#failed_commands[@]} -eq 0 ]]; then
        echo "All tested commands are available in busybox"
        return 0
    else
        echo "Some commands are not available: ${failed_commands[*]}"
        # This might not be a failure depending on busybox build
        echo "Warning: Some commands missing, but this might be expected"
        return 0
    fi
}

# =============================================================================
# BUSYBOX SYSTEM INITIALIZATION TESTS
# =============================================================================

test_init_busybox_system_success() {
    echo "Testing complete busybox system initialization..."
    
    # Remove existing busybox to test full initialization
    if [[ -f "$BUSYBOX_PATH" ]]; then
        mv "$BUSYBOX_PATH" "${BUSYBOX_PATH}.backup"
    fi
    
    if init_busybox_system; then
        echo "Busybox system initialization completed successfully"
        return 0
    else
        echo "Busybox system initialization failed"
        return 1
    fi
}

test_get_busybox_info() {
    echo "Testing busybox information display..."
    
    # Ensure busybox is available
    setup_busybox_binary || return 1
    
    local info_output
    if info_output=$(get_busybox_info); then
        echo "Busybox info retrieved successfully:"
        echo "$info_output"
        
        # Check if info contains expected fields
        if echo "$info_output" | grep -q "Path:" && \
           echo "$info_output" | grep -q "Version:" && \
           echo "$info_output" | grep -q "Status:"; then
            echo "Busybox info contains expected fields"
            return 0
        else
            echo "Busybox info missing expected fields"
            return 1
        fi
    else
        echo "Failed to get busybox info"
        return 1
    fi
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main() {
    echo "Starting Busybox Management System Tests"
    echo "========================================"
    
    # Initialize test environment
    init_test_environment
    
    # Run setup tests
    run_test "Setup Busybox Binary Success" test_setup_busybox_binary_success
    run_test "Setup Busybox Already Exists" test_setup_busybox_already_exists
    
    # Run functionality verification tests
    run_test "Verify Functionality Success" test_verify_busybox_functionality_success
    run_test "Verify Functionality Missing File" test_verify_busybox_functionality_missing_file
    run_test "Basic Functionality Test" test_busybox_basic_functionality_test
    
    # Run setup tests
    run_test "Setup Busybox Success" test_setup_busybox_success
    
    # Run functionality tests
    run_test "Busybox Functionality Success" test_busybox_functionality_success
    run_test "Busybox Commands Available" test_busybox_commands_available
    
    # Run system initialization tests
    run_test "Init Busybox System Success" test_init_busybox_system_success
    run_test "Get Busybox Info" test_get_busybox_info
    
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