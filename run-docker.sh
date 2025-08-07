#!/bin/bash

# RT Container Runtime - Docker Runner
# Script untuk menjalankan RT Container Runtime di dalam Docker container

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

# Function to show usage
show_usage() {
    echo -e "${COLOR_BLUE}🏘️  RT Container Runtime - Docker Runner${COLOR_RESET}"
    echo -e "${COLOR_BLUE}===========================================${COLOR_RESET}"
    echo
    echo -e "${COLOR_GREEN}USAGE:${COLOR_RESET}"
    echo -e "  $0 [MODE] [ACTION]"
    echo
    echo -e "${COLOR_YELLOW}MODES:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}dev${COLOR_RESET}      : Development mode (privileged, full features)"
    echo -e "  ${COLOR_CYAN}rootless${COLOR_RESET} : Rootless mode (non-privileged, limited features)"
    echo
    echo -e "${COLOR_YELLOW}ACTIONS:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}start${COLOR_RESET}    : Start and enter the container"
    echo -e "  ${COLOR_CYAN}build${COLOR_RESET}    : Build the Docker image"
    echo -e "  ${COLOR_CYAN}stop${COLOR_RESET}     : Stop the container"
    echo -e "  ${COLOR_CYAN}clean${COLOR_RESET}    : Clean up containers and images"
    echo -e "  ${COLOR_CYAN}logs${COLOR_RESET}     : Show container logs"
    echo -e "  ${COLOR_CYAN}exec${COLOR_RESET}     : Execute command in running container"
    echo
    echo -e "${COLOR_YELLOW}EXAMPLES:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}# Start development environment${COLOR_RESET}"
    echo -e "  $0 dev start"
    echo
    echo -e "  ${COLOR_GREEN}# Start rootless environment${COLOR_RESET}"
    echo -e "  $0 rootless start"
    echo
    echo -e "  ${COLOR_GREEN}# Build Docker image${COLOR_RESET}"
    echo -e "  $0 dev build"
    echo
    echo -e "  ${COLOR_GREEN}# Execute RT command in container${COLOR_RESET}"
    echo -e "  $0 dev exec ./rt.sh create webapp"
    echo
    echo -e "${COLOR_YELLOW}QUICK START:${COLOR_RESET}"
    echo -e "  1. $0 dev build     # Build the image"
    echo -e "  2. $0 dev start     # Start container"
    echo -e "  3. Inside container: ./rt.sh create webapp"
    echo
}

# Function to check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${COLOR_RED}❌ Error: Docker not found${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}💡 Please install Docker first${COLOR_RESET}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${COLOR_RED}❌ Error: Docker daemon not running${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}💡 Please start Docker daemon${COLOR_RESET}"
        exit 1
    fi
}

# Function to check if docker-compose is available
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        echo -e "${COLOR_RED}❌ Error: docker-compose not found${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}💡 Please install docker-compose${COLOR_RESET}"
        exit 1
    fi
}

# Function to build Docker image
build_image() {
    local mode=$1
    
    echo -e "${COLOR_BLUE}🔨 Building Docker image for $mode mode...${COLOR_RESET}"
    
    cd "$SCRIPT_DIR"
    
    case "$mode" in
        dev)
            $COMPOSE_CMD build rt-dev
            ;;
        rootless)
            $COMPOSE_CMD build rt-rootless
            ;;
        *)
            echo -e "${COLOR_RED}❌ Invalid mode: $mode${COLOR_RESET}"
            exit 1
            ;;
    esac
    
    echo -e "${COLOR_GREEN}✅ Docker image built successfully${COLOR_RESET}"
}

