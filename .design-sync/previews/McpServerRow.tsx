import { HermesProvider, McpServerRow } from "@hermes-app/ui";

const pane = { width: 380 } as const;

export const List = () => (
  <div style={pane}>
    <McpServerRow
      server={{
        name: "grafana",
        transport: "remote",
        address: "https://mcp.grafana.com/mcp",
        auth: "OAuth",
        enabled: true,
      }}
      test={{ ok: true, toolCount: 4 }}
    />
    <McpServerRow
      selected
      server={{
        name: "asana",
        transport: "remote",
        address: "https://mcp.asana.com/sse",
        auth: "OAuth",
        enabled: true,
      }}
      test={{ signInNeeded: true }}
    />
    <McpServerRow
      server={{
        name: "flaky",
        transport: "remote",
        address: "https://flaky.example/mcp",
        enabled: true,
      }}
    />
  </div>
);

export const CommandServers = () => (
  <div style={pane}>
    <McpServerRow
      server={{
        name: "notes-fs",
        transport: "command",
        address: "npx -y @modelcontextprotocol/server-filesystem /srv/my notes",
        enabled: true,
      }}
      test={{ ok: true, toolCount: 1 }}
    />
    <McpServerRow
      server={{
        name: "filesystem",
        transport: "command",
        address: "uvx mcp-server-filesystem",
        enabled: false,
      }}
    />
  </div>
);

export const LongNameAndSwitching = () => (
  <div style={pane}>
    <McpServerRow
      switching
      server={{
        name: "a-really-long-server-name-that-keeps-going-on",
        transport: "remote",
        address:
          "https://mcp.internal.example-corp.com/tenants/engineering/platform/observability/v2/streamable-http-endpoint",
        auth: "OAuth",
        enabled: true,
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <McpServerRow
        server={{
          name: "grafana",
          transport: "remote",
          address: "https://mcp.grafana.com/mcp",
          auth: "OAuth",
          enabled: true,
        }}
        test={{ ok: true, toolCount: 4 }}
      />
      <McpServerRow
        selected
        server={{
          name: "asana",
          transport: "remote",
          address: "https://mcp.asana.com/sse",
          auth: "OAuth",
          enabled: true,
        }}
        test={{ signInNeeded: true }}
      />
      <McpServerRow
        server={{
          name: "filesystem",
          transport: "command",
          address: "uvx mcp-server-filesystem",
          enabled: false,
        }}
      />
    </div>
  </HermesProvider>
);

/** Material (top) and Apple (bottom) enabled switches: 52x32 with a growing thumb vs the 51x31 toggle. */
export const PlatformSwitch = () => {
  const server = {
    name: "grafana",
    transport: "remote" as const,
    address: "https://mcp.grafana.com/mcp",
    auth: "OAuth",
    enabled: true,
  };
  return (
    <div style={pane}>
      <McpServerRow server={server} />
      <McpServerRow server={{ ...server, name: "asana", enabled: false }} />
      <HermesProvider platform="apple">
        <McpServerRow server={server} />
        <McpServerRow server={{ ...server, name: "asana", enabled: false }} />
      </HermesProvider>
    </div>
  );
};
