# Palette and type

The iOS and Mac apps use the shared `LikemindedPalette` for semantic colors. The iOS light `accentSoft` and room-gradient values intentionally changed as part of UI-13; the iOS palette is unified with Mac by design. The iOS Apple sign-in button is intentionally black per Apple's Human Interface Guidelines, replacing the earlier green treatment.

Visible text uses `LikemindedTypography` tokens. Keep Mac text at 14 pt or larger and iOS text at 13 pt or larger; the tab bar label is the sole iOS exception. Compact labels use the platform-aware `compact` token.

Appearance supports System, Light, and Dark through `@AppStorage("likeminded.appearance")`.
