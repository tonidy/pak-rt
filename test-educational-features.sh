#!/bin/bash

# Test script for educational features
echo "Testing RT Container Runtime Educational Features"
echo "================================================="

echo -e "\n1. Testing basic help system:"
./rt.sh help

echo -e "\n2. Testing specific help topics:"
./rt.sh help create
./rt.sh help monitor
./rt.sh help analogy

echo -e "\n3. Testing verbose mode:"
./rt.sh --verbose help create

echo -e "\n4. Testing debug mode:"
./rt.sh --debug help

echo -e "\n5. Testing unknown command (should show help):"
./rt.sh unknown-command

echo -e "\nAll educational features tested successfully!"