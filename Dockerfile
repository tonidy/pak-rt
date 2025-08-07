# Dockerfile for RT Container Runtime
# Educational container runtime that needs Linux namespaces

FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    busybox-static \
    iproute2 \
    iptables \
    util-linux \
    coreutils \
    procps \
    net-tools \
    iputils-ping \
    curl \
    jq \
    libcap2-bin \
    systemd \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /tmp/containers \
    && mkdir -p /home/rt-user/.local/share/rt

# Copy busybox to the expected location
RUN cp /bin/busybox /tmp/containers/busybox \
    && chmod +x /tmp/containers/busybox

# Create a non-root user for rootless mode
RUN useradd -m -s /bin/bash rt-user \
    && echo "rt-user:100000:65536" >> /etc/subuid \
    && echo "rt-user:100000:65536" >> /etc/subgid

# Copy the RT script
COPY rt.sh /usr/local/bin/rt.sh
RUN chmod +x /usr/local/bin/rt.sh

# Create a wrapper script for easy access
RUN echo '#!/bin/bash' > /usr/local/bin/rt \
    && echo 'exec /usr/local/bin/rt.sh "$@"' >> /usr/local/bin/rt \
    && chmod +x /usr/local/bin/rt

# Set up environment
ENV CONTAINERS_DIR=/tmp/containers
ENV BUSYBOX_PATH=/tmp/containers/busybox

# Create startup script
COPY <<EOF /usr/local/bin/start-rt.sh
#!/bin/bash
set -e

echo "🏘️  RT Container Runtime - Docker Environment"
echo "=============================================="
echo

# Check if running as root
if [[ \$EUID -eq 0 ]]; then
    echo "✅ Running as root - full features available"
    echo "💡 You can use: rt create webapp --ram=512 --cpu=50"
else
    echo "👤 Running as user - rootless mode"
    echo "💡 You can use: rt --rootless create webapp --ram=512 --cpu=50"
fi

echo
echo "📚 Available commands:"
echo "  rt help                           - Show help"
echo "  rt create <name>        - Create container"
echo "  rt list                - List all containers"
echo "  rt run <name>           - Run container"
echo "  rt delete <name>        - Delete container"
echo "  rt debug system                   - System diagnostics"
echo

# Start bash shell
exec /bin/bash
EOF

RUN chmod +x /usr/local/bin/start-rt.sh

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/usr/local/bin/start-rt.sh"]
