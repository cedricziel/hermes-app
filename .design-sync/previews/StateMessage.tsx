import { Button, HermesProvider, StateMessage } from "@hermes-app/ui";

export const Empty = () => (
  <StateMessage
    icon="schedule"
    title="No scheduled jobs yet"
    detail="Jobs you create run on the Hermes server, even while this app is closed."
    action={<Button icon="add">New job</Button>}
  />
);

export const LoadFailed = () => (
  <StateMessage
    icon="cloud_off"
    title="Couldn't load MCP servers"
    detail="The server didn't answer. Check your connection and try again."
    action={<Button variant="outlined">Retry</Button>}
  />
);

export const Unavailable = () => (
  <StateMessage
    icon="extension_off"
    title="Kanban isn't enabled on this server"
  />
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ borderRadius: 14 }}>
    <StateMessage
      icon="inbox"
      title="Nothing here yet"
      detail="Plugins you install show up here."
    />
  </HermesProvider>
);
