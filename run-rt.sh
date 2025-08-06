#!/bin/bash

# RT Container Runtime Wrapper
# Wrapper script untuk menjalankan rt.sh dengan mode yang tepat

set -euo pipefail

# Colors for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RT_SCRIPT="$SCRIPT_DIR/rt.sh"

# Check if rt.sh exists
if [[ ! -f "$RT_SCRIPT" ]]; then
    echo -e "${COLOR_RED}Error: rt.sh not found in $SCRIPT_DIR${COLOR_RESET}"
    exit 1
fi

# Make sure rt.sh is executable
chmod +x "$RT_SCRIPT"

# Function to show usage
show_usage() {
    echo -e "${COLOR_BLUE}🏘️  RT Container Runtime Wrapper${COLOR_RESET}"
    echo -e "${COLOR_BLUE}====================================${COLOR_RESET}"
    echo
    echo -e "${COLOR_GREEN}USAGE:${COLOR_RESET}"
    echo -e "  $0 [MODE] [COMMAND] [OPTIONS]"
    echo
    echo -e "${COLOR_YELLOW}MODES:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}--sudo${COLOR_RESET}     : Run with sudo (full features)"
    echo -e "  ${COLOR_CYAN}--rootless${COLOR_RESET} : Run without sudo (limited features)"
    echo -e "  ${COLOR_CYAN}--auto${COLOR_RESET}     : Auto-detect best mode"
    echo
    echo -e "${COLOR_YELLOW}EXAMPLES:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}# Create container with sudo${COLOR_RESET}"
    echo -e "  $0 --sudo create-container webapp --ram=512 --cpu=50"
    echo
    echo -e "  ${COLOR_GREEN}# Create container without sudo (rootless)${COLOR_RESET}"
    echo -e "  $0 --rootless create-container webapp --ram=512 --cpu=50"
    echo
    echo -e "  ${COLOR_GREEN}# Auto-detect mode${COLOR_RESET}"
    echo -e "  $0 --auto create-container webapp --ram=512 --cpu=50"
    echo
    echo -e "  ${COLOR_GREEN}# Show help${COLOR_RESET}"
    echo -e "  $0 help"
    echo
}

# Function to check if sudo is available and working
check_sudo() {
    if command -v sudo &> /dev/null; then
        if sudo -n true 2>/dev/null; then
            return 0  # sudo available and no password needed
        elif sudo -v 2>/dev/null; then
            return 0  # sudo available and password can be entered
        fi
    fi
    return 1  # sudo not available or not working
}

# Function to check rootless support
check_rootless_support() {
    # Check if user namespaces are enabled
    if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
        local userns_enabled=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "0")
        if [[ "$userns_enabled" == "1" ]]; then
            return 0
        fi
    fi
    return 1
}

# Function to run with sudo
run_with_sudo() {
    echo -e "${COLOR_BLUE}🔐 Running RT with sudo privileges...${COLOR_RESET}"
    echo -e "${COLOR_BLUE}   Seperti RT yang bekerja dengan wewenang penuh${COLOR_RESET}"
    
    if check_sudo; then
        exec sudo "$RT_SCRIPT" "$@"
    else
        echo -e "${COLOR_RED}❌ Error: sudo not available or not configured${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}💡 Try running in rootless mode: $0 --rootless $*${COLOR_RESET}"
        exit 1
    fi
}

# Function to run in rootless mode
run_rootless() {
    echo -e "${COLOR_CYAN}🏠 Running RT in rootless mode...${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   Seperti RT yang bekerja dengan wewenang terbatas${COLOR_RESET}"
    
    if check_rootless_support; then
        exec "$RT_SCRIPT" --rootless "$@"
    else
        echo -e "${COLOR_RED}❌ Error: Rootless mode not supported on this system${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}💡 User namespaces may be disabled${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}💡 Try running with sudo: $0 --sudo $*${COLOR_RESET}"
        exit 1
    fi
}

# Function to auto-detect best mode
run_auto() {
    echo -e "${COLOR_BLUE}🔍 Auto-detecting best mode...${COLOR_RESET}"
    
    # First try sudo if available
    if check_sudo; then
        echo -e "${COLOR_GREEN}✅ Sudo available, using sudo mode${COLOR_RESET}"
        run_with_sudo "$@"
    elif check_rootless_support; then
        echo -e "${COLOR_YELLOW}⚠️  Sudo not available, using rootless mode${COLOR_RESET}"
        run_rootless "$@"
    else
        echo -e "${COLOR_RED}❌ Error: Neither sudo nor rootless mode is available${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}💡 Please configure sudo or enable user namespaces${COLOR_RESET}"
        exit 1
    fi
}

# Main logic
main() {
    # If no arguments, show usage
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi
    
    # Parse mode
    case "$1" in
        --sudo)
            shift
            run_with_sudo "$@"
            ;;
        --rootless)
            shift
            run_rootless "$@"
            ;;
        --auto)
            shift
            run_auto "$@"
            ;;
        help|--help|-h)
            show_usage
            exit 0
            ;;
        *)
            # If no mode specified, try auto mode
            echo -e "${COLOR_YELLOW}⚠️  No mode specified, using auto-detect...${COLOR_RESET}"
            run_auto "$@"
            ;;
    esac
}

# Run main function
main "$@"
