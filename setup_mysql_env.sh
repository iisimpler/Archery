#!/bin/bash
# MySQL Environment Setup Script for macOS (Intel)
# This script sets up environment variables needed to compile mysqlclient

echo "Setting up MySQL environment variables..."

# Set PKG_CONFIG_PATH for mysql-client
export PKG_CONFIG_PATH="/usr/local/opt/mysql-client/lib/pkgconfig:$PKG_CONFIG_PATH"

# Optional: Add mysql-client to PATH if needed
export PATH="/usr/local/opt/mysql-client/bin:$PATH"

# Verify setup
echo "Verifying MySQL environment setup..."
if pkg-config --exists mysqlclient; then
    echo "✅ pkg-config can find mysqlclient"
    echo "   CFLAGS: $(pkg-config --cflags mysqlclient)"
    echo "   LIBS: $(pkg-config --libs mysqlclient)"
else
    echo "❌ pkg-config cannot find mysqlclient"
    exit 1
fi

echo "✅ MySQL environment setup complete!" 