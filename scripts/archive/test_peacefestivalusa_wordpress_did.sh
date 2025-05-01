#!/bin/bash
# Test script for Peace Festival USA WordPress in Docker-in-Docker environment
# This follows the AgencyStack TDD Protocol with test-first development
# Validates Docker-in-Docker compliance

set -e

# Source common utilities if available
if [ -f "$(dirname "$0")/../utils/common.sh" ]; then
    source "$(dirname "$0")/../utils/common.sh"
fi

# Client-specific variables
CLIENT_ID="peacefestivalusa"
DOMAIN="${DOMAIN:-peacefestivalusa.nerdofmouth.com}"
CONTAINER_NAME="${CLIENT_ID}_wordpress"
DATABASE_CONTAINER="${CLIENT_ID}_mariadb"
WP_PORT=8082

echo "=== Peace Festival USA WordPress Docker-in-Docker TDD Test Suite ==="
echo "Domain: $DOMAIN"
echo "Client ID: $CLIENT_ID"
echo "Container: $CONTAINER_NAME"
echo ""

# Utility function to validate Docker-in-Docker environment
check_docker_in_docker() {
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker-in-Docker is available"
        return 0
    else
        echo "❌ Docker-in-Docker is not available"
        return 1
    fi
}

# Run tests in a structured format
run_tests() {
    echo "🚀 Starting Peace Festival USA WordPress Docker-in-Docker Test Suite..."
    echo "--------------------------------------------------"
    
    # Phase 1: Environment Tests
    echo "📋 Running Environment Tests..."
    
    # Test 1: Verify Docker-in-Docker environment
    echo "🧪 Test 1: Docker-in-Docker environment"
    if check_docker_in_docker; then
        echo "✅ PASS: Docker-in-Docker environment is available"
    else
        echo "❌ FAIL: Docker-in-Docker environment is not available"
        return 1
    fi
    
    # Test 2: Verify directory structure exists
    echo "🧪 Test 2: Directory structure"
    if [ -d "$HOME/.agencystack/clients/$CLIENT_ID/wordpress" ]; then
        echo "✅ PASS: Directory structure exists ($HOME/.agencystack/clients/$CLIENT_ID/wordpress)"
    else
        echo "❌ FAIL: Directory structure does not exist ($HOME/.agencystack/clients/$CLIENT_ID/wordpress)"
        return 1
    fi
    
    echo "✅ Environment Tests: PASSED"
    echo "--------------------------------------------------"
    
    # Phase 2: Container Tests
    echo "📋 Running Container Tests..."
    
    # Test 3: WordPress container exists
    echo "🧪 Test 3: WordPress container exists"
    if docker ps --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
        echo "✅ PASS: WordPress container exists"
    else
        echo "❌ FAIL: WordPress container does not exist"
        return 1
    fi
    
    # Test 4: Database container exists
    echo "🧪 Test 4: Database container exists"
    if docker ps --format '{{.Names}}' | grep -q "$DATABASE_CONTAINER"; then
        echo "✅ PASS: Database container exists"
    else
        echo "❌ FAIL: Database container does not exist"
        return 1
    fi
    
    # Test 5: Network configuration
    echo "🧪 Test 5: Docker network exists"
    if docker network ls | grep -q "${CLIENT_ID}_network"; then
        echo "✅ PASS: Docker network exists"
    else
        echo "❌ FAIL: Docker network does not exist"
        return 1
    fi
    
    echo "✅ Container Tests: PASSED"
    echo "--------------------------------------------------"
    
    # Phase 3: WordPress Accessibility Tests
    echo "📋 Running Accessibility Tests..."
    
    # Test 6: WordPress HTTP response (localhost)
    echo "🧪 Test 6: WordPress HTTP response"
    echo "   Waiting for WordPress to become accessible (this may take up to 30 seconds)..."
    MAX_TRIES=15
    counter=0
    HTTP_STATUS="000"
    
    while [ $counter -lt $MAX_TRIES ]; do
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${WP_PORT}" 2>/dev/null || echo "000")
        echo "   Attempt $((counter+1))/$MAX_TRIES - HTTP Status: $HTTP_STATUS"
        
        if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "302" || "$HTTP_STATUS" == "301" ]]; then
            break
        fi
        
        counter=$((counter+1))
        sleep 2
    done
    
    if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "302" || "$HTTP_STATUS" == "301" ]]; then
        echo "✅ PASS: WordPress is accessible via HTTP"
    else
        echo "❌ FAIL: WordPress is not accessible via HTTP (Status: $HTTP_STATUS)"
        echo "   Displaying WordPress container logs for troubleshooting:"
        docker logs "${CONTAINER_NAME}" | tail -15
        return 1
    fi
    
    echo "✅ Accessibility Tests: PASSED"
    echo "--------------------------------------------------"
    
    echo "🎉 All tests passed! Peace Festival USA WordPress is properly deployed in Docker-in-Docker"
    return 0
}

# Main test execution
if run_tests; then
    echo ""
    echo "✅ TEST SUITE PASSED: Peace Festival USA WordPress Docker-in-Docker deployment"
    exit 0
else
    echo ""
    echo "❌ TEST SUITE FAILED: Peace Festival USA WordPress Docker-in-Docker deployment"
    exit 1
fi
