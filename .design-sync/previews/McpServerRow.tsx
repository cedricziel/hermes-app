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

const platformLabel = { padding: "8px 16px 0" } as const;

/** Material (top) and Apple (bottom) switches, on and off: 52x32 with a growing thumb vs the 51x31 toggle. */
export const PlatformSwitch = () => {
  const grafana = {
    name: "grafana",
    transport: "remote" as const,
    address: "https://mcp.grafana.com/mcp",
    auth: "OAuth",
    enabled: true,
  };
  const asana = {
    ...grafana,
    name: "asana",
    address: "https://mcp.asana.com/sse",
    enabled: false,
  };
  return (
    <div style={pane}>
      <div className="h-label-sm h-muted" style={platformLabel}>
        Material
      </div>
      <McpServerRow server={grafana} />
      <McpServerRow server={asana} />
      <HermesProvider platform="apple">
        <div className="h-label-sm h-muted" style={platformLabel}>
          Apple
        </div>
        <McpServerRow server={grafana} />
        <McpServerRow server={asana} />
      </HermesProvider>
    </div>
  );
};

const grafana = {
  name: "grafana",
  transport: "remote" as const,
  address: "https://mcp.grafana.com/mcp",
  auth: "OAuth",
  enabled: true,
};
const notes = {
  name: "notes-fs",
  transport: "command" as const,
  address: "npx -y @modelcontextprotocol/server-filesystem /srv/notes",
  enabled: false,
};

/** iPhone: grafana swiped from the trailing edge shows Remove in red. */
export const AppleSwipe = () => (
  <HermesProvider platform="apple" style={{ width: 390 }}>
    <McpServerRow
      server={grafana}
      test={{ ok: true, toolCount: 4 }}
      swipeRevealed
    />
    <McpServerRow server={notes} />
  </HermesProvider>
);

/** iPhone: a long press opens Turn off and Remove in an action sheet. */
export const AppleActionSheet = () => (
  <HermesProvider
    platform="apple"
    style={{
      position: "relative",
      width: 390,
      height: 400,
      overflow: "hidden",
      borderRadius: 14,
    }}
  >
    <McpServerRow server={grafana} actionSheetOpen />
    <McpServerRow server={notes} />
  </HermesProvider>
);

export const AppleSwipeDark = () => (
  <HermesProvider platform="apple" theme="dark" style={{ width: 390 }}>
    <McpServerRow server={grafana} />
    <McpServerRow server={notes} swipeRevealed />
  </HermesProvider>
);
