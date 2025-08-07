#!/bin/bash
# RT Container Runtime - Final Integration Validation
# Validates all components are properly integrated

set -e

echo "🔍 RT Container Runtime - Final Integration Validation"
echo "===================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validation results
VALIDATIONS_PASSED=0
VALIDATIONS_FAILED=0

validate_component() {
    local component_name="$1"
    local validation_command="$2"
    local description="$3"
    
    echo -e "\n${BLUE}🔍 Validating: $component_name${NC}"
    echo -e "${BLUE}   📝 $description${NC}"
    
    if eval "$validation_command" >/dev/null 2>&1; then
        echo -e "${GREEN}   ✅ PASSED: $component_name${NC}"
        ((VALIDATIONS_PASSED++))
        return 0
    else
        echo -e "${RED}   ❌ FAILED: $component_name${NC}"
        ((VALIDATIONS_FAILED++))
        return 1
    fi
}

echo -e "${YELLOW}🏠 Seperti RT yang melakukan inspeksi final kompleks perumahan${NC}"

# 1. Script Structure Validation
echo -e "\n${BLUE}📋 PHASE 1: SCRIPT STRUCTURE VALIDATION${NC}"

validate_component "RT Script Executable" \
    "test -x ./rt.sh" \
    "Memastikan rt.sh dapat dijalankan"

validate_component "Script Shebang" \
    "head -1 ./rt.sh | grep -q '#!/bin/bash'" \
    "Memastikan script menggunakan bash interpreter"

validate_component "Configuration Variables" \
    "grep -q 'readonly CONTAINERS_DIR' ./rt.sh" \
    "Memastikan konfigurasi dasar tersedia"

validate_component "Logging Functions" \
    "grep -q 'log_info()' ./rt.sh && grep -q 'log_error()' ./rt.sh" \
    "Memastikan sistem logging dengan analogi RT tersedia"

# 2. Core Functions Validation
echo -e "\n${BLUE}🔧 PHASE 2: CORE FUNCTIONS VALIDATION${NC}"

validate_component "Busybox Management" \
    "grep -q 'setup_busybox()' ./rt.sh" \
    "Memastikan fungsi manajemen busybox tersedia"

validate_component "Namespace Functions" \
    "grep -q 'cleanup_container_namespaces\|verify.*namespace' ./rt.sh" \
    "Memastikan fungsi namespace management tersedia"

validate_component "Cgroup Functions" \
    "grep -q 'create_container_cgroup\|setup_cgroup' ./rt.sh" \
    "Memastikan fungsi resource management tersedia"

validate_component "Network Functions" \
    "grep -q 'setup_container_network' ./rt.sh" \
    "Memastikan fungsi networking tersedia"

validate_component "Container Lifecycle" \
    "grep -q 'create_container()' ./rt.sh && grep -q 'delete_container()' ./rt.sh" \
    "Memastikan fungsi lifecycle management tersedia"

# 3. CLI Interface Validation
echo -e "\n${BLUE}💻 PHASE 3: CLI INTERFACE VALIDATION${NC}"

validate_component "Command Parser" \
    "grep -A2 'create' ./rt.sh | grep -q 'shift'" \
    "Memastikan CLI parser tersedia"

validate_component "Help System" \
    "grep -q 'show_interactive_help\|show_main_help' ./rt.sh" \
    "Memastikan sistem bantuan tersedia"

validate_component "Parameter Validation" \
    "grep -q 'parse_create_container_args\|validate_create_container_args' ./rt.sh" \
    "Memastikan validasi parameter tersedia"

# 4. Error Handling Validation
echo -e "\n${BLUE}🚨 PHASE 4: ERROR HANDLING VALIDATION${NC}"

validate_component "Error Handling System" \
    "grep -q 'handle_error' ./rt.sh || grep -q 'trap.*ERR' ./rt.sh" \
    "Memastikan sistem error handling tersedia"

validate_component "Cleanup Functions" \
    "grep -q 'cleanup' ./rt.sh" \
    "Memastikan fungsi cleanup tersedia"

validate_component "Recovery Mechanisms" \
    "grep -q 'recover' ./rt.sh || grep -q 'rollback' ./rt.sh" \
    "Memastikan mekanisme recovery tersedia"

# 5. Educational Features Validation
echo -e "\n${BLUE}📚 PHASE 5: EDUCATIONAL FEATURES VALIDATION${NC}"

validate_component "RT Analogies" \
    "grep -q 'Seperti RT' ./rt.sh" \
    "Memastikan analogi perumahan RT tersedia"

validate_component "Verbose Mode" \
    "grep -q 'VERBOSE_MODE' ./rt.sh" \
    "Memastikan mode verbose educational tersedia"

