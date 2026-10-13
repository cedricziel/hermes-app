## Why

The MCP catalog still presents installation details as a mobile bottom sheet in a compact macOS window. It needs the shared desktop dialog policy while retaining its installation workflow.

## What Changes

- Open compact macOS catalog installation details through the shared adaptive modal helper.
- Reuse the existing panel, success and disappearance callbacks, mobile sheet options, wide pane, and busy dismissal behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `mcp-catalog`: Present compact macOS installation details as desktop dialogs.

## Impact

Only McpCatalogScreen's install modal caller and focused presentation tests change. No API, dependency, credential handling, or minimum Hermes version changes are required. Existing catalog cases are reused. The React McpCatalogScreen counterpart needs a design port in a separate design slice.

Non-goals: installed-server navigation, wide panes, controller authorization or session retention, new install behavior, and changing native projects.

Security and privacy: None. Credentials still live only in the panel fields and existing install requests; no storage or telemetry content changes.

Observability: None added. This presentation change adds no operation or user action beyond existing MCP behavior.
