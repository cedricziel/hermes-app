import { HermesProvider, McpServersScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const desktop = { ...phone, width: 800, height: 560 } as const;

const servers = [
  {
    name: "grafana",
    transport: "remote" as const,
    address: "https://mcp.grafana.com/mcp",
    auth: "OAuth",
    enabled: true,
    test: {
      status: "connected" as const,
      tools: [
        {
          name: "search_dashboards",
          description: "Find dashboards by title or tag.",
          schemaChars: 320,
        },
        {
          name: "query_prometheus",
          description: "Run a PromQL query.",
          schemaChars: 1420,
        },
      ],
      prompts: 1,
    },
  },
  {
    name: "asana",
    transport: "remote" as const,
    address: "https://mcp.asana.com/sse",
    auth: "OAuth",
    enabled: true,
    test: { status: "signInNeeded" as const },
  },
  {
    name: "filesystem",
    transport: "command" as const,
    address: "npx -y @modelcontextprotocol/server-filesystem",
    enabled: false,
  },
];

/** iPhone: the inset group under "‹ Chat", the title over the profile, "+" and "…" in the bar. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <McpServersScreen layout="phone" profile="work" servers={servers} />
    </div>
  </HermesProvider>
);

/** Material phone with the "+" menu open: Browse the catalog, Add a custom server. */
export const MaterialPhone = () => (
  <div style={phone}>
    <McpServersScreen
      layout="phone"
      profile="work"
      servers={servers}
      addMenuOpen
    />
  </div>
);

/** Mac: the toolbar ("work · 3 servers"), the 380px list beside grafana's detail. */
export const Desktop = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <McpServersScreen layout="desktop" profile="work" servers={servers} />
    </div>
  </HermesProvider>
);

/** iPhone, dark: a server's own page, named in the bar, back to "MCP servers". */
export const ApplePhoneServerPage = () => (
  <HermesProvider
    platform="apple"
    theme="dark"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <McpServersScreen
        layout="phone"
        profile="work"
        servers={servers}
        openServer="grafana"
      />
    </div>
  </HermesProvider>
);

export const Empty = () => (
  <div style={phone}>
    <McpServersScreen layout="phone" profile="work" servers={[]} />
  </div>
);

export const LoadingAndFailed = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 16 }}>
    <div style={{ ...phone, width: 300, height: 400 }}>
      <McpServersScreen
        layout="phone"
        profile="work"
        servers={[]}
        state="loading"
      />
    </div>
    <div style={{ ...phone, width: 300, height: 400 }}>
      <McpServersScreen
        layout="phone"
        profile="work"
        servers={[]}
        state="failed"
      />
    </div>
  </HermesProvider>
);

/** Material desktop, dark, asana selected: its sign-in banner in the detail. */
export const DarkDesktop = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...desktop, width: 768, height: 520 }}>
      <McpServersScreen
        layout="desktop"
        profile="work"
        servers={servers}
        selected="asana"
      />
    </div>
  </HermesProvider>
);
