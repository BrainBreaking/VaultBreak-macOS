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

## Distribution

Prebuilt binaries are published on [GitHub Releases](https://github.com/BrainBreaking/VaultBreak-macOS/releases/latest) when available. Until the first notarized asset is uploaded, build from source or follow [docs/signing-and-notarization.md](docs/signing-and-notarization.md) to produce a signed `.dmg`/`.zip`.

The `vaultbreak` CLI opens this app when installed; if missing, it prints the releases URL above.

## Run behavior

Menu bar companion (`LSUIElement`): Keychain-backed session (shared with CLI), popover secrets, mini-console, vault lock, handoffs attention, login item, and `vaultbreak://` deep links.

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
