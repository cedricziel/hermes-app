import { Badge, HermesProvider } from "@hermes-app/ui";

const row = {
  display: "flex",
  gap: 8,
  flexWrap: "wrap",
  alignItems: "center",
} as const;

export const Tones = () => (
  <div style={row}>
    <Badge>acme</Badge>
    <Badge tone="error">P1</Badge>
    <Badge tone="success">Succeeded</Badge>
    <Badge tone="warning">Paused</Badge>
    <Badge tone="strong">Default</Badge>
  </div>
);

export const WithIcon = () => (
  <div style={row}>
    <Badge tone="success" icon="check_circle">
      Enabled
    </Badge>
    <Badge tone="error" icon="error">
      Failed
    </Badge>
    <Badge icon="schedule">Every day at 03:00</Badge>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={row}>
      <Badge>acme</Badge>
      <Badge tone="error">P2</Badge>
      <Badge tone="success">Succeeded</Badge>
      <Badge tone="warning">Paused</Badge>
      <Badge tone="strong">Default</Badge>
    </div>
  </HermesProvider>
);