# Function to start container
start_container() {
    local mode=$1
    
    echo -e "${COLOR_BLUE}🚀 Starting RT Container Runtime in $mode mode...${COLOR_RESET}"
    
    cd "$SCRIPT_DIR"
    
    case "$mode" in
        dev)
            $COMPOSE_CMD up -d rt-dev
            echo -e "${COLOR_GREEN}✅ Development container started${COLOR_RESET}"
            echo -e "${COLOR_CYAN}💡 Entering container...${COLOR_RESET}"
            $COMPOSE_CMD exec rt-dev /bin/bash
            ;;
        rootless)
            $COMPOSE_CMD up -d rt-rootless
            echo -e "${COLOR_GREEN}✅ Rootless container started${COLOR_RESET}"
            echo -e "${COLOR_CYAN}💡 Entering container...${COLOR_RESET}"
            $COMPOSE_CMD exec rt-rootless /bin/bash
            ;;
        *)
            echo -e "${COLOR_RED}❌ Invalid mode: $mode${COLOR_RESET}"
            exit 1
            ;;
    esac
}

# Function to stop container
stop_container() {
    local mode=$1
    
    echo -e "${COLOR_YELLOW}🛑 Stopping $mode container...${COLOR_RESET}"
    
    cd "$SCRIPT_DIR"
    
    case "$mode" in
        dev)
            $COMPOSE_CMD stop rt-dev
            ;;
        rootless)
            $COMPOSE_CMD stop rt-rootless
            ;;
        all)
            $COMPOSE_CMD stop
            ;;
        *)
            echo -e "${COLOR_RED}❌ Invalid mode: $mode${COLOR_RESET}"
            exit 1
            ;;
    esac
    
    echo -e "${COLOR_GREEN}✅ Container stopped${COLOR_RESET}"
}

# Function to clean up
clean_up() {
    echo -e "${COLOR_YELLOW}🧹 Cleaning up Docker resources...${COLOR_RESET}"
    
    cd "$SCRIPT_DIR"
    
    # Stop and remove containers
    $COMPOSE_CMD down -v
    
    # Remove images
    docker rmi $(docker images -q -f "reference=pak-rt*") 2>/dev/null || true
    
    echo -e "${COLOR_GREEN}✅ Cleanup completed${COLOR_RESET}"
}

# Function to show logs
show_logs() {
    local mode=$1
    
    cd "$SCRIPT_DIR"
    
    case "$mode" in
        dev)
            $COMPOSE_CMD logs -f rt-dev
            ;;
        rootless)
            $COMPOSE_CMD logs -f rt-rootless
            ;;
        *)
            echo -e "${COLOR_RED}❌ Invalid mode: $mode${COLOR_RESET}"
            exit 1
            ;;
    esac
}

# Function to execute command in container
exec_command() {
    local mode=$1
    shift
    local command="$*"
    
    cd "$SCRIPT_DIR"
    
    case "$mode" in
        dev)
            $COMPOSE_CMD exec rt-dev bash -c "$command"
            ;;
        rootless)
            $COMPOSE_CMD exec rt-rootless bash -c "$command"
            ;;
        *)
            echo -e "${COLOR_RED}❌ Invalid mode: $mode${COLOR_RESET}"
            exit 1
            ;;
    esac
}

# Main function
main() {
    # Check prerequisites
    check_docker
    check_docker_compose
    
    # If no arguments, show usage
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi
    
    local mode=$1
    local action=${2:-"start"}
    
    # Validate mode
    case "$mode" in
        dev|rootless)
            ;;
        help|--help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${COLOR_RED}❌ Invalid mode: $mode${COLOR_RESET}"
            show_usage
            exit 1
            ;;
    esac
    
    # Execute action
    case "$action" in
        start)
            start_container "$mode"
            ;;
        build)
            build_image "$mode"
            ;;
        stop)
            stop_container "$mode"
            ;;
        clean)
            clean_up
            ;;
        logs)
            show_logs "$mode"
            ;;
        exec)
            shift 2
            exec_command "$mode" "$@"
            ;;
        *)
            echo -e "${COLOR_RED}❌ Invalid action: $action${COLOR_RESET}"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
