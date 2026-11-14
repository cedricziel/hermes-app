# Common brief: propose one feature (OpenSpec change + design brief). No app code.

You are the product and UX lead for ONE new feature of hermes-app, a Flutter client (iPhone, iPad, Mac, Android,
Windows, Linux) for the self-hosted Hermes Agent dashboard. We own only the client; the server is
NousResearch/hermes-agent and cannot be changed by us. Your output is a reviewed plan that an implementer and a
designer can execute without asking you anything: an OpenSpec change and a design brief. You write no Dart.

## Read first
- The repo's rules: CLAUDE.md (short), then docs/architecture/README.md and the area files your feature touches
  (if docs/architecture/ does not exist yet on main, the same text is in CLAUDE.md: grep it).
- docs/roadmap.md (your item), openspec/config.yaml, and 2-3 recent well-made changes under
  openspec/changes/archive/ as the pattern for proposal.md, design.md, tasks.md and specs/**/spec.md
  (e.g. the memory-proposals, bot-screen-card and agent-messages changes).
- The repo skill .claude/skills/openspec-propose/SKILL.md: follow it to create the change. The CLI runs as
  `npx -y @fission-ai/openspec@latest <cmd>`; validate with `... validate <change-name> --strict`.
- The server contract: openapi/hermes-agent.openapi.json (REST) and openrpc/hermes-gateway.openrpc.json (gateway
  JSON-RPC). And the server's SOURCE at the same pinned revision, read-only, at a clone you make yourself: `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/NousResearch/hermes-agent /home/user/nousresearch/hermes-agent`, then `git -C /home/user/nousresearch/hermes-agent fetch --depth 1 origin $(cat openapi/HERMES_REF)` and `git -C /home/user/nousresearch/hermes-agent checkout FETCH_HEAD` (the revision the app's contracts are pinned to)
  (read what the routes/methods really do, what they return, what they require, how they fail; the web dashboard's
  own UI for this feature is there too and shows what Hermes' authors think the flow is). Never copy its code.
- How the app already does similar things: find the closest existing feature (e.g. MCP servers for
  credential-entry and install flows, Plugins for lists with detail panes, Memory settings for one-key writes,
  Helper models for pickers, Kanban for a tab that exists only when the server offers it) and reuse its patterns
  and shared widgets (lib/src/widgets/settings_scaffold.dart, grouped_list.dart, adaptive_sheet.dart, the model picker).

## What the change must contain
- proposal.md: why, what changes, what is explicitly NOT in it, impact. Sized so it can ship as 2-5 reviewable PRs.
- design.md: the server surface you verified (each route/method: request, response shape with a real example from
  the server source or its tests, errors, permissions, whether it takes a `profile`), the client architecture
  (repository with lenient parsing and a sealed result type, controller, plain-model widgets, where it is reached
  from in the navigation on phone / tablet / Mac), state and failure handling, secrets handling, telemetry (fixed
  names, counts and outcomes only; never text, names, ids, URLs), how the feature is hidden on a server that lacks
  it (method-not-found / 404 must not look like an error), and open questions with your recommended answer.
- specs/<capability>/spec.md: requirements with scenarios (GIVEN/WHEN/THEN) for the happy path, every failure,
  empty/loading states, an old server, App Lock, sign-out, profile switch, and accessibility.
- tasks.md: ordered tasks, each one PR-sized, following the repo's order: repository + contract test fixtures,
  controller, Claude Design pass, Widgetbook use cases (every state, both themes, phone and desktop), screen wiring,
  workflow test, docs. Verification-on-a-device tasks are listed separately at the end.
- docs/design-briefs/<change-name>.md (new directory if needed): the brief for the visual design pass. For each
  screen and state: purpose, the content hierarchy (what the user must see first), the components to reuse from the
  app's existing kit, the exact copy for titles, labels, helper text, errors and empty states (plain words, sentence
  case, no jargon the server uses internally unless the user typed it), primary and destructive actions, and the
  differences between iPhone, iPad/desktop width, and Mac.

