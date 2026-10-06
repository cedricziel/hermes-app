import { HermesProvider, Tag } from "@hermes-app/ui";

const row = {
  display: "flex",
  flexWrap: "wrap",
  gap: "4px 6px",
  alignItems: "center",
} as const;

/** The plugin tags: muted outline, strong outline, solid, and a commit in monospace. */
export const PluginTags = () => (
  <div style={row}>
    <Tag>Bundled</Tag>
    <Tag>Disabled</Tag>
    <Tag variant="strong">Needs login</Tag>
    <Tag variant="strong">Removed: unsafe network call</Tag>
    <Tag variant="filled">Official</Tag>
    <Tag variant="filled">Enabled</Tag>
    <Tag mono>a3f9c21</Tag>
  </div>
);

/** The MCP facts: tinted pills, and the orange "Sign in needed". */
export const McpTags = () => (
  <div style={row}>
    <Tag variant="tinted">Remote</Tag>
    <Tag variant="tinted">OAuth</Tag>
    <Tag variant="tinted">4 tools</Tag>
    <Tag variant="tinted">Builds locally</Tag>
    <Tag variant="warning">Sign in needed</Tag>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...row, marginBottom: 8 }}>
      <Tag>Bundled</Tag>
      <Tag variant="strong">Needs login</Tag>
      <Tag variant="filled">Ready</Tag>
      <Tag mono>search_dashboards</Tag>
    </div>
    <div style={row}>
      <Tag variant="tinted">Command</Tag>
      <Tag variant="tinted">Off</Tag>
      <Tag variant="warning">Sign in needed</Tag>
    </div>
  </HermesProvider>
);
