import { Button, Card, HermesProvider } from "@hermes-app/ui";

const Sample = () => (
  <Card style={{ width: 300 }}>
    <div className="h-title-sm">Where should we begin?</div>
    <div className="h-body-md h-muted" style={{ marginTop: 4 }}>
      Ask Hermes Agent about your server, your codebase, or anything it has
      tools for.
    </div>
    <div style={{ marginTop: 12 }}>
      <Button compact>New chat</Button>
    </div>
  </Card>
);

export const Light = () => (
  <HermesProvider theme="light" style={{ padding: 16, borderRadius: 14 }}>
    <Sample />
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <Sample />
  </HermesProvider>
);
