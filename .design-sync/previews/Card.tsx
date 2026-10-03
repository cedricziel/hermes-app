import { Badge, Button, Card, HermesProvider } from "@hermes-app/ui";

export const Basic = () => (
  <Card style={{ width: 360 }}>
    <div className="h-title-sm">Nightly backup</div>
    <div className="h-body-md h-muted" style={{ marginTop: 4 }}>
      Runs every day at 03:00 and posts the result to Telegram.
    </div>
    <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
      <Badge tone="success">Last run succeeded</Badge>
    </div>
  </Card>
);

export const Interactive = () => (
  <Card interactive style={{ width: 360 }}>
    <div className="h-title-sm">github</div>
    <div className="h-body-sm h-muted h-mono" style={{ marginTop: 4 }}>
      npx -y @modelcontextprotocol/server-github
    </div>
  </Card>
);

export const Tinted = () => (
  <Card tinted style={{ width: 360 }}>
    <div className="h-body-md">This server doesn't run the Kanban plugin.</div>
    <div style={{ marginTop: 12 }}>
      <Button compact variant="outlined">
        Learn more
      </Button>
    </div>
  </Card>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <Card style={{ width: 340 }}>
      <div className="h-title-sm">Nightly backup</div>
      <div className="h-body-md h-muted" style={{ marginTop: 4 }}>
        Runs every day at 03:00.
      </div>
    </Card>
  </HermesProvider>
);
