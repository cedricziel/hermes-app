import {
  Badge,
  Button,
  Card,
  HermesProvider,
  Icon,
  IconButton,
  ListDetailLayout,
  McpServerRow,
  PluginRow,
} from "@hermes-app/ui";

const frame = {
  width: 800,
  height: 560,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const note = (
  <div
    className="h-body-sm"
    style={{ display: "flex", gap: 8, padding: "8px 16px" }}
  >
    <Icon name="info" size={16} />
    <span>
      Changes apply from the next chat, not to one that is already running.
    </span>
  </div>
);

const mcpActions = (
  <>
    <Button variant="text" icon="add">
      Add
    </Button>
    <IconButton icon="more_vert" label="More" />
  </>
);

const mcpList = (
  <>
    {note}
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
    <McpServerRow
      server={{
        name: "notes-fs",
        transport: "command",
        address: "npx -y @modelcontextprotocol/server-filesystem /srv/my notes",
        enabled: true,
      }}
    />
    <McpServerRow
      server={{
        name: "filesystem",
        transport: "command",
        address: "uvx mcp-server-filesystem",
        enabled: false,
      }}
    />
  </>
);

const mcpDetail = (
  <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
    <div>
      <div className="h-title-lg" style={{ fontWeight: 400 }}>
        asana
      </div>
      <div className="h-body-sm" style={{ marginTop: 4 }}>
        Remote · OAuth
      </div>
      <div className="h-body-md" style={{ marginTop: 12 }}>
        https://mcp.asana.com/sse
      </div>
    </div>
    <Card>
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <div style={{ flex: 1 }}>
          <div className="h-body-lg">Enabled</div>
          <div className="h-body-md">Used from the next chat</div>
        </div>
        <Badge tone="strong">On</Badge>
      </div>
    </Card>
    <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
      <Button variant="outlined" icon="check" fullWidth>
        Test connection
      </Button>
      <IconButton icon="delete" label="Remove server" variant="outlined" />
    </div>
    <Card tinted>
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <Icon name="lock" size={18} color="var(--h-warning)" />
        <div style={{ flex: 1 }}>
          <div className="h-title-sm">Sign in needed</div>
          <div className="h-body-md">
            Hermes has no OAuth token for this server yet, so it cannot list
            tools.
          </div>
        </div>
        <Button variant="text" icon="login">
          Sign in
        </Button>
      </div>
    </Card>
  </div>
);

export const McpServers = () => (
  <div style={frame}>
    <ListDetailLayout
      title="MCP servers"
      subtitle="Profile: work"
      actions={mcpActions}
      listWidth={340}
      list={mcpList}
      detail={mcpDetail}
    />
  </div>
);

const divider = { height: 1, background: "var(--h-border)" } as const;

export const PluginsWithTabs = () => (
  <div style={frame}>
    <ListDetailLayout
      title="Plugins"
      tabs={["Installed", "Catalog", "Providers"]}
      activeTab={0}
      listWidth={340}
      placeholder="Select a plugin"
      list={
        <>
          <PluginRow
            plugin={{
              name: "netbox",
              version: "1.0.0",
              description:
                "Query and update NetBox from the agent: look up devices, prefixes, VLANs and cables.",
              authRequired: true,
              status: "enabled",
            }}
          />
          <div style={divider} />
          <PluginRow
            plugin={{
              name: "kanban",
              version: "1.0.0",
              description: "About kanban",
              bundled: true,
              status: "enabled",
            }}
          />
          <div style={divider} />
          <PluginRow
            plugin={{
              name: "gmail-triage",
              version: "1.0.0",
              description: "About gmail-triage",
              status: "disabled",
            }}
          />
        </>
      }
    />
  </div>
);

export const PhoneList = () => (
  <div style={{ ...frame, width: 390, height: 560 }}>
    <ListDetailLayout
      layout="list"
      title="MCP servers"
      subtitle="Profile: work"
      onBack={() => {}}
      actions={mcpActions}
      list={mcpList}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={frame}>
      <ListDetailLayout
        title="MCP servers"
        subtitle="Profile: work"
        actions={mcpActions}
        listWidth={340}
        list={mcpList}
        detail={mcpDetail}
      />
    </div>
  </HermesProvider>
);
