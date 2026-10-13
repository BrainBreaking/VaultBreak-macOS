# VaultBreak (macOS)

Menu bar companion for [VaultBreak](https://github.com/BrainBreaking/VaultBreak). Handles OAuth callbacks via the `vaultbreak://` URL scheme and (in later tasks) keychain-backed session state shared with the `vaultbreak` CLI.

## Requirements

- macOS 13 or later
- Xcode 15+ (Swift 5.9)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the project from `project.yml`
- `vaultbreak` CLI installed and signed in (`vaultbreak login`)

## Open and build

```bash
cd /path/to/VaultBreak-macOS
xcodegen generate   # if VaultBreak.xcodeproj is missing or project.yml changed
open VaultBreak.xcodeproj
```

In Xcode: select the **VaultBreak** scheme, **My Mac**, then **Product → Run** (⌘R).

Or from the command line:

```bash
xcodebuild -scheme VaultBreak -destination 'platform=macOS' build
```

## Run behavior (scaffold)

This repo is a **Task 6 scaffold**: a menu bar agent (`LSUIElement`) with a placeholder panel showing **Signed out**. Full keychain integration and deep links are implemented in later SDD tasks.

Before using the app with the CLI, authenticate:

```bash
vaultbreak login
```

## Project layout

| Path | Purpose |
|------|---------|
| `project.yml` | XcodeGen spec (bundle `com.brainbreaking.vaultbreak`, URL scheme `vaultbreak`) |
| `VaultBreak/` | SwiftUI app sources |
| `VaultBreak.xcodeproj` | Generated — do not hand-edit; regenerate with `xcodegen generate` |

## License

Same as the VaultBreak monorepo / org policy — see BrainBreaking repositories.
