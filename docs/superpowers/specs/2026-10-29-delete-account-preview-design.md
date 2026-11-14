# Delete Account preview validation

## Goal

Make Delete Account completable on a throwaway member before any production delete and before any App Store resubmit.

Production `https://vault.brainbreaking.com` returns 404 for `/account/delete` and `POST /api/v1/account/deletion-authorization` because that code is uncommitted on the web repo. Vercel deploys `main`. The Mac client only talks to `https://vault.brainbreaking.com`, and it rejects non-https hosts.

## Chosen path

1. Put the web deletion work on a branch and open a pull request. Vercel builds an https preview. Linux CI does not hit the local argon2 crash.
2. Point that preview at its own database and apply `drizzle/0007_apple_identity_account_deletion.sql`. Keep `AUTH_DEV_BYPASS` off.
3. Add a Debug-only https origin override in the Mac app. Release builds stay on `https://vault.brainbreaking.com`.
4. Sign in as a throwaway member, complete Delete Account, and confirm the menu returns to signed out via `vaultbreak://account-deleted`.
5. After that click-through, merge to `main`, apply `0007` on the production database, and repeat once against `https://vault.brainbreaking.com` with a different throwaway member.

## Out of scope

- App Store Connect age rating (Parental Controls = None) and resubmitting the Mac build.
- PostgreSQL integration tests.
- A localhost web server. `argon2` crashes this Mac, and the client rejects `http://localhost`.
- Deleting an account that should be kept.

## Mac override

Debug reads `VAULTBREAK_API_BASE_URL`. The value must be an https origin with no user, path, query, or fragment. Anything else is ignored and the app uses production. The variable is compiled out of Release and ReleaseMAS. Sign-in stores the chosen origin in the Keychain session, so a production session must be logged out before a preview launch. Launch the executable directly so the variable is inherited.

## Preview safety

The preview `DATABASE_URL` must not be the production Neon database. The preview hostname must be an authorized Google redirect, because device sign-in opens that origin. `AUTH_SECRET` must be set. `ACCOUNT_DELETION_HASH_KEY` may stay unset and then falls back to `AUTH_SECRET`.
