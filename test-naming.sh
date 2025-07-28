#!/bin/bash

# Test script to demonstrate the new randomized naming
echo "Testing randomized storage account naming..."
echo ""

for i in {1..3}; do
    # Generate a random suffix to ensure unique storage account names
    TIMESTAMP=$(date +%s)
    RANDOM_NUM=$((RANDOM % 900 + 100))  # Random number between 100-999
    RANDOM_SUFFIX="${TIMESTAMP: -6}${RANDOM_NUM}"
    BASE_NAME="stgdemo${RANDOM_SUFFIX}"
    
    echo "Run $i:"
    echo "  Base name: $BASE_NAME"
    echo "  Example storage accounts:"
    echo "    ${BASE_NAME}01std"
    echo "    ${BASE_NAME}02std"
    echo "    ${BASE_NAME}06grs"
    echo "    ${BASE_NAME}16prm"
    echo ""
    
    # Small delay to ensure different timestamps
    sleep 1
done

echo "As you can see, each run generates unique names to avoid conflicts!"
