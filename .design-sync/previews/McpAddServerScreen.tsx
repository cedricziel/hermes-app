import { HermesProvider, McpAddServerScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const desktop = { ...phone, width: 800, height: 560 } as const;

/** Apple phone: a remote server with a bearer token. */
export const AppleRemote = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <McpAddServerScreen
        profile="work"
        name="linear"
        url="https://mcp.linear.app/sse"
        auth="bearer"
        token="lin_api_xxxxxxxx"
      />
    </div>
  </HermesProvider>
);

/** Material phone: a command server with an invalid variable name. */
export const MaterialCommand = () => (
  <div style={phone}>
    <McpAddServerScreen
      profile="work"
      kind="command"
      name="notes-fs"
      command="npx"
      args={"-y\n@modelcontextprotocol/server-filesystem\n/srv/notes"}
      env={[
        { name: "FS_TOKEN", value: "secret" },
        {
          name: "2FA",
          value: "",
          error:
            "Use letters, digits and underscores, not starting with a digit",
        },
      ]}
    />
  </div>
);

/** Phone: the review sheet before a command server is sent. */
export const PhoneReview = () => (
  <div style={phone}>
    <McpAddServerScreen
      profile="work"
      kind="command"
      name="notes-fs"
      command="npx"
      args={"-y\n@modelcontextprotocol/server-filesystem"}
      env={[{ name: "FS_TOKEN", value: "secret" }]}
      saving
      review={{
        name: "notes-fs",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem"],
        envNames: ["FS_TOKEN"],
      }}
    />
  </div>
);

/** Desktop: the 560px form, OAuth picked, name taken and Hermes' refusal. */
export const Desktop = () => (
  <div style={desktop}>
    <McpAddServerScreen
      layout="desktop"
      profile="work"
      name="grafana"
      nameTaken
      url="https://mcp.grafana.com/mcp"
      auth="oauth"
      error="Could not add grafana"
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={phone}>
      <McpAddServerScreen profile="work" name="docs" url="ftp://docs" />
    </div>
  </HermesProvider>
);
