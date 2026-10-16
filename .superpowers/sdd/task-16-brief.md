# Task 16 — Signing / notarization docs + download URL

## Goal
Close M6 by documenting **Developer ID** signing, **notarytool**, and **stapling** for the macOS companion, aligning CLI **download URL** with GitHub Releases, and updating monorepo **PROJECT_MEMORY** with P0–P4 shipped status.

## Deliverables
- `docs/signing-and-notarization.md` — codesign, notarize, staple, Gatekeeper, entitlements notes (Keychain, Login Item, `vaultbreak://`)
- Release asset naming (`VaultBreak-<semver>.dmg` / zip) and **manual publish** path when no Apple credentials or no GitHub release yet
- CLI `appDownloadURL` → `https://github.com/BrainBreaking/VaultBreak-macOS/releases/latest` (verify + document)
- `VaultBreak/docs/PROJECT_MEMORY.md` — macOS companion P0–P4 complete; notarized binary may be pending
- SDD: `task-16-brief.md`, `task-16-report.md`, `progress.md` Task 16 DONE / M6 complete

## Non-goals
- Do not invent a published notarized release on GitHub without assets
- CI notarization pipeline (future)

## Commit (app repo)
`docs: signing and notarization guide`
