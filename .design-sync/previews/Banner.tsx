import { Banner, Button, HermesProvider } from "@hermes-app/ui";

const column = {
  width: 460,
  display: "flex",
  flexDirection: "column",
  gap: 12,
} as const;

export const Tones = () => (
  <div style={column}>
    <Banner
      tone="success"
      icon="check_circle"
      title="Connected"
      detail="4 tools · 1 prompt · 0 resources"
    />
    <Banner
      tone="warning"
      icon="lock"
      title="Sign in needed"
      detail="Hermes has no OAuth token for this server yet, so it cannot list tools."
      action={
        <Button variant="text" icon="login">
          Sign in
        </Button>
      }
    />
    <Banner
      tone="error"
      icon="error"
      title="Could not test grafana"
      action={<Button variant="text">Retry</Button>}
    />
  </div>
);

export const LongWarning = () => (
  <div style={column}>
    <Banner
      tone="warning"
      icon="warning"
      title="Replaces all servers of this profile."
      detail="Anything you remove here is deleted, not just switched off. This is the profile's real configuration, including secrets such as environment values and bearer tokens. It is not saved on this device."
    />
  </div>
);

export const Apple = () => (
  <HermesProvider platform="apple">
    <div style={column}>
      <Banner
        tone="warning"
        icon="lock"
        title="Sign in needed"
        detail="Hermes has no OAuth token for this server yet, so it cannot list tools."
        action={
          <Button variant="text" icon="login">
            Sign in
          </Button>
        }
      />
      <Banner
        tone="error"
        icon="error"
        title="Could not connect"
        detail="Connection refused: https://flaky.example/mcp"
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={column}>
      <Banner
        tone="success"
        icon="check_circle"
        title="Connected"
        detail="2 tools · 1 prompt · 0 resources"
      />
      <Banner
        tone="warning"
        icon="warning"
        title="Only add commands you recognise."
        detail="You can remove the server afterwards, but not undo what it ran."
      />
      <Banner tone="error" icon="error" title="Could not add notes-fs" />
    </div>
  </HermesProvider>
);
