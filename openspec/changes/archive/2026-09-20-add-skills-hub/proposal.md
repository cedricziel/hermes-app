## Why

`add-skills-installed` lets the user manage the skills they already have. The other half of the dashboard's skills page is finding new ones: searching the hub, checking a skill before trusting it, installing it, and keeping hub skills up to date. Skills can run scripts on the machine the agent lives on, so this half needs the security scan in front of every install, not after.

This is the second of two changes. It needs `add-skills-installed` archived first, because it adds to the `skills` capability and the Skills page that change creates.

## What Changes

- Add the Discover tab to the Skills page (the page gains its tab bar here). It shows the featured and official skills when the search is empty, and hub search results, with a source chip row, a trust badge on every card, and "Installed" on skills the profile already has.
- Add a hub skill page: the skill's description, its file list, its rendered `SKILL.md`, and the security scan (verdict, summary, severity counts and findings) fetched when the page opens.
- Install follows the server's policy from the scan: `allow` installs after one tap, `ask` needs an explicit confirmation naming the findings, `block` disables Install and shows the reason.
- Install, uninstall and update run as background jobs on the server. A bottom sheet shows the job's log tail and result, can be sent to the background, and refreshes the Installed list when the job ends.
- Uninstall on hub skills from the detail page, and "Check for updates" / "Update all" for hub skills from the Installed tab footer.
- Mockups for these screens are in `openspec/changes/add-skills-installed/design/mockups.html` (screens 4 to 6).

**Non-goals**

- No adding or removing hub sources (taps) and no source trust settings.
- No publishing skills.
- No installing from a pasted URL or repository outside the hub's search; the search results and official catalog are the only entry points.
- No per-file selection when installing; a skill is installed as the server installs it.
- No app-side override of a `block` policy.
- No update of a single skill; the server offers only "update all".

**Security and privacy impact**

This change lets the app cause code to be installed on the user's Hermes server. Mitigations: the scan runs before Install is offered, the server's policy is followed and cannot be overridden from the app, `ask` requires an explicit confirmation that lists what the scan found, and the scan result shown is always the one fetched for the exact identifier being installed. Identifiers and search text go only to the user's own Hermes server. No new tokens or storage.

**Telemetry**

Through flutter_otel, when enabled: requests are already traced by the app's Dio interceptor. Each install, uninstall and update also logs an app event `skills.job` with attributes `op`, `source` (source id), `trust_level`, `policy` (`allow`, `ask`, `block`) and `result` (`ok`, `failed`, `unknown`). Search text, skill identifiers, names and log lines are never attached.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `skills`: adds discovering, previewing with a security scan, installing, uninstalling and updating hub skills.

## Impact

- `lib/src/skills/`: hub repository, hub controller, Discover tab, hub skill page, job sheet.
- Generated client routes already exist (`/api/skills/hub/*`, `/api/actions/{name}/status`); no spec or client regeneration. All are untyped JSON, parsed leniently.
- Contract test additions for search, official, sources, preview, scan and job status shapes.
- No native, entitlement or dependency changes.
