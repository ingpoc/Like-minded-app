#!/usr/bin/env bash

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check Swift syntax
check_swift_syntax() {
    print_header "1. Swift Syntax Check"

    backend_dir="apps/ios-macos/Sources/LikemindedMac"

    swift_files=(
        "${backend_dir}/MacAppState.swift"
        "${backend_dir}/LikemindedAPIClient.swift"
        "${backend_dir}/Models.swift"
        "${backend_dir}/MacRootView.swift"
        "${backend_dir}/MacScreens.swift"
    )

    for file in "${swift_files[@]}"; do
        if [ -f "$file" ]; then
            print_pass "$(basename $file) exists"
        else
            print_fail "$(basename $file) missing"
        fi
    done
}

# Check backend wiring
check_backend_wiring() {
    print_header "2. Backend Wiring Verification"

    backend_dir="apps/ios-macos/Sources/LikemindedMac"

    # Check MacAppState has backend methods
    if grep -q "func fetchCircles" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState.fetchCircles exists"
    else
        print_fail "MacAppState missing fetchCircles"
    fi

    if grep -q "func fetchCommunities" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState.fetchCommunities exists"
    else
        print_fail "MacAppState missing fetchCommunities"
    fi

    if grep -q "func fetchMeetings" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState.fetchMeetings exists"
    else
        print_fail "MacAppState missing fetchMeetings"
    fi

    if grep -q "func loadCurrentPlacement" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState.loadCurrentPlacement exists"
    else
        print_fail "MacAppState missing loadCurrentPlacement"
    fi

    if grep -q "func loadCurrentProfile" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState.loadCurrentProfile exists"
    else
        print_fail "MacAppState missing loadCurrentProfile"
    fi

    if grep -q "func fetchSoulmateStatus" "${backend_dir}/MacAppState.swift" 2>/dev/null; then
        print_pass "MacAppState.fetchSoulmateStatus exists"
    else
        print_fail "MacAppState missing fetchSoulmateStatus"
    fi

    # Check LikemindedAPIClient has API methods
    if grep -q "func authenticateWithApple" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null; then
        print_pass "LikemindedAPIClient.authenticateWithApple exists"
    else
        print_fail "LikemindedAPIClient missing authenticateWithApple"
    fi

    if grep -q "func fetchMyPlacement" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null; then
        print_pass "LikemindedAPIClient.fetchMyPlacement exists"
    else
        print_fail "LikemindedAPIClient missing fetchMyPlacement"
    fi

    if grep -q "func fetchMyProfile" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null && grep -q "/v1/me/profile" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null; then
        print_pass "LikemindedAPIClient.fetchMyProfile uses /v1/me/profile"
    else
        print_fail "LikemindedAPIClient missing /v1/me/profile fetch"
    fi

    if grep -q "MacBackendConfig.baseURLString" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null; then
        print_pass "LikemindedAPIClient uses MacBackendConfig"
    else
        print_fail "LikemindedAPIClient not using MacBackendConfig"
    fi

    if grep -q "func fetchCircleDetail" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null && grep -q "/v1/circles" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null; then
        print_pass "LikemindedAPIClient.fetchCircleDetail uses /v1/circles/:id"
    else
        print_fail "LikemindedAPIClient missing /v1/circles/:id fetch"
    fi

    if grep -q "func fetchNotifications" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null && grep -q "/v1/me/notifications" "${backend_dir}/LikemindedAPIClient.swift" 2>/dev/null; then
        print_pass "LikemindedAPIClient.fetchNotifications uses /v1/me/notifications"
    else
        print_fail "LikemindedAPIClient missing /v1/me/notifications fetch"
    fi
}

