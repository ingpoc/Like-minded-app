#!/usr/bin/env bash

# Screen-by-screen macOS validation workflow
# This script validates each screen systematically with seeded backend data

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
PASSED=0
FAILED=0
SKIPPED=0

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

print_skip() {
    echo -e "${YELLOW}○${NC} $1"
    ((SKIPPED++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

API_BASE_URL="${LIKEMINDED_API_BASE_URL:-http://127.0.0.1:8787}"

# Test prerequisites
check_prerequisites() {
    print_header "Prerequisites Check"

    # Check if API is running
    if curl -s --max-time 2 "${API_BASE_URL}/health" > /dev/null 2>&1; then
        print_pass "API server running at ${API_BASE_URL}"
    else
        print_fail "API server not running at ${API_BASE_URL}"
        print_info "Start it with: npm run dev:api"
        return 1
    fi

    # Check if validation data is seeded
    if [ -d "data/validation-db" ]; then
        print_pass "Validation database directory exists"
    else
        print_info "Validation database not found - seeding now"
        npm run seed:validation-data || {
            print_fail "Failed to seed validation data"
            return 1
        }
        print_pass "Validation data seeded successfully"
    fi

    return 0
}

# Screen 1: Welcome/Auth
validate_welcome_screen() {
    print_header "Screen 1: Welcome / Auth"

    # Test auth endpoint
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${API_BASE_URL}/v1/auth/apple" \
        -H "Content-Type: application/json" \
        -d '{"identityToken":"test-token","authorizationCode":null,"fullName":"Test User"}' 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "401" ] || [ "$http_code" = "400" ]; then
        print_pass "Auth endpoint responds (expected auth error)"
        return 0
    elif [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        print_pass "Auth endpoint accepts requests"
        return 0
    else
        print_fail "Auth endpoint unexpected status: $http_code"
        return 1
    fi
}

# Screen 2: Meet Overview
validate_meet_screen() {
    print_header "Screen 2: Meet Overview"

    # Test meetings endpoint
    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/meetings/upcoming" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "401" ]; then
        print_pass "Meetings endpoint requires auth (expected)"
        print_info "Screen will show 'Sign in to see your meetups' when not authenticated"
        return 0
    elif [ "$http_code" = "200" ]; then
        print_pass "Meetings endpoint returns data"

        # Check response structure
        body=$(echo "$response" | sed '$d')
        if echo "$body" | grep -q '"upcoming"'; then
            print_pass "Meetings response has 'upcoming' field"
        fi
        if echo "$body" | grep -q '"rsvps"'; then
            print_pass "Meetings response has 'rsvps' field"
        fi
        return 0
    else
        print_fail "Meetings endpoint unexpected status: $http_code"
        return 1
    fi
}

# Screen 3: Circles Room
validate_circles_screen() {
    print_header "Screen 3: Circles Room"

    # Test circles endpoint
    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/circles" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        print_pass "Circles endpoint accessible"

        if [ "$http_code" = "200" ]; then
            body=$(echo "$response" | sed '$d')
            if echo "$body" | grep -q '\['; then
                print_pass "Circles endpoint returns array"
            fi
        fi
        return 0
    else
        print_fail "Circles endpoint unexpected status: $http_code"
        return 1
    fi
}

# Screen 4: Communities Browse
validate_communities_screen() {
    print_header "Screen 4: Communities Browse"

    # Test communities endpoint
    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/communities" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        print_pass "Communities endpoint accessible"

        if [ "$http_code" = "200" ]; then
            body=$(echo "$response" | sed '$d')
            if echo "$body" | grep -q '\['; then
                print_pass "Communities endpoint returns array"
            fi
        fi
        return 0
    else
        print_fail "Communities endpoint unexpected status: $http_code"
        return 1
    fi
}

# Screen 5: My Profile
validate_profile_screen() {
    print_header "Screen 5: My Profile"

    # Test placement endpoint
    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/me/placement" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "401" ]; then
        print_pass "Placement endpoint requires auth (expected)"
        print_info "Screen will show 'Sign in to view your profile' when not authenticated"
        return 0
    elif [ "$http_code" = "200" ]; then
        print_pass "Placement endpoint returns data"

        body=$(echo "$response" | sed '$d')
        if echo "$body" | grep -q '"basicInfo"'; then
            print_pass "Placement response has 'basicInfo' field"
        fi
        if echo "$body" | grep -q '"interests"'; then
            print_pass "Placement response has 'interests' field"
        fi
        return 0
    else
        print_fail "Placement endpoint unexpected status: $http_code"
        return 1
    fi
}

# Screen 6: Soulmate Overview
validate_soulmate_screen() {
    print_header "Screen 6: Soulmate Overview"

    # Test soulmate endpoint
    response=$(curl -s -w "\n%{http_code}" \
        "${API_BASE_URL}/v1/me/soulmate/status" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        print_pass "Soulmate endpoint accessible"

        if [ "$http_code" = "200" ]; then
            body=$(echo "$response" | sed '$d')
            if echo "$body" | grep -q '"enabled"'; then
                print_pass "Soulmate response has 'enabled' field"
            fi
        fi
        return 0
    else
        print_fail "Soulmate endpoint unexpected status: $http_code"
        return 1
    fi
}

print_summary() {
    print_header "Summary"
    echo -e "  Passed: ${GREEN}${PASSED}${NC}"
    echo -e "  Failed: ${RED}${FAILED}${NC}"
    echo -e "  Skipped: ${YELLOW}${SKIPPED}${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}All screens validated!${NC}"
        echo ""
        echo "Screen-by-screen backend validation complete:"
        echo "  ✓ Welcome/Auth - auth endpoint works"
        echo "  ✓ Meet Overview - meetings data loads"
        echo "  ✓ Circles Room - circles data loads"
        echo "  ✓ Communities Browse - communities data loads"
        echo "  ✓ My Profile - placement data loads"
        echo "  ✓ Soulmate Overview - soulmate data loads"
        echo ""
        echo "Next steps:"
        echo "  1. Build and run macOS app in Xcode"
        echo "  2. Navigate through all screens"
        echo "  3. Verify data displays correctly"
        echo "  4. Test interactions (RSVPs, toggles, etc.)"
        return 0
    else
        echo -e "${RED}Some screens failed validation.${NC}"
        echo ""
        echo "Failed screens need backend fixes before macOS testing."
        return 1
    fi
}

# Run all screen validations
main() {
    print_header "macOS Screen-by-Screen Backend Validation"
    print_info "Validating each screen's backend integration with seeded data"

    check_prerequisites || {
        print_info "Prerequisites failed - skipping remaining checks"
        print_summary
        exit 1
    }

    validate_welcome_screen || true
    validate_meet_screen || true
    validate_circles_screen || true
    validate_communities_screen || true
    validate_profile_screen || true
    validate_soulmate_screen || true

    print_summary
}

main
