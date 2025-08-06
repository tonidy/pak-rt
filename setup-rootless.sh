#!/bin/bash

# Setup script untuk mengaktifkan mode rootless pada RT Container Runtime
# Author: Container Learning Project

set -euo pipefail

# Colors for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'

echo -e "${COLOR_BLUE}🔧 RT Container Runtime - Rootless Setup${COLOR_RESET}"
echo -e "${COLOR_BLUE}=======================================${COLOR_RESET}\n"

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Function to install required packages
install_packages() {
    local os_type=$(detect_os)
    
    echo -e "${COLOR_CYAN}📦 Installing required packages for $os_type...${COLOR_RESET}"
    
    case "$os_type" in
        "ubuntu"|"debian")
            echo -e "${COLOR_GREEN}Installing uidmap package...${COLOR_RESET}"
            sudo apt update
            sudo apt install -y uidmap
            ;;
        "centos"|"rhel"|"fedora")
            echo -e "${COLOR_GREEN}Installing shadow-utils package...${COLOR_RESET}"
            if command -v dnf &> /dev/null; then
                sudo dnf install -y shadow-utils
            else
                sudo yum install -y shadow-utils
            fi
            ;;
        "arch")
            echo -e "${COLOR_GREEN}Installing shadow package...${COLOR_RESET}"
            sudo pacman -S --noconfirm shadow
            ;;
        *)
            echo -e "${COLOR_YELLOW}⚠️  Unknown OS. Please install uidmap/shadow-utils manually${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}   Ubuntu/Debian: sudo apt install uidmap${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}   CentOS/RHEL: sudo yum install shadow-utils${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}   Arch: sudo pacman -S shadow${COLOR_RESET}"
            return 1
            ;;
    esac
}

# Function to enable user namespaces
enable_user_namespaces() {
    echo -e "\n${COLOR_CYAN}🔓 Enabling user namespaces...${COLOR_RESET}"
    
    # Check if already enabled
    if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
        local current_value=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "0")
        if [[ "$current_value" == "1" ]]; then
            echo -e "${COLOR_GREEN}✅ User namespaces already enabled${COLOR_RESET}"
            return 0
        fi
    fi
    
    # Enable temporarily
    echo -e "${COLOR_GREEN}Enabling user namespaces temporarily...${COLOR_RESET}"
    echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone > /dev/null
    
    # Make permanent
    echo -e "${COLOR_GREEN}Making user namespaces permanent...${COLOR_RESET}"
    if ! grep -q "kernel.unprivileged_userns_clone" /etc/sysctl.conf 2>/dev/null; then
        echo "kernel.unprivileged_userns_clone=1" | sudo tee -a /etc/sysctl.conf > /dev/null
        echo -e "${COLOR_GREEN}✅ Added to /etc/sysctl.conf${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}✅ Already configured in /etc/sysctl.conf${COLOR_RESET}"
    fi
}

# Function to setup subuid/subgid mappings
setup_subuid_subgid() {
    local current_user=$(id -un)
    
    echo -e "\n${COLOR_CYAN}👤 Setting up subuid/subgid mappings for $current_user...${COLOR_RESET}"
    
    # Setup subuid
    if [[ -f /etc/subuid ]] && grep -q "^$current_user:" /etc/subuid; then
        echo -e "${COLOR_GREEN}✅ subuid mapping already exists for $current_user${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}Adding subuid mapping for $current_user...${COLOR_RESET}"
        echo "$current_user:100000:65536" | sudo tee -a /etc/subuid > /dev/null
        echo -e "${COLOR_GREEN}✅ Added subuid mapping${COLOR_RESET}"
    fi
    
    # Setup subgid
    if [[ -f /etc/subgid ]] && grep -q "^$current_user:" /etc/subgid; then
        echo -e "${COLOR_GREEN}✅ subgid mapping already exists for $current_user${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}Adding subgid mapping for $current_user...${COLOR_RESET}"
        echo "$current_user:100000:65536" | sudo tee -a /etc/subgid > /dev/null
        echo -e "${COLOR_GREEN}✅ Added subgid mapping${COLOR_RESET}"
    fi
}

# Function to verify setup
verify_setup() {
    echo -e "\n${COLOR_CYAN}🔍 Verifying rootless setup...${COLOR_RESET}"
    
    local issues=()
    
    # Check user namespaces
    if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
        local userns_enabled=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "0")
        if [[ "$userns_enabled" == "1" ]]; then
            echo -e "${COLOR_GREEN}✅ User namespaces: Enabled${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}❌ User namespaces: Disabled${COLOR_RESET}"
            issues+=("user_namespaces")
        fi
    else
        echo -e "${COLOR_RED}❌ User namespaces: Not available${COLOR_RESET}"
        issues+=("user_namespaces")
    fi
    
    # Check required tools
    local tools=("unshare" "newuidmap" "newgidmap")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "${COLOR_GREEN}✅ $tool: Available${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}❌ $tool: Missing${COLOR_RESET}"
            issues+=("$tool")
        fi
    done
    
    # Check subuid/subgid
    local current_user=$(id -un)
    if [[ -f /etc/subuid ]] && grep -q "^$current_user:" /etc/subuid; then
        echo -e "${COLOR_GREEN}✅ subuid mapping: Available${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}❌ subuid mapping: Missing${COLOR_RESET}"
        issues+=("subuid")
    fi
    
    if [[ -f /etc/subgid ]] && grep -q "^$current_user:" /etc/subgid; then
        echo -e "${COLOR_GREEN}✅ subgid mapping: Available${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}❌ subgid mapping: Missing${COLOR_RESET}"
        issues+=("subgid")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "\n${COLOR_GREEN}🎉 ROOTLESS SETUP COMPLETE!${COLOR_RESET}"
        echo -e "${COLOR_GREEN}You can now use: ./rt.sh --rootless create-container nama-container${COLOR_RESET}"
        return 0
    else
        echo -e "\n${COLOR_RED}❌ Setup incomplete. Issues found: ${issues[*]}${COLOR_RESET}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${COLOR_GREEN}This script will setup your system for rootless containers${COLOR_RESET}"
    echo -e "${COLOR_GREEN}It will install required packages and configure user namespaces${COLOR_RESET}\n"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${COLOR_RED}❌ Please run this script as a regular user (not root)${COLOR_RESET}"
        echo -e "${COLOR_RED}   The script will use sudo when needed${COLOR_RESET}"
        exit 1
    fi
    
    # Ask for confirmation
    read -p "Do you want to proceed with rootless setup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${COLOR_YELLOW}Setup cancelled${COLOR_RESET}"
        exit 0
    fi
    
    # Run setup steps
    install_packages
    enable_user_namespaces
    setup_subuid_subgid
    verify_setup
    
    if [[ $? -eq 0 ]]; then
        echo -e "\n${COLOR_PURPLE}🚀 Next steps:${COLOR_RESET}"
        echo -e "${COLOR_PURPLE}1. Test with: ./rt.sh --rootless validate-system${COLOR_RESET}"
        echo -e "${COLOR_PURPLE}2. Create container: ./rt.sh --rootless create-container test${COLOR_RESET}"
        echo -e "${COLOR_PURPLE}3. Run container: ./rt.sh --rootless run-container test${COLOR_RESET}"
    else
        echo -e "\n${COLOR_RED}❌ Setup failed. Please check the errors above${COLOR_RESET}"
        exit 1
    fi
}

# Run main function
main "$@"
