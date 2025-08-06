#!/bin/bash
# RT Container Runtime - Unit Tests
# Tests individual functions dan components

set -e

echo "🔬 Running Unit Tests untuk RT Container Runtime"
echo "===================================================="

# Test configuration
TEST_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
UNIT_TESTS_PASSED=0
UNIT_TESTS_FAILED=0

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✅ $test_name${NC}"
        ((UNIT_TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name${NC}"
        echo -e "   Expected: $expected"
        echo -e "   Actual: $actual"
        ((UNIT_TESTS_FAILED++))
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="$2"
    
    if [ -f "$file_path" ]; then
        echo -e "${GREEN}✅ $test_name${NC}"
        ((UNIT_TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name${NC}"
        echo -e "   File not found: $file_path"
        ((UNIT_TESTS_FAILED++))
    fi
}

# Test 1: Check if development environment is properly setup
echo -e "\n${YELLOW}Testing Development Environment Setup...${NC}"

assert_file_exists "$PROJECT_ROOT/Makefile" "Makefile exists"
assert_file_exists "$PROJECT_ROOT/docker-compose.yml" "docker-compose.yml exists"
assert_file_exists "$PROJECT_ROOT/Dockerfile.dev" "Dockerfile.dev exists"

# Test 2: Check required directories
echo -e "\n${YELLOW}Testing Directory Structure...${NC}"

if [ -d "$PROJECT_ROOT/tests" ]; then
    echo -e "${GREEN}✅ tests directory exists${NC}"
    ((UNIT_TESTS_PASSED++))
else
    echo -e "${RED}❌ tests directory missing${NC}"
    ((UNIT_TESTS_FAILED++))
fi

if [ -d "$PROJECT_ROOT/docs" ]; then
    echo -e "${GREEN}✅ docs directory exists${NC}"
    ((UNIT_TESTS_PASSED++))
else
    echo -e "${RED}❌ docs directory missing${NC}"
    ((UNIT_TESTS_FAILED++))
fi

# Test 3: Check if required tools are available dalam container
echo -e "\n${YELLOW}Testing Required Tools Availability...${NC}"

check_command() {
    local cmd="$1"
    local test_name="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $test_name${NC}"
        ((UNIT_TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name${NC}"
        ((UNIT_TESTS_FAILED++))
    fi
}

check_command "ip" "ip command available"
check_command "unshare" "unshare command available"
check_command "nsenter" "nsenter command available"
check_command "jq" "jq command available"

# Test 4: Check cgroup filesystem
echo -e "\n${YELLOW}Testing Cgroup Filesystem...${NC}"

if [ -d "/sys/fs/cgroup" ]; then
    echo -e "${GREEN}✅ cgroup filesystem mounted${NC}"
    ((UNIT_TESTS_PASSED++))
else
    echo -e "${RED}❌ cgroup filesystem not available${NC}"
    ((UNIT_TESTS_FAILED++))
fi

# Test 5: Run Busybox Management System Tests
echo -e "\n${YELLOW}Testing Busybox Management System...${NC}"

if [ -x "$TEST_DIR/busybox-tests.sh" ]; then
    echo -e "${GREEN}✅ busybox-tests.sh is executable${NC}"
    ((UNIT_TESTS_PASSED++))
    
    # Run busybox tests and capture results
    if "$TEST_DIR/busybox-tests.sh"; then
        echo -e "${GREEN}✅ Busybox management system tests passed${NC}"
        ((UNIT_TESTS_PASSED++))
    else
        echo -e "${RED}❌ Busybox management system tests failed${NC}"
        ((UNIT_TESTS_FAILED++))
    fi
else
    echo -e "${RED}❌ busybox-tests.sh not found or not executable${NC}"
    ((UNIT_TESTS_FAILED++))
fi

# Summary
echo -e "\n===================================================="
echo -e "Unit Test Summary:"
echo -e "${GREEN}Passed: $UNIT_TESTS_PASSED${NC}"
echo -e "${RED}Failed: $UNIT_TESTS_FAILED${NC}"

if [ $UNIT_TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All unit tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some unit tests failed!${NC}"
    exit 1
fi