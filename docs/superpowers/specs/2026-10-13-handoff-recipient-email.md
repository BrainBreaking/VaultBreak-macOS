# Handoff recipient email (console)

**Status:** Approved (Approach A)  
**Date:** 2026-10-13

## Goal

Optional recipient email on the macOS console **New handoff** sheet, matching web ops `/handoffs/new`. Empty = create + Copy link only; filled = also request server email send, then still show Copy link.

## Behavior

- Optional text field labeled “Recipient email” with placeholder `partner@example.com`.
- Empty / whitespace → omit `recipientEmail` from POST body.
- Non-empty invalid address → client error, no API call.
- Valid address → include `recipientEmail` in POST `/api/v1/handoffs`.
- Success: Copy link UI unchanged; if `email.sent == true`, show “Link emailed to {email}”; if recipient was set but not sent, show muted “Couldn’t email {email}” (optional reason).

## Non-goals

- Required email, separate post-create email action, server changes.