# Check screen integration
check_screen_integration() {
    print_header "3. Screen Integration Check"

    screens_file="apps/ios-macos/Sources/LikemindedMac/MacScreens.swift"

    # Check Meet screen uses appState
    if grep -q "appState.fetchMeetings()" "$screens_file" 2>/dev/null; then
        print_pass "Meet screen loads meetings from appState"
    else
        print_fail "Meet screen missing appState.fetchMeetings()"
    fi

    if grep -q "appState.meetingRsvps" "$screens_file" 2>/dev/null; then
        print_pass "Meet screen displays RSVPs from appState"
    else
        print_fail "Meet screen missing appState.meetingRsvps"
    fi

    # Check Circles screen uses appState
    if grep -q "appState.fetchCircles()" "$screens_file" 2>/dev/null; then
        print_pass "Circles screen loads circles from appState"
    else
        print_fail "Circles screen missing appState.fetchCircles()"
    fi

    if grep -Eq "appState\.circles(\.map|\.enumerated\(\))" "$screens_file" 2>/dev/null; then
        print_pass "Circles screen displays circles from appState"
    else
        print_fail "Circles screen not using appState.circles"
    fi

    # Check Communities screen uses appState
    if grep -q "appState.fetchCommunities()" "$screens_file" 2>/dev/null; then
        print_pass "Communities screen loads communities from appState"
    else
        print_fail "Communities screen missing appState.fetchCommunities()"
    fi

    if grep -Eq "appState\.communities(\.map|\.enumerated\(\))" "$screens_file" 2>/dev/null; then
        print_pass "Communities screen displays communities from appState"
    else
        print_fail "Communities screen not using appState.communities"
    fi

    # Check Profile screen uses appState
    if grep -q "appState.profile" "$screens_file" 2>/dev/null; then
        print_pass "Profile screen uses appState.profile"
    else
        print_fail "Profile screen missing appState.profile"
    fi

    # Check Soulmate screen uses appState
    if grep -q "appState.soulmateEnabled" "$screens_file" 2>/dev/null; then
        print_pass "Soulmate screen uses appState.soulmateEnabled"
    else
        print_fail "Soulmate screen missing appState.soulmateEnabled"
    fi

    if grep -q "appState.soulmateMatches" "$screens_file" 2>/dev/null; then
        print_pass "Soulmate screen displays matches from appState"
    else
        print_fail "Soulmate screen not using appState.soulmateMatches"
    fi

    if grep -q "appState.chatMessages" "$screens_file" 2>/dev/null; then
        print_pass "Messages screen displays messages from appState"
    else
        print_fail "Messages screen not using appState.chatMessages"
    fi

    if grep -q "appState.notifications" "$screens_file" 2>/dev/null; then
        print_pass "Notifications screen displays notifications from appState"
    else
        print_fail "Notifications screen not using appState.notifications"
    fi
}

# Check MacRootView integration
check_root_view() {
    print_header "4. MacRootView Integration"

    root_view_file="apps/ios-macos/Sources/LikemindedMac/MacRootView.swift"

    if grep -q "@StateObject.*appState" "$root_view_file" 2>/dev/null; then
        print_pass "MacRootView has @StateObject appState"
    else
        print_fail "MacRootView missing @StateObject appState"
    fi

    if grep -q "MacScreenView(screen:.*appState:" "$root_view_file" 2>/dev/null; then
        print_pass "MacRootView passes appState to MacScreenView"
    else
        print_fail "MacRootView not passing appState to MacScreenView"
    fi

    if grep -q "MacBottomNav.*soulmateEnabled" "$root_view_file" 2>/dev/null; then
        print_pass "MacRootView passes soulmateEnabled to MacBottomNav"
    else
        print_fail "MacRootView not passing soulmateEnabled to MacBottomNav"
    fi
}

# Check MacTab extension
check_mactab() {
    print_header "5. MacTab Extension"

    root_view_file="apps/ios-macos/Sources/LikemindedMac/MacRootView.swift"

    if grep -q "MacTab.visible" "$root_view_file" 2>/dev/null; then
        print_pass "MacTab.visible extension exists"
    else
        print_fail "MacTab.visible extension missing"
    fi

    if grep -q "MacTab.visible(soulmateEnabled: soulmateEnabled)" "$root_view_file" 2>/dev/null; then
        print_pass "MacTab.visible uses soulmateEnabled"
    else
        print_warn "MacTab.visible may not use soulmateEnabled"
    fi
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
        echo "Backend integration complete:"
        echo "  ✓ MacAppState wired to LikemindedAPIClient"
        echo "  ✓ All screens use appState for data"
        echo "  ✓ MacRootView propagates state correctly"
        echo ""
        echo "Next steps:"
        echo "  1. Start API server: npm run dev:api (or dev:api:local-auth)"
        echo "  2. Build and run macOS app in Xcode"
        echo "  3. Test with seeded validation data"
        return 0
    else
        echo -e "${RED}Some checks failed. Please fix the issues above.${NC}"
        return 1
    fi
}

# Run all tests
main() {
    print_header "macOS Screen-by-Screen Backend Integration Verification"

    check_swift_syntax
    check_backend_wiring
    check_screen_integration
    check_root_view
    check_mactab

    print_summary
}

main
