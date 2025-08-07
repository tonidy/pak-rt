#!/bin/bash
# RT Container Runtime - Educational Demo Scenarios
# Interactive demonstrations untuk learning container technology

set -e

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Demo configuration
DEMO_CONTAINERS=("rumah-jakarta" "rumah-bandung" "rumah-surabaya")
DEMO_DELAY=2

echo -e "${BLUE}🏘️ RT Container Runtime - Educational Demo Scenarios${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e "${PURPLE}🏠 Seperti RT yang memberikan demo cara kerja kompleks perumahan${NC}"

# Check if rt.sh exists and is executable
if [[ ! -x "./rt.sh" ]]; then
    echo -e "${RED}❌ Error: rt.sh not found or not executable${NC}"
    echo -e "${RED}   Make sure you're in the correct directory and rt.sh exists${NC}"
    exit 1
fi

# Check if running in appropriate environment
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}⚠️  Warning: Not running as root${NC}"
    echo -e "${YELLOW}   Some demos may fail. Consider running in Docker: make dev${NC}"
    echo -e "${YELLOW}   Continue anyway? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

pause_demo() {
    local message=${1:-"Press Enter to continue..."}
    echo -e "\n${CYAN}⏸️  $message${NC}"
    read -r
}

demo_header() {
    local title="$1"
    local description="$2"
    
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}🎯 DEMO: $title${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "${PURPLE}📝 $description${NC}"
    echo -e "${PURPLE}🏠 Analogi: $3${NC}"
    pause_demo "Press Enter to start this demo..."
}

