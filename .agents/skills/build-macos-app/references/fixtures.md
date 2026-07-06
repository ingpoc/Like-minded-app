# Validation fixtures (`--mac-screen` deep links)

When API rows are unstable (parallel seeding, empty threads, roster order), add a **fixture layer** in `MacPrototypeData.swift` or screen-local plate maps. Active when `--mac-screen` is set and API data is empty or plate copy is required.

## Current fixtures

| Screen | Fixture | Ledger mockup | Rule |
| --- | --- | --- | --- |
| `chat` | `MacChatFixtures` | plate 05 (`mockup_ref` in ledger) | API first; fixtures for roster + jazz thread |
| `messages` | `MacMessagesFixtures` | plate 15 | Fixtures preferred on `messages` deep-link |
| `communitiesBrowse` | `communityBrowsePlate` in `MacScreens.swift` | plate 06 | Maps API ids → mockup names/order/join badges |

## Adding a new deep-link screen

1. Add fixture block if plate copy ≠ seeded API shape
2. Document in ledger `intentional_differences` / `visual_parity.notes`
3. Wire `accessibilityLabel` strings to labels in `macos_cua_screen.sh` (see `macos-cua/references/likeminded.md`)
4. Add screen to `verify_macos_screens.sh` + `macos_validation_batch.sh` screen lists if missing
