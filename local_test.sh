#!/bin/bash

# Local Testing Script for AWS Chat RAG
# This script helps you test the application locally before deploying

set -e

echo "🚀 AWS Chat RAG - Local Testing Script"
echo "======================================"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"

# Build the Docker image
echo ""
echo "📦 Building Docker image..."
cd backend
docker build -t aws-chat-rag-local:latest .
echo -e "${GREEN}✓ Docker image built successfully${NC}"

# Run the container
echo ""
echo "🏃 Starting container on port 8000..."
docker run -d \
    --name aws-chat-rag-test \
    -p 8000:8000 \
    -e DATABASE_HOST="" \
    -e REDIS_HOST="" \
    aws-chat-rag-local:latest

echo -e "${GREEN}✓ Container started${NC}"

# Wait for the application to start
echo ""
echo "⏳ Waiting for application to start..."
sleep 3

# Test the API
echo ""
echo "🧪 Testing the /hello endpoint..."
RESPONSE=$(curl -s http://localhost:8000/hello)
if [[ $RESPONSE == *"hello"* ]]; then
    echo -e "${GREEN}✓ /hello endpoint working: $RESPONSE${NC}"
else
    echo -e "${RED}❌ /hello endpoint failed${NC}"
    docker logs aws-chat-rag-test
    docker stop aws-chat-rag-test
    docker rm aws-chat-rag-test
    exit 1
fi

# Test health endpoint
echo ""
echo "🧪 Testing the /health endpoint..."
HEALTH=$(curl -s http://localhost:8000/health)
if [[ $HEALTH == *"healthy"* ]]; then
    echo -e "${GREEN}✓ /health endpoint working: $HEALTH${NC}"
else
    echo -e "${RED}❌ /health endpoint failed${NC}"
fi

# Show logs
echo ""
echo "📋 Container logs:"
echo "=================="
docker logs aws-chat-rag-test | tail -n 10

# Instructions
echo ""
echo "======================================"
echo -e "${GREEN}✅ Local testing complete!${NC}"
echo ""
echo "Your application is running at:"
echo -e "${YELLOW}http://localhost:8000${NC}"
echo ""
echo "Test endpoints:"
echo "  • Frontend: http://localhost:8000/"
echo "  • API:      http://localhost:8000/hello"
echo "  • Health:   http://localhost:8000/health"
echo ""
echo "Commands:"
echo "  • View logs:     docker logs -f aws-chat-rag-test"
echo "  • Stop:          docker stop aws-chat-rag-test"
echo "  • Remove:        docker rm aws-chat-rag-test"
echo "  • Full cleanup:  docker stop aws-chat-rag-test && docker rm aws-chat-rag-test"
echo ""
echo "Press Ctrl+C to stop (container will keep running)"

