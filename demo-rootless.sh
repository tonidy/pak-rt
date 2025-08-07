#!/bin/bash

# Demo script untuk menunjukkan penggunaan RT Container Runtime dalam mode rootless
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

echo -e "${COLOR_BLUE}🏘️  RT Container Runtime - Demo Mode Rootless${COLOR_RESET}"
echo -e "${COLOR_BLUE}=============================================${COLOR_RESET}\n"

echo -e "${COLOR_GREEN}📚 PENJELASAN MODE ROOTLESS:${COLOR_RESET}"
echo -e "${COLOR_GREEN}Mode rootless memungkinkan menjalankan container tanpa sudo${COLOR_RESET}"
echo -e "${COLOR_GREEN}dengan menggunakan user namespaces dan fitur Linux terbaru${COLOR_RESET}\n"

echo -e "${COLOR_YELLOW}⚠️  KETERBATASAN MODE ROOTLESS:${COLOR_RESET}"
echo -e "${COLOR_YELLOW}├── Resource limits (cgroups) mungkin tidak tersedia${COLOR_RESET}"
echo -e "${COLOR_YELLOW}├── Beberapa fitur network mungkin terbatas${COLOR_RESET}"
echo -e "${COLOR_YELLOW}├── Container disimpan di ~/.local/share/rt${COLOR_RESET}"
echo -e "${COLOR_YELLOW}└── Perlu konfigurasi subuid/subgid untuk beberapa distro${COLOR_RESET}\n"

echo -e "${COLOR_CYAN}🔍 MEMERIKSA DUKUNGAN ROOTLESS...${COLOR_RESET}"

# Check if user namespaces are enabled
if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
    userns_enabled=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "0")
    if [[ "$userns_enabled" == "1" ]]; then
        echo -e "${COLOR_GREEN}✅ User namespaces: Enabled${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}❌ User namespaces: Disabled${COLOR_RESET}"
        echo -e "${COLOR_RED}   Perlu mengaktifkan dengan: echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_RED}❌ User namespaces: Not available${COLOR_RESET}"
fi

# Check for required tools
echo -e "\n${COLOR_CYAN}🔧 MEMERIKSA TOOLS YANG DIPERLUKAN...${COLOR_RESET}"

tools=("unshare" "newuidmap" "newgidmap")
all_tools_available=true

for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo -e "${COLOR_GREEN}✅ $tool: Available${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}❌ $tool: Missing${COLOR_RESET}"
        all_tools_available=false
    fi
done

# Check subuid/subgid
echo -e "\n${COLOR_CYAN}👤 MEMERIKSA KONFIGURASI USER...${COLOR_RESET}"
current_user=$(id -un)

if [[ -f /etc/subuid ]] && grep -q "^$current_user:" /etc/subuid; then
    echo -e "${COLOR_GREEN}✅ subuid mapping: Available for $current_user${COLOR_RESET}"
    grep "^$current_user:" /etc/subuid | head -1
else
    echo -e "${COLOR_YELLOW}⚠️  subuid mapping: Not configured for $current_user${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   Mungkin perlu menambahkan: $current_user:100000:65536 ke /etc/subuid${COLOR_RESET}"
fi

if [[ -f /etc/subgid ]] && grep -q "^$current_user:" /etc/subgid; then
    echo -e "${COLOR_GREEN}✅ subgid mapping: Available for $current_user${COLOR_RESET}"
    grep "^$current_user:" /etc/subgid | head -1
else
    echo -e "${COLOR_YELLOW}⚠️  subgid mapping: Not configured for $current_user${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   Mungkin perlu menambahkan: $current_user:100000:65536 ke /etc/subgid${COLOR_RESET}"
fi

echo -e "\n${COLOR_PURPLE}🚀 CONTOH PENGGUNAAN MODE ROOTLESS:${COLOR_RESET}"
echo -e "${COLOR_PURPLE}# 1. Cek dukungan sistem${COLOR_RESET}"
echo -e "${COLOR_PURPLE}./rt.sh --rootless validate-system${COLOR_RESET}\n"

echo -e "${COLOR_PURPLE}# 2. Buat container tanpa sudo${COLOR_RESET}"
echo -e "${COLOR_PURPLE}./rt.sh --rootless create rumah-user${COLOR_RESET}\n"

echo -e "${COLOR_PURPLE}# 3. Jalankan container${COLOR_RESET}"
echo -e "${COLOR_PURPLE}./rt.sh --rootless run rumah-user${COLOR_RESET}\n"

echo -e "${COLOR_PURPLE}# 4. List container${COLOR_RESET}"
echo -e "${COLOR_PURPLE}./rt.sh --rootless list${COLOR_RESET}\n"

echo -e "${COLOR_PURPLE}# 5. Hapus container${COLOR_RESET}"
echo -e "${COLOR_PURPLE}./rt.sh --rootless delete rumah-user${COLOR_RESET}\n"

if [[ "$all_tools_available" == "true" && "$userns_enabled" == "1" ]]; then
    echo -e "${COLOR_GREEN}🎉 SISTEM SIAP UNTUK MODE ROOTLESS!${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Anda bisa langsung mencoba perintah di atas${COLOR_RESET}\n"
    
    read -p "Apakah Anda ingin mencoba membuat container rootless sekarang? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\n${COLOR_CYAN}🏗️  MEMBUAT CONTAINER ROOTLESS...${COLOR_RESET}"
        ./rt.sh --rootless create demo-rootless
        
        echo -e "\n${COLOR_CYAN}📋 MELIHAT DAFTAR CONTAINER...${COLOR_RESET}"
        ./rt.sh --rootless list
        
        echo -e "\n${COLOR_CYAN}🧹 MEMBERSIHKAN DEMO...${COLOR_RESET}"
        ./rt.sh --rootless delete demo-rootless --force
        
        echo -e "\n${COLOR_GREEN}✅ DEMO SELESAI!${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_RED}❌ SISTEM BELUM SIAP UNTUK MODE ROOTLESS${COLOR_RESET}"
    echo -e "${COLOR_RED}Silakan perbaiki masalah di atas terlebih dahulu${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 TIPS SETUP ROOTLESS:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}1. Ubuntu/Debian: sudo apt install uidmap${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. CentOS/RHEL: sudo yum install shadow-utils${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}3. Arch Linux: sudo pacman -S shadow${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}4. Enable user namespaces jika diperlukan${COLOR_RESET}"
fi

echo -e "\n${COLOR_BLUE}🏘️  Seperti RT yang memberikan opsi fleksibel untuk warga!${COLOR_RESET}"
