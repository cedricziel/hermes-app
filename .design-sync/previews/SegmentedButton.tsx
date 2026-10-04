import { HermesProvider, SegmentedButton, TextField } from "@hermes-app/ui";

const form = {
  width: 420,
  display: "flex",
  flexDirection: "column",
  gap: 12,
} as const;

/** The Add server form: server type, then authentication. */
export const Material = () => (
  <div style={form}>
    <SegmentedButton
      label="Server type"
      labels={["Remote (URL)", "Command"]}
      value={0}
    />
    <TextField label="URL" value="https://mcp.example.com/mcp" readOnly />
    <SegmentedButton
      label="Authentication"
      labels={["None", "Bearer token", "OAuth"]}
      value={1}
    />
  </div>
);

/** Apple: the app draws the same Material control on iOS and macOS. */
export const Apple = () => (
  <HermesProvider platform="apple">
    <div style={form}>
      <SegmentedButton
        label="Server type"
        labels={["Remote (URL)", "Command"]}
        value={1}
      />
    </div>
  </HermesProvider>
);

/** Read-only while the request runs. */
export const Disabled = () => (
  <div style={form}>
    <SegmentedButton
      label="Authentication"
      labels={["None", "Bearer token", "OAuth"]}
      value={2}
      disabled
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={form}>
      <SegmentedButton
        label="Server type"
        labels={["Remote (URL)", "Command"]}
        value={0}
      />
      <SegmentedButton
        label="Authentication"
        labels={["None", "Bearer token", "OAuth"]}
        value={2}
      />
    </div>
  </HermesProvider>
);