validate_component "Debug System" \
    "grep -q 'debug' ./rt.sh" \
    "Memastikan sistem debug tersedia"

# 6. Documentation Validation
echo -e "\n${BLUE}📖 PHASE 6: DOCUMENTATION VALIDATION${NC}"

validate_component "Main README" \
    "test -f README.md && grep -q 'RT Container Runtime' README.md" \
    "Memastikan dokumentasi utama tersedia"

validate_component "Analogy Documentation" \
    "test -f docs/ANALOGY.md && grep -q 'Analogi Perumahan' docs/ANALOGY.md" \
    "Memastikan dokumentasi analogi tersedia"

validate_component "Troubleshooting Guide" \
    "test -f docs/TROUBLESHOOTING.md && grep -q 'Troubleshooting' docs/TROUBLESHOOTING.md" \
    "Memastikan panduan troubleshooting tersedia"

validate_component "Security Documentation" \
    "test -f docs/SECURITY.md && grep -q 'Security' docs/SECURITY.md" \
    "Memastikan dokumentasi keamanan tersedia"

# 7. Development Environment Validation
echo -e "\n${BLUE}🐳 PHASE 7: DEVELOPMENT ENVIRONMENT VALIDATION${NC}"

validate_component "Makefile" \
    "test -f Makefile && grep -q 'make dev' Makefile" \
    "Memastikan Makefile development tersedia"

validate_component "Docker Compose" \
    "test -f docker-compose.yml && grep -q 'rt-dev' docker-compose.yml" \
    "Memastikan Docker Compose configuration tersedia"

validate_component "Development Dockerfile" \
    "test -f Dockerfile.dev && grep -q 'privileged' docker-compose.yml" \
    "Memastikan development container configuration tersedia"

# 8. Testing Framework Validation
echo -e "\n${BLUE}🧪 PHASE 8: TESTING FRAMEWORK VALIDATION${NC}"

validate_component "Test Runner" \
    "test -f tests/run-all-tests.sh && test -x tests/run-all-tests.sh" \
    "Memastikan test runner tersedia"

validate_component "Unit Tests" \
    "test -f tests/unit-tests.sh" \
    "Memastikan unit tests tersedia"

validate_component "Integration Tests" \
    "test -f tests/integration-tests.sh" \
    "Memastikan integration tests tersedia"

validate_component "Component Tests" \
    "ls tests/*-tests.sh 2>/dev/null | wc -l | awk '{print \$1}' | grep -E '^([5-9]|[1-9][0-9]+)$'" \
    "Memastikan component tests tersedia"

# Final Summary
echo -e "\n${BLUE}=====================================================${NC}"
echo -e "${BLUE}🏠 RT Container Runtime - Integration Validation Summary${NC}"
echo -e "${BLUE}=====================================================${NC}"

echo -e "Validations Passed: ${GREEN}$VALIDATIONS_PASSED${NC}"
echo -e "Validations Failed: ${RED}$VALIDATIONS_FAILED${NC}"
echo -e "Total Validations: $((VALIDATIONS_PASSED + VALIDATIONS_FAILED))"

if [[ $VALIDATIONS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 ALL VALIDATIONS PASSED!${NC}"
    echo -e "${GREEN}   ✅ RT Container Runtime is fully integrated and ready for use${NC}"
    echo -e "${GREEN}   🏠 Seperti kompleks RT yang sempurna dan siap dihuni${NC}"
    
    echo -e "\n${BLUE}🚀 NEXT STEPS:${NC}"
    echo -e "${BLUE}   1. Run 'make dev' to start development environment${NC}"
    echo -e "${BLUE}   2. Run 'make test' to execute full test suite${NC}"
    echo -e "${BLUE}   3. Try demo scenarios with './demo-scenarios.sh'${NC}"
    echo -e "${BLUE}   4. Read docs/ANALOGY.md for detailed explanations${NC}"
    
    exit 0
else
    echo -e "\n${RED}💥 SOME VALIDATIONS FAILED!${NC}"
    echo -e "${RED}   🚨 RT Container Runtime needs fixes before use${NC}"
    echo -e "${RED}   🏠 Seperti kompleks RT yang masih perlu perbaikan${NC}"
    
    echo -e "\n${YELLOW}🔧 RECOMMENDED ACTIONS:${NC}"
    echo -e "${YELLOW}   1. Check failed validations above${NC}"
    echo -e "${YELLOW}   2. Fix missing components or functions${NC}"
    echo -e "${YELLOW}   3. Re-run this validation script${NC}"
    echo -e "${YELLOW}   4. Consult docs/TROUBLESHOOTING.md for help${NC}"
    
    exit 1
fi