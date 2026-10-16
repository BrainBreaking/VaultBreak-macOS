# Task 16 report — signing, notarization, and distribution URL

## Summary
Added operator documentation for Developer ID signing, notarization, stapling, and GitHub Releases publishing. Confirmed CLI `appDownloadURL` targets `BrainBreaking/VaultBreak-macOS` **releases/latest** (no published release assets yet — manual upload required). Updated VaultBreak monorepo PROJECT_MEMORY for macOS companion P0–P4.

## Files
| Path | Change |
|------|--------|
| `docs/signing-and-notarization.md` | New — full signing/notarization/release checklist |
| `.superpowers/sdd/task-16-brief.md` | Task brief |
| `.superpowers/sdd/task-16-report.md` | This report |
| `.superpowers/sdd/progress.md` | Task 16 DONE; M6 complete |
| `README.md` | Distribution + signing doc link (if updated) |

## GitHub Releases
- Remote: `git@github.com:BrainBreaking/VaultBreak-macOS.git`
- **No releases** at task time — use `/releases/latest` as stable CLI pointer
- Expected first assets: `VaultBreak-<version>.dmg`, optional `VaultBreak-<version>-macOS.zip`

## CLI worktree
- Branch: `feat/macos-desktop-keychain`
- `internal/cmd/app.go`: `appDownloadURL` already set to releases/latest; comment documents expected asset names
- `go test ./...` — see commit SHA in CLI repo

## Monorepo
- `VaultBreak/docs/PROJECT_MEMORY.md` — macOS section moved from “Planned” to shipped P0–P4 + distribution docs

## Tests
- macOS: existing suite (55 tests at Task 15) unchanged by docs-only task
- CLI: `go test ./...` in worktree

## Commits
| Repo | SHA | Message |
|------|-----|---------|
| VaultBreak-macOS | `641aeb71f810fb10893c34017aa196e0b3532892` | docs: signing and notarization guide |
| vaultbreak-cli (worktree) | `b8bee10c74775fd93b48a89aba73dbd9dac0bdad` | chore(cli): point app download URL at VaultBreak-macOS releases |
| VaultBreak | `730be6226dc60e133a06b50af8b8e592423de2c8` | docs: PROJECT_MEMORY macOS companion P0-P4 status |

## Manual follow-up
- First notarized `.dmg`/`.zip` upload to GitHub Releases
- Optional: add `VaultBreak.entitlements` to XcodeGen and wire in `project.yml` for repeatable CI signing
