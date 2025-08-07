#!/bin/bash

# Quick diagnostic script to check rootless container support
# Author: Container Learning Project

set -euo pipefail

# Colors for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'

echo -e "${COLOR_BLUE}🔍 RT Container Runtime - Rootless Support Check${COLOR_RESET}"
echo -e "${COLOR_BLUE}================================================${COLOR_RESET}\n"

# Check OS information
echo -e "${COLOR_CYAN}📋 System Information:${COLOR_RESET}"
echo -e "   OS: $(uname -s)"
echo -e "   Kernel: $(uname -r)"
echo -e "   Architecture: $(uname -m)"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo -e "   Distribution: $PRETTY_NAME"
fi
echo

# Check user namespaces
echo -e "${COLOR_CYAN}🔓 User Namespaces:${COLOR_RESET}"
if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
    local userns_enabled=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "0")
    if [[ "$userns_enabled" == "1" ]]; then
        echo -e "${COLOR_GREEN}   ✅ Status: Enabled${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}   ❌ Status: Disabled${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   💡 Fix: echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_RED}   ❌ Status: Not available${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   💡 This kernel doesn't support user namespaces${COLOR_RESET}"
fi
echo

# Check required tools
echo -e "${COLOR_CYAN}🔧 Required Tools:${COLOR_RESET}"
local tools=("unshare" "newuidmap" "newgidmap" "ip" "mount" "umount")
local missing_tools=()

for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo -e "${COLOR_GREEN}   ✅ $tool: $(command -v "$tool")${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}   ❌ $tool: Not found${COLOR_RESET}"
        missing_tools+=("$tool")
    fi
done

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo -e "\n${COLOR_YELLOW}   💡 Install missing tools:${COLOR_RESET}"
    if [[ -f /etc/debian_version ]]; then
        echo -e "${COLOR_YELLOW}      sudo apt install uidmap${COLOR_RESET}"
    elif [[ -f /etc/redhat-release ]]; then
        echo -e "${COLOR_YELLOW}      sudo yum install shadow-utils${COLOR_RESET}"
    elif [[ -f /etc/arch-release ]]; then
        echo -e "${COLOR_YELLOW}      sudo pacman -S shadow${COLOR_RESET}"
    fi
fi
echo

# Check subuid/subgid mappings
echo -e "${COLOR_CYAN}👤 User ID Mappings:${COLOR_RESET}"
local current_user=$(id -un)
echo -e "   Current user: $current_user"

if [[ -f /etc/subuid ]]; then
    if grep -q "^$current_user:" /etc/subuid; then
        echo -e "${COLOR_GREEN}   ✅ subuid: $(grep "^$current_user:" /etc/subuid | head -1)${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}   ❌ subuid: No mapping found${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   💡 Fix: echo '$current_user:100000:65536' | sudo tee -a /etc/subuid${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_RED}   ❌ subuid: /etc/subuid not found${COLOR_RESET}"
fi

if [[ -f /etc/subgid ]]; then
    if grep -q "^$current_user:" /etc/subgid; then
        echo -e "${COLOR_GREEN}   ✅ subgid: $(grep "^$current_user:" /etc/subgid | head -1)${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}   ❌ subgid: No mapping found${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   💡 Fix: echo '$current_user:100000:65536' | sudo tee -a /etc/subgid${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_RED}   ❌ subgid: /etc/subgid not found${COLOR_RESET}"
fi
echo

# Check cgroups
echo -e "${COLOR_CYAN}📊 Cgroups Support:${COLOR_RESET}"
if [[ -d "/sys/fs/cgroup" ]]; then
    echo -e "${COLOR_GREEN}   ✅ Cgroups filesystem: Available${COLOR_RESET}"
    
    # Check cgroups v2
    if [[ -f "/sys/fs/cgroup/cgroup.controllers" ]]; then
        echo -e "${COLOR_GREEN}   ✅ Cgroups v2: Available${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}   ⚠️  Cgroups v2: Not available (v1 only)${COLOR_RESET}"
    fi
    
    # Check user slice
    if [[ -d "/sys/fs/cgroup/user.slice/user-$(id -u).slice" ]]; then
        echo -e "${COLOR_GREEN}   ✅ User slice: Available${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}   ⚠️  User slice: Not available${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   💡 Resource limits may not work in rootless mode${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_RED}   ❌ Cgroups filesystem: Not available${COLOR_RESET}"
fi
echo

# Test basic unshare functionality
echo -e "${COLOR_CYAN}🧪 Testing Basic Functionality:${COLOR_RESET}"
if command -v unshare &> /dev/null; then
    if unshare --user --pid --fork echo "test" &> /dev/null; then
        echo -e "${COLOR_GREEN}   ✅ Basic unshare: Working${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}   ❌ Basic unshare: Failed${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   💡 User namespaces may not be properly configured${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_RED}   ❌ unshare command not available${COLOR_RESET}"
fi

# Summary
echo -e "\n${COLOR_BLUE}📋 SUMMARY:${COLOR_RESET}"
echo -e "${COLOR_BLUE}==========${COLOR_RESET}"

# Count issues
local issues=0

# Check each requirement
if [[ ! -f /proc/sys/kernel/unprivileged_userns_clone ]] || [[ "$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo '0')" != "1" ]]; then
    ((issues++))
fi

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    ((issues++))
fi

if [[ ! -f /etc/subuid ]] || ! grep -q "^$current_user:" /etc/subuid; then
    ((issues++))
fi

if [[ ! -f /etc/subgid ]] || ! grep -q "^$current_user:" /etc/subgid; then
    ((issues++))
fi

if [[ $issues -eq 0 ]]; then
    echo -e "${COLOR_GREEN}🎉 Your system is ready for rootless containers!${COLOR_RESET}"
    echo -e "${COLOR_GREEN}   You can run: ./rt.sh --rootless create test${COLOR_RESET}"
else
    echo -e "${COLOR_RED}❌ Found $issues issue(s) that need to be fixed${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}💡 Run ./setup-rootless.sh to automatically fix these issues${COLOR_RESET}"
fi

echo -e "\n${COLOR_BLUE}🏘️  Seperti RT yang memastikan semua fasilitas kompleks siap digunakan!${COLOR_RESET}"
