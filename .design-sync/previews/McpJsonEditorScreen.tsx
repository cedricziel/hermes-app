import { HermesProvider, McpJsonEditorScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const desktop = { ...phone, width: 800, height: 560 } as const;

const json = `{
  "grafana": {
    "url": "https://mcp.grafana.com/mcp",
    "auth": "oauth"
  },
  "filesystem": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-filesystem"
    ],
    "env": {
      "FS_TOKEN": "x"
    },
    "enabled": false
  }
}`;

/** iPhone: Save is the bar's trailing text button. */
export const AppleEditor = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <McpJsonEditorScreen profile="work" text={json} dirty />
    </div>
  </HermesProvider>
);

/** A parse error under the field; Save stays disabled. */
export const MaterialInvalid = () => (
  <div style={phone}>
    <McpJsonEditorScreen
      profile="work"
      text={json.replace('"auth": "oauth"', '"auth": "oauth",')}
      dirty
      invalid="Unexpected '}' at line 5"
    />
  </div>
);

/** Material desktop: the review dialog of a changed command server, Save spinning in the bar. */
export const DesktopReview = () => (
  <div style={desktop}>
    <McpJsonEditorScreen
      layout="desktop"
      profile="work"
      text={json}
      dirty
      saving
      review={[
        {
          name: "filesystem",
          command: "npx",
          args: ["-y", "@modelcontextprotocol/server-filesystem"],
          envNames: ["FS_TOKEN"],
        },
      ]}
    />
  </div>
);

export const LoadFailed = () => (
  <div style={{ ...phone, height: 420 }}>
    <McpJsonEditorScreen profile="work" state="failed" />
  </div>
);

/** Mac, dark: Save in the toolbar, Hermes' problem under the editor. */
export const Dark = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    theme="dark"
    style={{ padding: 16, borderRadius: 14 }}
  >
    <div style={{ ...desktop, width: 768, height: 520 }}>
      <McpJsonEditorScreen
        layout="desktop"
        profile="work"
        text={json}
        dirty
        problems={['"filesystem": args must be a list of strings']}
      />
    </div>
  </HermesProvider>
);
