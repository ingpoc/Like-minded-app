#!/usr/bin/env bash

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default API URL (override with environment variable)
API_BASE_URL="${LIKEMINDED_API_BASE_URL:-http://127.0.0.1:8787}"

# Test results
PASSED=0
FAILED=0
WARNED=0

print_header() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════════════════"
}

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNED++))
}

test_api_reachable() {
    print_header "1. API Reachability"

    if curl -s --max-time 5 "${API_BASE_URL}/health" > /dev/null 2>&1; then
        print_pass "API is reachable at ${API_BASE_URL}"
        return 0
    else
        print_fail "API is not reachable at ${API_BASE_URL}"
        return 1
    fi
}

test_auth_endpoint() {
    print_header "2. Auth Endpoint"

    # Test Apple auth endpoint
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${API_BASE_URL}/v1/auth/apple" \
        -H "Content-Type: application/json" \
        -d '{"identityToken":"test-token","authorizationCode":null,"fullName":"Test User"}' 2>/dev/null || echo "")

    # Extract HTTP code (last line)
    http_code=$(echo "$response" | tail -n 1)
    # Extract body (all but last line)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "401" ] || [ "$http_code" = "400" ]; then
        print_pass "Auth endpoint responds (expected auth error for test token)"
        return 0
    elif [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        print_pass "Auth endpoint accepts requests"
        if echo "$body" | grep -q '"sessionToken"'; then
            print_pass "Auth response contains sessionToken"
        fi
        return 0
    else
        print_fail "Auth endpoint unexpected status: $http_code"
        return 1
    fi
}

test_placement_endpoint() {
    print_header "3. Placement Endpoint"

    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/me/placement" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "401" ]; then
        print_pass "Placement endpoint requires auth (expected)"
        return 0
    elif [ "$http_code" = "200" ]; then
        print_pass "Placement endpoint returns data"
        return 0
    else
        print_fail "Placement endpoint unexpected status: $http_code"
        return 1
    fi
}

test_circles_endpoint() {
    print_header "4. Circles Endpoint"

    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/circles" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        print_pass "Circles endpoint accessible"
        return 0
    else
        print_fail "Circles endpoint unexpected status: $http_code"
        return 1
    fi
}

test_communities_endpoint() {
    print_header "5. Communities Endpoint"

    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/communities" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        print_pass "Communities endpoint accessible"
        return 0
    else
        print_fail "Communities endpoint unexpected status: $http_code"
        return 1
    fi
}

test_meetings_endpoint() {
    print_header "6. Meetings Endpoint"

    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/meetings/upcoming" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        print_pass "Meetings endpoint accessible"
        return 0
    else
        print_fail "Meetings endpoint unexpected status: $http_code"
        return 1
    fi
}

test_soulmate_endpoint() {
    print_header "7. Soulmate Endpoint"

    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/me/soulmate/status" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        print_pass "Soulmate endpoint accessible"
        return 0
    else
        print_fail "Soulmate endpoint unexpected status: $http_code"
        return 1
    fi
}

test_swift_compilation() {
    print_header "8. macOS App Compilation"

    if ! command -v xcodebuild &> /dev/null; then
        print_warn "xcodebuild not available - skipping compilation test"
        return 0
    fi

    if command -v xcodegen &> /dev/null; then
        (cd /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/apps/ios-macos && xcodegen generate >/dev/null)
    fi

    if xcodebuild -project /Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/apps/ios-macos/Likeminded.xcodeproj -scheme LikemindedMac -destination 'platform=macOS' build >/tmp/likeminded-macos-build.log 2>&1; then
        print_pass "macOS app compiles successfully"
        return 0
    else
        print_fail "macOS app has compilation errors"
        return 1
    fi
}

test_mac_backend_files() {
    print_header "9. macOS Backend Files"

    backend_dir="/Users/gurusharan/Documents/remote-claude/active/apps/Like-minded-app/apps/ios-macos/Sources/LikemindedMac"

    if [ -f "${backend_dir}/MacAppState.swift" ]; then
        print_pass "MacAppState.swift exists"
    else
        print_fail "MacAppState.swift missing"
        return 1
    fi

    if [ -f "${backend_dir}/LikemindedAPIClient.swift" ]; then
        print_pass "LikemindedAPIClient.swift exists"
    else
        print_fail "LikemindedAPIClient.swift missing"
        return 1
    fi

    if [ -f "${backend_dir}/Models.swift" ]; then
        print_pass "Models.swift exists"
    else
        print_fail "Models.swift missing"
        return 1
    fi

    # Check for backend methods in MacAppState
    if grep -q "fetchCircles" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState has fetchCircles"
    else
        print_fail "MacAppState missing fetchCircles"
        return 1
    fi

    if grep -q "fetchCommunities" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState has fetchCommunities"
    else
        print_fail "MacAppState missing fetchCommunities"
        return 1
    fi

    if grep -q "fetchMeetings" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState has fetchMeetings"
    else
        print_fail "MacAppState missing fetchMeetings"
        return 1
    fi

    if grep -q "loadCurrentPlacement" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState has loadCurrentPlacement"
    else
        print_fail "MacAppState missing loadCurrentPlacement"
        return 1
    fi

    # Check for API client methods
    if grep -q "func authenticateWithApple" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null; then
        print_pass "LikemindedAPIClient has authenticateWithApple"
    else
        print_fail "LikemindedAPIClient missing authenticateWithApple"
        return 1
    fi

    if grep -q "func fetchMyPlacement" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null; then
        print_pass "LikemindedAPIClient has fetchMyPlacement"
    else
        print_fail "LikemindedAPIClient missing fetchMyPlacement"
        return 1
    fi

    return 0
}

print_summary() {
    print_header "Summary"
    echo -e "  Passed: ${GREEN}${PASSED}${NC}"
    echo -e "  Failed: ${RED}${FAILED}${NC}"
    echo -e "  Warnings: ${YELLOW}${WARNED}${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}All critical checks passed!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Start the API server: npm run dev:api:local-auth"
        echo "  2. Build the macOS app: xcodebuild -project apps/ios-macos/Likeminded.xcodeproj -scheme LikemindedMac -destination 'platform=macOS' build"
        echo "  3. Test with seeded validation data: npm run validate:macos-screens"
        return 0
    else
        echo -e "${RED}Some checks failed. Please fix the issues above.${NC}"
        return 1
    fi
}

# Run all tests
main() {
    print_header "macOS Backend Connection Verification"

    test_api_reachable || true
    test_auth_endpoint || true
    test_placement_endpoint || true
    test_circles_endpoint || true
    test_communities_endpoint || true
    test_meetings_endpoint || true
    test_soulmate_endpoint || true
    test_swift_compilation || true
    test_mac_backend_files || true

    print_summary
}

main
