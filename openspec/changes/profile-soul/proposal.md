# Proposal

## Why

Each Hermes profile has a SOUL.md: the text that tells the agent who it is and how to talk. It is the first thing in the system prompt. To change it today you need the web dashboard or a shell on the server. The app can already create a profile with a soul (Bot Mode) but cannot edit the one a profile has. Hermes has a plain read and write route for it, so the app can offer a small editor.

Roadmap item 4.8 ("smaller ones: SOUL editing").

## What Changes

A **Personality** screen for one profile: the profile's SOUL.md in a plain text editor, a character count, Save and Revert. Opened from a **Personality** row after Memory in the chat sidebar (drawer and More section on phones, for the chat's profile) and from a Personality section on the Mac Profiles page (for the selected profile).

- Read with `GET /api/profiles/{name}/soul`, write with `PUT /api/profiles/{name}/soul`. The profile name is in the path; neither route takes a `profile` query.
- Save asks first: it replaces the whole file, and only new chats use it.
- Before sending, the app reads the file again. If it changed on the server since the screen loaded, the user chooses between keeping their text and replacing the server's.
- Hermes has no version or etag, so this check narrows the window but cannot close it (design.md, "Conflicts").

Delivery: one PR (see tasks.md).

## Non-goals

- Editing the Bot Mode `soul` field in the Bots tab. It is the same file, written through another route; that sheet stays as it is.
- Templates, a persona gallery, AI rewriting, diff or history of earlier versions, "reset to Hermes' default text".
- Telling the user that Hermes blocked or shortened the text in a prompt. The server does not report it.
- Making a running chat pick up the change.

## Security and privacy impact

The text can hold anything the user writes. It lives only in the screen's state, is never written to preferences or drafts, never logged, never in a span or breadcrumb, and is dropped on sign-out, server change, profile switch and App Lock. No token handling changes.

## Observability

- Spans `profile_soul.fetch` and `profile_soul.save` for the two requests, with `hermes.*` server attributes.
- Log event `profile_soul.saved` for the outcome: `saved`, `conflict_kept`, `conflict_replaced`, `failed`, `unconfirmed`. Attributes: outcome, empty flag, length bucket.
- Breadcrumbs `profile_soul.opened` (source) and `profile_soul.save.confirmed`.
Fixed names, enums and buckets only: never the text, the profile name or an error body.

## Design pass

Claude Design covers, each in light and dark, at the largest text, on phone and desktop width:

- Personality screen - states: loading, loaded, file not set yet, empty file, long text (over 20,000 characters), too long to edit, offline, not found, unsaved changes, saving, saved, lost answer, wide layout.
- Save question - states: normal, empty text, with the chat-already-running note.
- Changed on the server - states: sheet or alert, server's text shown read-only.
- Discard changes question.
- Entry rows - Personality in the sidebar and the Mac Profiles section.

## Capabilities

### New Capabilities

- `profile-soul`: reading, editing and saving a profile's SOUL.md, its entry points, the confirmation, the changed-on-server check and the lost-answer behaviour.

### Modified Capabilities

None.

## Impact

- Code: `lib/src/profiles/soul/` (repository on the generated client, controller, screen, plain-model widgets), the sidebar row (`thread_sidebar.dart`, `chat_screen_navigation.dart`), `ProfileSection` and `mac_profiles_page.dart`, ARB strings (`profiles` area), Widgetbook use cases, `docs/architecture/app-shell.md`.
- Backend: no new route; both routes are in `openapi/hermes-agent.openapi.json`. No regeneration.
