import { Button, HermesProvider } from "@hermes-app/ui";

const row = {
  display: "flex",
  gap: 8,
  flexWrap: "wrap",
  alignItems: "center",
} as const;

export const Variants = () => (
  <div style={row}>
    <Button>Allow once</Button>
    <Button variant="outlined">Allow for session</Button>
    <Button variant="text">Deny</Button>
    <Button variant="danger">Remove server</Button>
    <Button variant="danger-outlined">Uninstall</Button>
  </div>
);

export const WithIcon = () => (
  <div style={row}>
    <Button icon="add">New task</Button>
    <Button variant="outlined" icon="refresh">
      Retry
    </Button>
    <Button variant="text" icon="stop_circle">
      Stop
    </Button>
  </div>
);

export const Compact = () => (
  <div style={row}>
    <Button compact>Save</Button>
    <Button compact variant="outlined">
      Test
    </Button>
    <Button compact variant="text">
      Cancel
    </Button>
  </div>
);

export const Disabled = () => (
  <div style={row}>
    <Button disabled>Sign in</Button>
    <Button variant="outlined" disabled>
      Install
    </Button>
    <Button variant="danger-outlined" disabled>
      Uninstall
    </Button>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={row}>
      <Button>Allow once</Button>
      <Button variant="outlined">Allow for session</Button>
      <Button variant="text">Deny</Button>
      <Button variant="danger-outlined">Ask agent to delete</Button>
    </div>
  </HermesProvider>
);