cleanup_demo() {
    echo -e "\n${YELLOW}🧹 Cleaning up demo containers...${NC}"
    for container in "${DEMO_CONTAINERS[@]}"; do
        ./rt.sh delete "$container" 2>/dev/null || true
    done
    ./rt.sh cleanup-all 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Trap untuk cleanup on exit
trap cleanup_demo EXIT

# Demo Menu
show_menu() {
    echo -e "\n${BLUE}📋 Available Demo Scenarios:${NC}"
    echo -e "${BLUE}=============================${NC}"
    echo "1. 🏠 Basic Container Lifecycle Demo"
    echo "2. 👨‍👩‍👧‍👦 Process Isolation Demo (PID Namespace)"
    echo "3. 📞 Container Networking Demo"
    echo "4. 💡 Resource Management Demo"
    echo "5. 🏘️ Multi-Container Complex Demo"
    echo "6. 🔍 Debug and Monitoring Demo"
    echo "7. 🚨 Error Handling and Recovery Demo"
    echo "8. 🎓 Complete Educational Walkthrough"
    echo "9. 🧹 Cleanup and Exit"
    echo ""
    echo -e "${CYAN}Enter your choice (1-9): ${NC}"
}

# Demo 1: Basic Container Lifecycle
demo_basic_lifecycle() {
    demo_header "Basic Container Lifecycle" \
                "Demonstrasi dasar create, list, run, dan delete container" \
                "Seperti RT yang mengelola siklus hidup rumah dari bangun sampai roboh"
    
    echo -e "\n${GREEN}Step 1: Creating a new container${NC}"
    echo -e "${PURPLE}🏗️ RT sedang membangun rumah baru...${NC}"
    ./rt.sh create rumah-demo --ram=256 --cpu=25
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 2: Listing containers${NC}"
    echo -e "${PURPLE}📋 RT menunjukkan daftar rumah di kompleks...${NC}"
    ./rt.sh list
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 3: Running container (will exit automatically)${NC}"
    echo -e "${PURPLE}🚪 RT membuka pintu rumah untuk dilihat...${NC}"
    echo -e "${YELLOW}Note: Container will run 'hostname && ps aux && sleep 3' then exit${NC}"
    ./rt.sh run rumah-demo "hostname && ps aux && echo 'Container demo completed' && sleep 3"
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 4: Deleting container${NC}"
    echo -e "${PURPLE}🏗️ RT merobohkan rumah yang sudah tidak dipakai...${NC}"
    ./rt.sh delete rumah-demo
    
    echo -e "\n${GREEN}✅ Basic lifecycle demo completed!${NC}"
    echo -e "${PURPLE}🏠 Seperti RT yang berhasil mengelola satu rumah dari awal sampai akhir${NC}"
}

# Demo 2: Process Isolation
demo_process_isolation() {
    demo_header "Process Isolation (PID Namespace)" \
                "Demonstrasi isolasi process antar container" \
                "Seperti setiap rumah punya penomoran keluarga sendiri"
    
    echo -e "\n${GREEN}Step 1: Creating two containers${NC}"
    ./rt.sh create rumah-a --ram=256 --cpu=25
    ./rt.sh create rumah-b --ram=256 --cpu=25
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 2: Showing process isolation${NC}"
    echo -e "${PURPLE}👨 Setiap rumah punya Ayah dengan nomor 1 (PID 1)${NC}"
    
    echo -e "\n${CYAN}Processes in rumah-a:${NC}"
    ./rt.sh run rumah-a "echo 'Rumah A - PID namespace:' && ps aux && sleep 2" &
    sleep 3
    
    echo -e "\n${CYAN}Processes in rumah-b:${NC}"
    ./rt.sh run rumah-b "echo 'Rumah B - PID namespace:' && ps aux && sleep 2" &
    sleep 3
    
    wait
    
    echo -e "\n${GREEN}✅ Process isolation demo completed!${NC}"
    echo -e "${PURPLE}🏠 Setiap rumah punya sistem penomoran keluarga yang terpisah${NC}"
    
    # Cleanup
    ./rt.sh delete rumah-a
    ./rt.sh delete rumah-b
}

# Demo 3: Container Networking
demo_networking() {
    demo_header "Container Networking" \
                "Demonstrasi komunikasi antar container" \
                "Seperti sistem telepon antar rumah di kompleks"
    
    echo -e "\n${GREEN}Step 1: Creating networked containers${NC}"
    ./rt.sh create rumah-jakarta --ram=256 --cpu=25
    ./rt.sh create rumah-bandung --ram=256 --cpu=25
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 2: Checking IP addresses${NC}"
    echo -e "${PURPLE}📞 Setiap rumah mendapat nomor telepon (IP address)${NC}"
    
    echo -e "\n${CYAN}IP address rumah-jakarta:${NC}"
    ./rt.sh run rumah-jakarta "ip addr show eth0 | grep inet" &
    sleep 2
    
    echo -e "\n${CYAN}IP address rumah-bandung:${NC}"
    ./rt.sh run rumah-bandung "ip addr show eth0 | grep inet" &
    sleep 2
    
    wait
    
    echo -e "\n${GREEN}Step 3: Testing connectivity${NC}"
    echo -e "${PURPLE}📞 Rumah Jakarta menelepon rumah Bandung...${NC}"
    ./rt.sh run rumah-jakarta "ping -c 3 10.0.0.3 || echo 'Network test completed'" &
    sleep 5
    
    wait
    
    echo -e "\n${GREEN}✅ Networking demo completed!${NC}"
    echo -e "${PURPLE}🏠 Sistem telepon kompleks berfungsi dengan baik${NC}"
    
    # Cleanup
    ./rt.sh delete rumah-jakarta
    ./rt.sh delete rumah-bandung
}

# Demo 4: Resource Management
demo_resource_management() {
    demo_header "Resource Management" \
                "Demonstrasi pembatasan memory dan CPU" \
                "Seperti pembagian kuota listrik dan air untuk setiap rumah"
    
    echo -e "\n${GREEN}Step 1: Creating container with resource limits${NC}"
    echo -e "${PURPLE}💡 RT mengatur kuota listrik 128MB dan daya 20% untuk rumah${NC}"
    ./rt.sh create rumah-hemat --ram=128 --cpu=20
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 2: Monitoring resource usage${NC}"
    echo -e "${PURPLE}📊 RT memantau pemakaian listrik dan daya rumah${NC}"
    ./rt.sh monitor-resources rumah-hemat &
    MONITOR_PID=$!
    sleep 3
    kill $MONITOR_PID 2>/dev/null || true
    
    echo -e "\n${GREEN}Step 3: Testing memory limit${NC}"
    echo -e "${PURPLE}⚡ Mencoba memakai listrik melebihi kuota...${NC}"
    echo -e "${YELLOW}Note: This may trigger OOM killer if memory limit is enforced${NC}"
    ./rt.sh run rumah-hemat "echo 'Testing memory usage...' && sleep 2" &
    sleep 3
    
    wait
    
    echo -e "\n${GREEN}✅ Resource management demo completed!${NC}"
    echo -e "${PURPLE}🏠 Sistem pembagian resource kompleks berfungsi${NC}"
    
    # Cleanup
    ./rt.sh delete rumah-hemat
}

# Demo 5: Multi-Container Complex
demo_multi_container() {
    demo_header "Multi-Container Complex" \
                "Demonstrasi kompleks dengan beberapa rumah" \
                "Seperti RT yang mengelola kompleks perumahan lengkap"
    
    echo -e "\n${GREEN}Step 1: Building the complex${NC}"
    echo -e "${PURPLE}🏘️ RT membangun kompleks dengan 3 rumah...${NC}"
    
    ./rt.sh create rumah-jakarta --ram=512 --cpu=50
    ./rt.sh create rumah-bandung --ram=256 --cpu=25
    ./rt.sh create rumah-surabaya --ram=384 --cpu=35
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 2: Complex overview${NC}"
    echo -e "${PURPLE}📋 RT menunjukkan kondisi seluruh kompleks...${NC}"
    ./rt.sh list
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 3: Network topology${NC}"
    echo -e "${PURPLE}📞 Peta jaringan telepon kompleks...${NC}"
    ./rt.sh debug network
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 4: Resource overview${NC}"
    echo -e "${PURPLE}💡 Laporan pemakaian listrik kompleks...${NC}"
    ./rt.sh debug resources
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 5: Inter communication test${NC}"
    echo -e "${PURPLE}📞 Test komunikasi antar rumah...${NC}"
    
    # Start simple servers in background
    ./rt.sh run rumah-jakarta "echo 'Jakarta server ready' && nc -l -p 8080" &
    JAKARTA_PID=$!
    sleep 2
    
    ./rt.sh run rumah-bandung "echo 'Connecting to Jakarta...' && echo 'Hello from Bandung' | nc 10.0.0.2 8080 || echo 'Connection test completed'" &
    sleep 3
    
    # Cleanup background processes
    kill $JAKARTA_PID 2>/dev/null || true
    wait
    
    echo -e "\n${GREEN}✅ Multi complex demo completed!${NC}"
    echo -e "${PURPLE}🏠 Kompleks perumahan RT berfungsi dengan sempurna${NC}"
    
    # Cleanup
    for container in "${DEMO_CONTAINERS[@]}"; do
        ./rt.sh delete "$container" 2>/dev/null || true
    done
}

# Demo 6: Debug and Monitoring
demo_debug_monitoring() {
    demo_header "Debug and Monitoring" \
                "Demonstrasi tools debug dan monitoring" \
                "Seperti RT yang melakukan inspeksi rutin kompleks"
    
    echo -e "\n${GREEN}Step 1: System inspection${NC}"
    echo -e "${PURPLE}🔍 RT melakukan inspeksi kondisi kompleks...${NC}"
    ./rt.sh debug system
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 2: Creating test container${NC}"
    ./rt.sh create rumah-test --ram=256 --cpu=30
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 3: Container inspection${NC}"
    echo -e "${PURPLE}🏠 RT memeriksa kondisi rumah secara detail...${NC}"
    ./rt.sh debug containers
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 4: Network inspection${NC}"
    echo -e "${PURPLE}📞 RT memeriksa sistem telepon kompleks...${NC}"
    ./rt.sh debug network
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 5: Resource monitoring${NC}"
    echo -e "${PURPLE}📊 RT memantau pemakaian resource real-time...${NC}"
    ./rt.sh monitor-resources rumah-test &
    MONITOR_PID=$!
    sleep 5
    kill $MONITOR_PID 2>/dev/null || true
    
    echo -e "\n${GREEN}✅ Debug and monitoring demo completed!${NC}"
    echo -e "${PURPLE}🏠 Sistem inspeksi RT berfungsi dengan baik${NC}"
    
    # Cleanup
    ./rt.sh delete rumah-test
}

# Demo 7: Error Handling and Recovery
demo_error_recovery() {
    demo_header "Error Handling and Recovery" \
                "Demonstrasi penanganan error dan recovery" \
                "Seperti RT yang menangani masalah darurat kompleks"
    
    echo -e "\n${GREEN}Step 1: Creating test container${NC}"
    ./rt.sh create rumah-error --ram=256 --cpu=25
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 2: Simulating corruption${NC}"
    echo -e "${PURPLE}🚨 Simulasi masalah pada rumah (corrupt state)...${NC}"
    echo -e "${YELLOW}Note: This will intentionally create a problematic state${NC}"
    
    # Simulate corruption by removing PID file but keeping other state
    if [[ -f "/tmp/containers/rumah-error/container.pid" ]]; then
        rm -f "/tmp/containers/rumah-error/container.pid" 2>/dev/null || true
    fi
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 3: Detecting corruption${NC}"
    echo -e "${PURPLE}🔍 RT mendeteksi masalah pada rumah...${NC}"
    ./rt.sh recover-state || echo "Recovery detection completed"
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 4: Recovery process${NC}"
    echo -e "${PURPLE}🔧 RT melakukan perbaikan darurat...${NC}"
    ./rt.sh recover rumah-error || echo "Recovery process completed"
    sleep $DEMO_DELAY
    
    echo -e "\n${GREEN}Step 5: Verification${NC}"
    echo -e "${PURPLE}✅ RT memverifikasi hasil perbaikan...${NC}"
    ./rt.sh list
    
    echo -e "\n${GREEN}✅ Error handling and recovery demo completed!${NC}"
    echo -e "${PURPLE}🏠 Sistem darurat RT berfungsi dengan baik${NC}"
    
    # Cleanup
    ./rt.sh delete rumah-error 2>/dev/null || true
}

# Demo 8: Complete Educational Walkthrough
demo_complete_walkthrough() {
    demo_header "Complete Educational Walkthrough" \
                "Walkthrough lengkap semua fitur RT Container Runtime" \
                "Seperti tur lengkap kompleks perumahan RT"
    
    echo -e "\n${PURPLE}🎓 This is a comprehensive walkthrough of all RT features${NC}"
    echo -e "${PURPLE}   Each step will be explained with housing analogies${NC}"
    pause_demo
    
    # Run all demos in sequence
    demo_basic_lifecycle
    pause_demo "Continue to Process Isolation demo..."
    
    demo_process_isolation  
    pause_demo "Continue to Networking demo..."
    
    demo_networking
    pause_demo "Continue to Resource Management demo..."
    
    demo_resource_management
    pause_demo "Continue to Multi-Container demo..."
    
    demo_multi_container
    pause_demo "Continue to Debug & Monitoring demo..."
    
    demo_debug_monitoring
    pause_demo "Continue to Error Recovery demo..."
    
    demo_error_recovery
    
    echo -e "\n${GREEN}🎉 COMPLETE WALKTHROUGH FINISHED!${NC}"
    echo -e "${PURPLE}🏠 Anda telah melihat semua kemampuan RT Container Runtime${NC}"
    echo -e "${PURPLE}   Seperti RT yang telah menunjukkan seluruh fasilitas kompleks${NC}"
    
    echo -e "\n${BLUE}📚 NEXT LEARNING STEPS:${NC}"
    echo -e "${BLUE}   1. Read docs/ANALOGY.md for detailed explanations${NC}"
    echo -e "${BLUE}   2. Try creating your own containers manually${NC}"
    echo -e "${BLUE}   3. Experiment with different resource limits${NC}"
    echo -e "${BLUE}   4. Explore the source code in rt.sh${NC}"
    echo -e "${BLUE}   5. Run 'make test' to see the testing framework${NC}"
}

# Main demo loop
main() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1) demo_basic_lifecycle ;;
            2) demo_process_isolation ;;
            3) demo_networking ;;
            4) demo_resource_management ;;
            5) demo_multi_container ;;
            6) demo_debug_monitoring ;;
            7) demo_error_recovery ;;
            8) demo_complete_walkthrough ;;
            9) 
                echo -e "${GREEN}🧹 Cleaning up and exiting...${NC}"
                cleanup_demo
                echo -e "${BLUE}Thank you for exploring RT Container Runtime!${NC}"
                echo -e "${PURPLE}🏠 Terima kasih telah mengunjungi kompleks RT!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please select 1-9.${NC}"
                ;;
        esac
        
        pause_demo "Press Enter to return to main menu..."
    done
}

# Start the demo
main