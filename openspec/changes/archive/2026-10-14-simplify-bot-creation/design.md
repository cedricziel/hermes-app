## Context

Creation currently uses profiles.create followed by a revision-checked profiles.configure for Bot Mode metadata. The shell's existing bot-open callback resolves and opens the canonical chat without changing the CLI default profile.

## Goals / Non-Goals

Goals: short initial form, optional model selection, accurate credential copy, immediate chat navigation, and safe partial retries.

Non-goals: cloning, empty profiles, avatar pipelines, capability configuration, or automatic introductions.

## Decisions

Extract plain creation fields for Widgetbook. Reuse GroupedDialog with a form-action footer, GroupedTextFieldRow, GroupedValueRow, and GroupedSwitchRow. The form uses the same platform-specific widths, grouped surfaces, row metrics, labelled fields, and explanatory footers as settings. Existing settings dialogs keep their Done action when no custom actions are supplied. Use the accessible DisclosureTile for Advanced and reuse the shared model picker with reasoning effort disabled. A null selection leaves model/provider absent in profiles.create; the picker offers a return to the inherited default. Load available models from the current connection before the profile exists. Show load failures in the form and keep basic creation available.

Keep a single-flight saving state and disable cancellation and field edits during submission. Retain the created name when metadata saving fails and retry metadata only. Persist both title and roster description. After success, close the dialog, reload the roster, and invoke the existing onOpen callback with the freshly saved bot. Navigation failures remain recoverable from the roster through the shell's existing error path.

Upstream introduction research: [canonical-chat.ts](https://github.com/NousResearch/hermes-agent/blob/main/apps/desktop/src/plugins/hermes-bots/canonical-chat.ts) uses createCanonicalChat with kickoff=true only for new agents. It opens the canonical session and submits a localized user prompt through prompt.submit, generating a real model turn. This pass opens the chat without adding that prompt.

Platforms: iOS, Android, macOS, Windows, Linux. watchOS unchanged. No native entitlement, manifest, or Xcode changes. Auth and secure-storage invariants remain unchanged; REST model options use the generated client. No new spans, log events, or breadcrumbs.

## Risks / Trade-offs

API key mirroring does not imply copied OAuth authentication. Unavailable model options must not block basic creation. Metadata save failure must not recreate the profile. Introduction parity remains a separate decision because it adds a user-attributed model turn.

## Verification

Creation and canonical-chat regressions: 28 tests passed. Creation catalog: 72 cases passed across Apple and Material platforms, light and dark themes, and phone and desktop viewports. Four workflow screenshot cases passed with explicit iOS and macOS themes. Formatting, flutter analyze, and strict OpenSpec validation passed.

Live macOS check used an isolated dashboard home and redirected profile command aliases after runtime bootstrap. Creating creation-smoke opened its canonical Bot Chat with the saved friendly title. Its session database contained Bot Chat and zero messages, confirming no automatic introduction turn. Temporary processes were stopped after verification. No model response was exercised because the throwaway profile had no provider credentials.

The grouped-layout revision passed 85 creation, workflow, and catalog checks and 43 existing grouped-row and settings-dialog checks. Updated iOS and macOS workflow renders were inspected in both themes; the form uses the settings dialog's 460-point Mac surface and persistent field labels. Formatting and analysis passed. Backend creation and chat-opening contracts are unchanged.
