#!/bin/bash

# Helper script untuk menjalankan RT Container Runtime di Docker
# Author: RT Development Team

set -euo pipefail

# Colors for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'

show_help() {
    echo -e "${COLOR_BLUE}🏘️  RT Container Runtime - Docker Helper${COLOR_RESET}"
    echo -e "${COLOR_BLUE}=======================================${COLOR_RESET}\n"
    
    echo -e "${COLOR_GREEN}📚 AVAILABLE MODES:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── dev      : Full privileged development environment${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── rootless : Rootless mode demonstration${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── build    : Build Docker images${COLOR_RESET}"
    echo -e "${COLOR_GREEN}├── clean    : Clean up containers and volumes${COLOR_RESET}"
    echo -e "${COLOR_GREEN}└── logs     : Show container logs${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}💡 USAGE EXAMPLES:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}# Start development environment${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}$0 dev${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}# Start rootless mode${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}$0 rootless${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}# Build images${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}$0 build${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}# Clean everything${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}$0 clean${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}🔧 INSIDE CONTAINER:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}# Create container (privileged mode)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}./rt.sh create webapp${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}# Create container (rootless mode)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}./rt.sh --rootless create webapp${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}# List containers${COLOR_RESET}"
    echo -e "${COLOR_CYAN}./rt.sh list${COLOR_RESET}\n"
    
    echo -e "${COLOR_PURPLE}🏘️  Seperti RT yang menyediakan berbagai cara untuk mengelola kompleks!${COLOR_RESET}\n"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${COLOR_RED}❌ Docker is not installed or not in PATH${COLOR_RESET}"
        echo -e "${COLOR_RED}Please install Docker first: https://docs.docker.com/get-docker/${COLOR_RESET}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${COLOR_RED}❌ Docker daemon is not running${COLOR_RESET}"
        echo -e "${COLOR_RED}Please start Docker daemon first${COLOR_RESET}"
        exit 1
    fi
}

check_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${COLOR_RED}❌ Docker Compose is not available${COLOR_RESET}"
        echo -e "${COLOR_RED}Please install Docker Compose${COLOR_RESET}"
        exit 1
    fi
    
    # Use docker compose if available, fallback to docker-compose
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
}

run_dev_mode() {
    echo -e "${COLOR_GREEN}🚀 Starting RT Container Runtime - Development Mode${COLOR_RESET}"
    echo -e "${COLOR_GREEN}This will start a privileged container with full RT capabilities${COLOR_RESET}\n"
    
    $COMPOSE_CMD up -d rt-dev
    echo -e "\n${COLOR_CYAN}📋 Container started! Connecting to shell...${COLOR_RESET}"
    $COMPOSE_CMD exec rt-dev /bin/bash
}

run_rootless_mode() {
    echo -e "${COLOR_GREEN}🚀 Starting RT Container Runtime - Rootless Mode${COLOR_RESET}"
    echo -e "${COLOR_GREEN}This will demonstrate rootless container capabilities${COLOR_RESET}\n"
    
    $COMPOSE_CMD up -d rt-rootless
    echo -e "\n${COLOR_CYAN}📋 Container started! Connecting to shell...${COLOR_RESET}"
    $COMPOSE_CMD exec rt-rootless /bin/bash
}

build_images() {
    echo -e "${COLOR_GREEN}🔨 Building RT Container Runtime Docker images${COLOR_RESET}\n"
    
    $COMPOSE_CMD build --no-cache
    
    echo -e "\n${COLOR_GREEN}✅ Build completed!${COLOR_RESET}"
    echo -e "${COLOR_GREEN}You can now run: $0 dev or $0 rootless${COLOR_RESET}"
}

show_logs() {
    local service=${1:-""}
    
    if [[ -n "$service" ]]; then
        echo -e "${COLOR_CYAN}📋 Showing logs for service: $service${COLOR_RESET}\n"
        $COMPOSE_CMD logs -f "$service"
    else
        echo -e "${COLOR_CYAN}📋 Showing logs for all services${COLOR_RESET}\n"
        $COMPOSE_CMD logs -f
    fi
}

clean_all() {
    echo -e "${COLOR_YELLOW}🧹 Cleaning up RT Container Runtime Docker environment${COLOR_RESET}\n"
    
    echo -e "${COLOR_YELLOW}Stopping containers...${COLOR_RESET}"
    $COMPOSE_CMD down
    
    echo -e "${COLOR_YELLOW}Removing volumes...${COLOR_RESET}"
    $COMPOSE_CMD down -v
    
    echo -e "${COLOR_YELLOW}Removing images...${COLOR_RESET}"
    docker rmi $(docker images -q pak-rt*) 2>/dev/null || true
    
    echo -e "\n${COLOR_GREEN}✅ Cleanup completed!${COLOR_RESET}"
}

main() {
    local command=${1:-"help"}
    
    case "$command" in
        "help"|"-h"|"--help")
            show_help
            ;;
        "dev"|"development")
            check_docker
            check_compose
            run_dev_mode
            ;;
        "rootless")
            check_docker
            check_compose
            run_rootless_mode
            ;;
        "build")
            check_docker
            check_compose
            build_images
            ;;
        "logs")
            check_docker
            check_compose
            show_logs "${2:-}"
            ;;
        "clean"|"cleanup")
            check_docker
            check_compose
            clean_all
            ;;
        *)
            echo -e "${COLOR_RED}❌ Unknown command: $command${COLOR_RESET}\n"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