## UX bar (the owner's instruction: the best Hermes app, easy to use, real UI best practice)
- Start from the user's job, not the API: say in one sentence per screen what the person is trying to get done and
  cut anything that does not serve it. Prefer one obvious primary action per screen.
- Progressive disclosure: sensible defaults first, advanced options behind a clear "Advanced"/detail step.
- Every state designed: loading (skeleton or progress with a label), empty (what this is, why it is empty, the one
  action that fills it), partial failure, full failure with a way forward, offline, old server, permission denied.
- Platform conventions: Apple HIG on iOS/iPadOS/macOS (navigation, sheets vs popovers vs inspectors, toolbars,
  destructive actions in red and confirmed, swipe actions, pull to refresh only where it fits), Material 3 on
  Android, pointer and keyboard on desktop (shortcuts, focus order, hover). No mobile bottom sheets on the Mac.
- Accessibility is a requirement, not a task: 44 pt / 48 dp targets, text scales to the largest accessibility size
  without truncating meaning, WCAG AA contrast in both themes, screen-reader labels and order, no meaning carried
  by colour alone, reduced motion respected.
- Safety: anything that restarts, deletes, spends money, exposes a secret or runs something on the server asks
  first, says exactly what will happen, and can be cancelled; secrets are masked, never logged, never stored on the
  device beyond the request, and never shown in notifications, widgets or the app switcher.
- Honest feedback: optimistic UI only with rollback; a lost answer is "may have happened" and is re-read, never
  resent; long operations show progress and survive leaving the screen.

## Rules
- Git: plain single commands, stage files by name. `git fetch origin main`, `git switch -c <branch> origin/main`.
  Commit with a Conventional Commit message (`docs(openspec): propose <feature>`), ending with:
  Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01NoPuyiKA3rH1r4cTVmK6ce
- Touch only openspec/changes/<your change>/** and docs/design-briefs/<your change>.md.
- Do not run Flutter. Do not write Dart. Never write a model name anywhere.
- Push (`git push -u origin <branch>`) and open a ready PR against main with `mcp__github__create_pull_request`
  (owner cedricziel, repo hermes-app; load with ToolSearch `select:mcp__github__create_pull_request`). Body:
  `## Summary`, `## Server surface verified` (routes/methods and where in the Hermes source you read them),
  `## Open questions` (with your recommendation), ending with:
  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  https://claude.ai/code/session_01NoPuyiKA3rH1r4cTVmK6ce
- Hierarchy and models: you are a sub-orchestrator. Have subagents on a cheaper model do the reading and drafting
  (Agent tool, model "sonnet" to read the Hermes source for a route group and report request/response/error shapes
  with file references, and to draft spec scenarios; model "haiku" for lookups). You decide the product and UX, check
  their findings against the source yourself where it matters, and own the documents.
- Review: before you report, start ONE isolated reviewer subagent with fresh context (model "sonnet"; give it only the
  branch name and what the change claims). It checks every server claim in design.md against the Hermes source and
  the contracts, that every state has a scenario, that the copy is plain, and that nothing needs a server change.
  Fix what it confirms; record findings and responses under `## Review` in the PR body.
- Run `npx -y @fission-ai/openspec@latest validate <change-name> --strict` and make it pass.
- Do not merge, comment, or enable auto-merge.
- You are fully autonomous: no questions to a human; decide and record the decision under "Open questions".
- Report to the orchestrator with `mcp__claude-code-remote__send_message` (session_id
  `session_01NoPuyiKA3rH1r4cTVmK6ce`) when the PR is up, validated and reviewed, or if you are blocked. Then stop.
- Final report (short): PR number, the change name, the 2-5 implementation PRs you planned, anything in the server
  that makes the feature harder than the roadmap assumed, and the open questions.
