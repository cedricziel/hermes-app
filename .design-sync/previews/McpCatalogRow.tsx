import { HermesProvider, McpCatalogRow } from "@hermes-app/ui";

const pane = { width: 380 } as const;

const entries = [
  {
    name: "airtable",
    description: "Read and write Airtable bases.",
    transport: "remote" as const,
    auth: "API key",
  },
  {
    name: "buildkite",
    description: "Pipelines and builds.",
    transport: "command" as const,
    auth: "No auth",
    repository: "https://github.com/buildkite/mcp-server",
  },
  {
    name: "grafana",
    description: "Dashboards and metrics.",
    transport: "remote" as const,
    auth: "OAuth",
    installed: true,
  },
];

export const List = () => (
  <div style={pane}>
    {entries.map((e) => (
      <McpCatalogRow key={e.name} entry={e} selected={e.name === "airtable"} />
    ))}
  </div>
);

/** A build running on the server, and a long description clamped to two lines. */
export const BuildingAndLong = () => (
  <div style={pane}>
    <McpCatalogRow entry={entries[1]} building />
    <McpCatalogRow
      entry={{
        name: "context7",
        description:
          "Up-to-date library docs for any package: fetches the current README, API reference and examples straight from the source instead of stale training data.",
        transport: "remote",
        auth: "No auth",
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      {entries.map((e) => (
        <McpCatalogRow key={e.name} entry={e} selected={e.name === "grafana"} />
      ))}
    </div>
  </HermesProvider>
);
