# RT Container Runtime - Makefile untuk macOS Development
# Requires Docker dan Docker Compose untuk Linux environment

.PHONY: help setup dev test test-unit test-integration clean

# Default target
help:
	@echo "RT Container Runtime - Development Commands"
	@echo ""
	@echo "🏗️  SETUP COMMANDS:"
	@echo "  make setup           - Setup development environment"
	@echo "  make dev            - Start interactive development container"
	@echo "  make clean          - Cleanup containers dan volumes"
	@echo ""
	@echo "🧪 TESTING COMMANDS:"
	@echo "  make test           - Run all tests dalam Linux container"
	@echo "  make test-unit      - Run unit tests only"
	@echo "  make test-integration - Run integration tests only"
	@echo "  make test-components - Run component tests (busybox, namespace, cgroup, network)"
	@echo "  make test-stress    - Run stress tests"
	@echo "  make test-resources - Run resource validation tests"
	@echo "  make test-cleanup   - Run cleanup verification tests"
	@echo ""
	@echo "🔧 SPECIFIC COMPONENT TESTS:"
	@echo "  make test-busybox   - Run busybox management tests"
	@echo "  make test-namespace - Run namespace management tests"
	@echo "  make test-cgroup    - Run cgroup management tests"
	@echo "  make test-network   - Run network management tests"
	@echo ""
	@echo "ℹ️  OTHER COMMANDS:"
	@echo "  make help           - Show this help message"
	@echo ""
	@echo "📋 Requirements:"
	@echo "  - Docker Desktop untuk macOS"
	@echo "  - Docker Compose"
	@echo ""
	@echo "🏠 Seperti RT yang menyediakan berbagai perintah untuk mengelola kompleks"

# Check if Docker is available
check-docker:
	@which docker > /dev/null || (echo "Error: Docker tidak ditemukan. Install Docker Desktop untuk macOS dari https://docker.com/products/docker-desktop" && exit 1)
	@which docker-compose > /dev/null || (echo "Error: Docker Compose tidak ditemukan. Install Docker Compose atau gunakan Docker Desktop" && exit 1)
	@docker info > /dev/null 2>&1 || (echo "Error: Docker daemon tidak running. Start Docker Desktop" && exit 1)

# Setup development environment
setup: check-docker
	@echo "🏗️  Setting up RT development environment..."
	@docker-compose build rt-dev
	@echo "✅ Development environment ready!"
	@echo "Run 'make dev' untuk start development container"

# Start interactive development container
dev: check-docker
	@echo "🚀 Starting RT development container..."
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

# Run stress tests
test-stress: check-docker
	@echo "💪 Running stress tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/stress-tests.sh"

# Run resource validation tests
test-resources: check-docker
	@echo "📊 Running resource validation tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/resource-validation-tests.sh"

# Run cleanup verification tests
test-cleanup: check-docker
	@echo "🧹 Running cleanup verification tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/cleanup-verification-tests.sh"

# Run network tests
test-network: check-docker
	@echo "🌐 Running network tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/network-tests.sh"

# Run cgroup tests
test-cgroup: check-docker
	@echo "⚡ Running cgroup tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/cgroup-tests.sh"

# Run namespace tests
test-namespace: check-docker
	@echo "🏠 Running namespace tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/namespace-tests.sh"

# Run busybox tests
test-busybox: check-docker
	@echo "📦 Running busybox tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/busybox-tests.sh"

# Run component tests
test-components: check-docker
	@echo "🔧 Running component tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/busybox-tests.sh && ./tests/namespace-tests.sh && ./tests/cgroup-tests.sh && ./tests/network-tests.sh"

# Run stress tests
test-stress: check-docker
	@echo "💪 Running stress tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/stress-tests.sh"

# Run resource validation tests
test-resources: check-docker
	@echo "📊 Running resource validation tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/resource-validation-tests.sh"

# Run cleanup verification tests
test-cleanup: check-docker
	@echo "🧹 Running cleanup verification tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/cleanup-verification-tests.sh"

# Run specific component tests
test-busybox: check-docker
	@echo "📦 Running busybox tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/busybox-tests.sh"

test-namespace: check-docker
	@echo "🏠 Running namespace tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/namespace-tests.sh"

test-cgroup: check-docker
	@echo "⚡ Running cgroup tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/cgroup-tests.sh"

test-network: check-docker
	@echo "🌐 Running network tests..."
	@docker-compose run --rm rt-dev bash -c "cd /workspace && ./tests/network-tests.sh"

# Cleanup containers dan volumes
clean: check-docker
	@echo "🧹 Cleaning up development environment..."
	@docker-compose down -v --remove-orphans
	@docker system prune -f
	@echo "✅ Cleanup complete!"

# Development shortcuts
shell: dev
build: setup