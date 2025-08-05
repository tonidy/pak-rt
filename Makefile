# Pak RT Container Runtime - Makefile untuk macOS Development
# Requires Docker dan Docker Compose untuk Linux environment

.PHONY: help setup dev test test-unit test-integration clean

# Default target
help:
	@echo "Pak RT Container Runtime - Development Commands"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup           - Setup development environment"
	@echo "  make dev            - Start interactive development container"
	@echo "  make test           - Run all tests dalam Linux container"
	@echo "  make test-unit      - Run unit tests only"
	@echo "  make test-integration - Run integration tests only"
	@echo "  make clean          - Cleanup containers dan volumes"
	@echo "  make help           - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - Docker Desktop untuk macOS"
	@echo "  - Docker Compose"

# Check if Docker is available
check-docker:
	@which docker > /dev/null || (echo "Error: Docker tidak ditemukan. Install Docker Desktop untuk macOS dari https://docker.com/products/docker-desktop" && exit 1)
	@which docker-compose > /dev/null || (echo "Error: Docker Compose tidak ditemukan. Install Docker Compose atau gunakan Docker Desktop" && exit 1)
	@docker info > /dev/null 2>&1 || (echo "Error: Docker daemon tidak running. Start Docker Desktop" && exit 1)

# Setup development environment
setup: check-docker
	@echo "🏗️  Setting up Pak RT development environment..."
	@docker-compose build rt-dev
	@echo "✅ Development environment ready!"
	@echo "Run 'make dev' untuk start development container"

# Start interactive development container
dev: check-docker
	@echo "🚀 Starting Pak RT development container..."
	@echo "📝 Code directory mounted ke /workspace"
	@echo "🔧 Privileged mode enabled untuk namespace operations"
	@docker-compose run --rm rt-dev

# Run all tests dalam Linux container
test: check-docker
	@echo "🧪 Running all tests dalam Linux environment..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/run-all-tests.sh"

# Run unit tests only
test-unit: check-docker
	@echo "🔬 Running unit tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/unit-tests.sh"

# Run integration tests only
test-integration: check-docker
	@echo "🔗 Running integration tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/integration-tests.sh"

# Cleanup containers dan volumes
clean: check-docker
	@echo "🧹 Cleaning up development environment..."
	@docker-compose down -v --remove-orphans
	@docker system prune -f
	@echo "✅ Cleanup complete!"

# Development shortcuts
shell: dev
build: setup