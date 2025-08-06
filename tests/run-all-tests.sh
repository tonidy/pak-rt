#!/bin/bash
# RT Container Runtime - Test Runner
# Runs all tests dalam proper order

set -e

echo "🧪 RT Container Runtime - Running All Tests"
echo "================================================"

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

run_test_suite() {
    local test_name="$1"
    local test_script="$2"
    
    echo -e "\n${YELLOW}Running $test_name...${NC}"
    
    if bash "$test_script"; then
        echo -e "${GREEN}✅ $test_name PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name FAILED${NC}"
        ((TESTS_FAILED++))
    fi
}

# Ensure we're dalam correct directory
cd "$(dirname "$0")"

# Run test suites dalam order
run_test_suite "Unit Tests" "./unit-tests.sh"
run_test_suite "Integration Tests" "./integration-tests.sh"

# Summary
echo -e "\n================================================"
echo -e "Test Summary:"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some tests failed!${NC}"
    exit 1
fi