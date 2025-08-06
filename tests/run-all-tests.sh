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
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test configuration
TEST_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

run_test_suite() {
    local test_name="$1"
    local test_script="$2"
    local required_privileges="${3:-false}"
    
    echo -e "\n${YELLOW}Running $test_name...${NC}"
    echo -e "${CYAN}🏠 Seperti RT yang menjalankan tes: $test_name${NC}"
    
    # Check if test requires root privileges
    if [[ "$required_privileges" == "true" ]] && [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}⏭️  SKIPPED: $test_name (requires root privileges)${NC}"
        echo -e "${YELLOW}   🔑 Seperti tes RT yang memerlukan wewenang khusus${NC}"
        ((TESTS_SKIPPED++))
        return 0
    fi
    
    # Check if test script exists and is executable
    if [[ ! -f "$test_script" ]]; then
        echo -e "${RED}❌ $test_name FAILED (script not found: $test_script)${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    if [[ ! -x "$test_script" ]]; then
        echo -e "${YELLOW}Making test script executable: $test_script${NC}"
        chmod +x "$test_script" 2>/dev/null || true
    fi
    
    # Run the test with timeout
    if timeout 300 bash "$test_script"; then
        echo -e "${GREEN}✅ $test_name PASSED${NC}"
        echo -e "${GREEN}   🎉 Seperti tes RT yang berhasil sempurna${NC}"
        ((TESTS_PASSED++))
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo -e "${RED}❌ $test_name FAILED (timeout)${NC}"
            echo -e "${RED}   ⏰ Seperti tes RT yang terlalu lama${NC}"
        else
            echo -e "${RED}❌ $test_name FAILED (exit code: $exit_code)${NC}"
            echo -e "${RED}   💥 Seperti tes RT yang mengalami masalah${NC}"
        fi
        ((TESTS_FAILED++))
    fi
}

# Ensure we're dalam correct directory
cd "$(dirname "$0")"

echo -e "${BLUE}📋 RT Container Runtime Test Suite${NC}"
echo -e "${BLUE}   🧪 Seperti RT yang menjalankan semua tes sistem kompleks${NC}"
echo -e "${BLUE}================================================${NC}"

# Check if running as root for privileged tests
if [[ $EUID -eq 0 ]]; then
    echo -e "${GREEN}🔑 Running with root privileges - all tests available${NC}"
    echo -e "${GREEN}   👑 Seperti RT dengan wewenang penuh untuk tes kompleks${NC}"
else
    echo -e "${YELLOW}⚠️  Running without root privileges - some tests will be skipped${NC}"
    echo -e "${YELLOW}   🏠 Seperti RT dengan akses terbatas untuk tes tertentu${NC}"
fi

# Phase 1: Basic Tests (no root required)
echo -e "\n${BLUE}📋 PHASE 1: BASIC TESTS${NC}"
run_test_suite "Unit Tests" "./unit-tests.sh" false
run_test_suite "Integration Tests" "./integration-tests.sh" false

# Phase 2: Component Tests (require root)
echo -e "\n${BLUE}🔧 PHASE 2: COMPONENT TESTS${NC}"
run_test_suite "Busybox Management Tests" "./busybox-tests.sh" true
run_test_suite "Namespace Management Tests" "./namespace-tests.sh" true
run_test_suite "Cgroup Management Tests" "./cgroup-tests.sh" true
run_test_suite "Network Management Tests" "./network-tests.sh" true

# Phase 3: Security Tests (mixed privileges)
echo -e "\n${BLUE}🔒 PHASE 3: SECURITY TESTS${NC}"
run_test_suite "Security Features Tests" "./security-tests.sh" false

# Phase 4: Advanced Tests (require root)
echo -e "\n${BLUE}🚀 PHASE 4: ADVANCED TESTS${NC}"
run_test_suite "Resource Validation Tests" "./resource-validation-tests.sh" true
run_test_suite "Stress Tests" "./stress-tests.sh" true
run_test_suite "Cleanup Verification Tests" "./cleanup-verification-tests.sh" true

# Summary
echo -e "\n${BLUE}================================================${NC}"
echo -e "${BLUE}🏠 RT Container Runtime Test Summary${NC}"
echo -e "${BLUE}   📊 Seperti laporan RT tentang hasil tes kompleks${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Tests Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"

# Detailed results
if [[ $TESTS_PASSED -gt 0 ]]; then
    echo -e "\n${GREEN}✅ PASSED TESTS: $TESTS_PASSED${NC}"
    echo -e "${GREEN}   🎉 Seperti sistem RT yang berfungsi dengan baik${NC}"
fi

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "\n${RED}❌ FAILED TESTS: $TESTS_FAILED${NC}"
    echo -e "${RED}   🚨 Seperti sistem RT yang perlu perbaikan${NC}"
fi

if [[ $TESTS_SKIPPED -gt 0 ]]; then
    echo -e "\n${YELLOW}⏭️  SKIPPED TESTS: $TESTS_SKIPPED${NC}"
    echo -e "${YELLOW}   📝 Seperti tes RT yang memerlukan kondisi khusus${NC}"
    echo -e "${YELLOW}   💡 Run with 'sudo' to execute all tests${NC}"
fi

# Final result
if [[ $TESTS_FAILED -eq 0 ]]; then
    if [[ $TESTS_SKIPPED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 ALL TESTS PASSED! Container runtime is fully functional.${NC}"
        echo -e "${GREEN}   ✅ Seperti kompleks RT yang sempurna dalam semua aspek${NC}"
    else
        echo -e "\n${GREEN}🎉 ALL EXECUTED TESTS PASSED! (Some tests were skipped)${NC}"
        echo -e "${GREEN}   ✅ Seperti kompleks RT yang baik dengan beberapa tes tertunda${NC}"
    fi
    exit 0
else
    echo -e "\n${RED}💥 SOME TESTS FAILED! Please check the implementation.${NC}"
    echo -e "${RED}   🚨 Seperti kompleks RT yang memerlukan perbaikan sistem${NC}"
    
    # Provide troubleshooting hints
    echo -e "\n${CYAN}🔍 TROUBLESHOOTING HINTS:${NC}"
    echo -e "${CYAN}   • Check system requirements (Linux kernel features)${NC}"
    echo -e "${CYAN}   • Verify cgroup and namespace support${NC}"
    echo -e "${CYAN}   • Ensure sufficient system resources${NC}"
    echo -e "${CYAN}   • Run individual test suites for detailed error information${NC}"
    echo -e "${CYAN}   • Check RT script permissions and dependencies${NC}"
    
    exit 1
fi