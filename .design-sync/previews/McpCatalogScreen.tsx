import { HermesProvider, McpCatalogScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const desktop = { ...phone, width: 800, height: 560 } as const;

const entries = [
  {
    name: "airtable",
    description: "Read and write Airtable bases.",
    source: "github.com/airtable/mcp",
    transport: "remote" as const,
    auth: "API key",
    url: "https://mcp.airtable.com/mcp",
    credentials: [
      { name: "AIRTABLE_API_KEY", prompt: "Personal access token" },
    ],
  },
  {
    name: "buildkite",
    description: "Pipelines and builds.",
    transport: "command" as const,
    auth: "No auth",
    command: "node",
    args: ["dist/index.js", "--stdio"],
    repository: "https://github.com/buildkite/mcp-server",
    ref: "v1.2.0",
    buildSteps: ["npm ci", "npm run build"],
  },
  {
    name: "grafana",
    description: "Dashboards and metrics.",
    transport: "remote" as const,
    auth: "OAuth",
    url: "https://mcp.grafana.com/mcp",
    installed: true,
  },
  {
    name: "context7",
    description: "Up-to-date library docs.",
    transport: "remote" as const,
    auth: "No auth",
    url: "https://mcp.context7.com/mcp",
  },
];

export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <McpCatalogScreen layout="phone" profile="work" entries={entries} />
    </div>
  </HermesProvider>
);

/** Phone: an entry opens its install panel in a bottom sheet. */
export const MaterialPhoneSheet = () => (
  <div style={phone}>
    <McpCatalogScreen
      layout="phone"
      profile="work"
      entries={entries}
      sheetEntry="context7"
    />
  </div>
);

/** Desktop: the install panel of an entry built on the server, building. */
export const DesktopBuilding = () => (
  <div style={desktop}>
    <McpCatalogScreen
      layout="desktop"
      profile="work"
      entries={entries}
      selected="buildkite"
      building={["buildkite"]}
      install={{ state: "building" }}
    />
  </div>
);

/** Filtered to Command with a search that matches nothing. */
export const NoMatch = () => (
  <div style={phone}>
    <McpCatalogScreen
      layout="phone"
      profile="work"
      entries={entries}
      filter="Command"
      query="calendar"
    />
  </div>
);

export const Failed = () => (
  <div style={{ ...phone, height: 420 }}>
    <McpCatalogScreen layout="phone" entries={[]} state="failed" />
  </div>
);

export const DarkDesktop = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...desktop, width: 768, height: 520 }}>
      <McpCatalogScreen
        layout="desktop"
        profile="work"
        entries={entries}
        selected="airtable"
        hasDiagnostics
      />
    </div>
  </HermesProvider>
);
