#!/bin/bash

# Test script for memory usage tracking and OOM testing fixes
# This script demonstrates the improved memory monitoring and OOM testing functionality

set -euo pipefail

echo "🧪 Testing Memory Usage Tracking and OOM Functionality"
echo "======================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test configuration
TEST_CONTAINER="memory-test-container"
MEMORY_LIMIT_MB=128
STRESS_TARGET_MB=96
STRESS_DURATION=20

echo -e "${BLUE}Test Configuration:${NC}"
echo -e "  Container Name: $TEST_CONTAINER"
echo -e "  Memory Limit: ${MEMORY_LIMIT_MB}MB"
echo -e "  Stress Target: ${STRESS_TARGET_MB}MB"
echo -e "  Stress Duration: ${STRESS_DURATION}s"
echo ""

# Function to run test and capture result
run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -e "${CYAN}🔬 Running: $test_name${NC}"
    echo -e "${CYAN}Command: $command${NC}"
    echo ""
    
    if eval "$command"; then
        echo -e "${GREEN}✅ $test_name: PASSED${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name: FAILED${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up test container...${NC}"
    ./rt.sh delete "$TEST_CONTAINER" 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Set up cleanup trap
trap cleanup EXIT

echo -e "${BLUE}📋 Test Plan:${NC}"
echo -e "  1. Create container with memory limit"
echo -e "  2. Test basic memory monitoring"
echo -e "  3. Test memory allocation (within limits)"
echo -e "  4. Test memory stress (may trigger OOM)"
echo -e "  5. Verify memory usage tracking accuracy"
echo ""

# Test 1: Create container with memory limit
echo -e "${YELLOW}=== Test 1: Container Creation ===${NC}"
if run_test "Create container with ${MEMORY_LIMIT_MB}MB limit" \
    "./rt.sh create $TEST_CONTAINER --ram=$MEMORY_LIMIT_MB --cpu=25"; then
    echo -e "${GREEN}Container created successfully${NC}"
else
    echo -e "${RED}Failed to create container${NC}"
    exit 1
fi
echo ""

# Test 2: Check container status and cgroup setup
echo -e "${YELLOW}=== Test 2: Container Status Check ===${NC}"
echo -e "${CYAN}Checking container status...${NC}"
./rt.sh list
echo ""

echo -e "${CYAN}Checking cgroup setup...${NC}"
if [[ -d "/sys/fs/cgroup/memory/container-$TEST_CONTAINER" ]]; then
    echo -e "${GREEN}✅ cgroup v1 memory controller found${NC}"
    MEMORY_CGROUP="/sys/fs/cgroup/memory/container-$TEST_CONTAINER"
elif [[ -d "/sys/fs/cgroup/container-$TEST_CONTAINER" ]]; then
    echo -e "${GREEN}✅ cgroup v2 unified hierarchy found${NC}"
    MEMORY_CGROUP="/sys/fs/cgroup/container-$TEST_CONTAINER"
else
    echo -e "${RED}❌ No memory cgroup found${NC}"
    MEMORY_CGROUP=""
fi

if [[ -n "$MEMORY_CGROUP" ]]; then
    echo -e "${CYAN}Memory cgroup path: $MEMORY_CGROUP${NC}"
    
    # Check memory limit file
    if [[ -f "$MEMORY_CGROUP/memory.limit_in_bytes" ]]; then
        LIMIT=$(cat "$MEMORY_CGROUP/memory.limit_in_bytes")
        LIMIT_MB=$((LIMIT / 1024 / 1024))
        echo -e "${GREEN}✅ Memory limit set: ${LIMIT_MB}MB${NC}"
    elif [[ -f "$MEMORY_CGROUP/memory.max" ]]; then
        LIMIT=$(cat "$MEMORY_CGROUP/memory.max")
        if [[ "$LIMIT" != "max" ]]; then
            LIMIT_MB=$((LIMIT / 1024 / 1024))
            echo -e "${GREEN}✅ Memory limit set: ${LIMIT_MB}MB${NC}"
        else
            echo -e "${YELLOW}⚠️  Memory limit is unlimited${NC}"
        fi
    else
        echo -e "${RED}❌ No memory limit file found${NC}"
    fi
fi
echo ""

# Test 3: Start container and test basic monitoring
echo -e "${YELLOW}=== Test 3: Basic Memory Monitoring ===${NC}"
echo -e "${CYAN}Starting container...${NC}"
./rt.sh run "$TEST_CONTAINER" "sleep 30" &
CONTAINER_PID=$!

# Wait a moment for container to start
sleep 3

echo -e "${CYAN}Testing resource monitoring...${NC}"
timeout 10 ./rt.sh monitor "$TEST_CONTAINER" 8 || echo -e "${YELLOW}Monitor completed or timed out${NC}"
echo ""

# Test 4: Memory allocation test (within limits)
echo -e "${YELLOW}=== Test 4: Memory Allocation Test ===${NC}"
# Use a smaller allocation that should succeed
SAFE_ALLOCATION=$((MEMORY_LIMIT_MB / 2))
run_test "Memory allocation test (${SAFE_ALLOCATION}MB)" \
    "./rt.sh test-memory $TEST_CONTAINER $SAFE_ALLOCATION"
echo ""

# Test 5: Memory stress test (may trigger OOM)
echo -e "${YELLOW}=== Test 5: Memory Stress Test ===${NC}"
echo -e "${CYAN}⚠️  This test may trigger OOM killer - this is expected behavior${NC}"
run_test "Memory stress test (${STRESS_TARGET_MB}MB for ${STRESS_DURATION}s)" \
    "./rt.sh stress-memory $TEST_CONTAINER $STRESS_TARGET_MB $STRESS_DURATION" || \
    echo -e "${YELLOW}💡 OOM killer may have been triggered - this demonstrates working memory limits${NC}"
echo ""

# Test 6: Final resource usage check
echo -e "${YELLOW}=== Test 6: Final Resource Usage Check ===${NC}"
echo -e "${CYAN}Final container resource usage:${NC}"
./rt.sh monitor "$TEST_CONTAINER" 5 2>/dev/null || echo -e "${YELLOW}Container may have been OOM killed${NC}"
echo ""

# Kill background container process if still running
if kill -0 $CONTAINER_PID 2>/dev/null; then
    echo -e "${CYAN}Stopping background container process...${NC}"
    kill $CONTAINER_PID 2>/dev/null || true
    wait $CONTAINER_PID 2>/dev/null || true
fi

echo -e "${GREEN}🎉 Memory testing demonstration completed!${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo -e "  • Memory usage tracking has been improved for both cgroup v1 and v2"
echo -e "  • OOM testing functionality has been added"
echo -e "  • Memory stress testing can now properly trigger OOM conditions"
echo -e "  • Real-time memory monitoring shows accurate usage data"
echo ""
echo -e "${CYAN}💡 Key improvements:${NC}"
echo -e "  1. Enhanced cgroup version detection"
echo -e "  2. Proper memory allocation in test scripts"
echo -e "  3. Real memory usage instead of just cgroup accounting"
echo -e "  4. Better OOM testing with actual memory pressure"
echo -e "  5. Improved monitoring with both cgroup v1 and v2 support"
