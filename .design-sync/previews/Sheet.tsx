import {
  Banner,
  Button,
  HermesProvider,
  PluginRow,
  Sheet,
  SwitchRow,
  Tag,
  TextField,
} from "@hermes-app/ui";

const phone = {
  position: "relative",
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;

const desktop = { ...phone, width: 800, height: 560 } as const;

const behind = (
  <div>
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
    <PluginRow
      plugin={{
        name: "gmail-triage",
        version: "0.4.2",
        description: "Sort, label and draft replies in Gmail.",
        status: "disabled",
      }}
    />
  </div>
);

/** A bottom sheet with a drag handle: the Plugins detail on a phone. */
export const BottomSheet = () => (
  <div style={phone}>
    {behind}
    <Sheet dragHandle padding={20}>
      <div className="h-title-lg">netbox</div>
      <div className="h-body-sm h-muted">v1.0.0 · git</div>
      <div className="h-body-md" style={{ marginTop: 12 }}>
        Query and update NetBox from the agent: look up devices, prefixes, VLANs
        and cables.
      </div>
      <div style={{ marginTop: 8 }}>
        <SwitchRow title="Enabled" subtitle="Applies to new chats" checked />
        <SwitchRow
          title="Hide from dashboard sidebar"
          subtitle="Only affects the web dashboard"
          checked={false}
        />
      </div>
    </Sheet>
  </div>
);

/** An alert-style dialog with a title and actions: Install from Git URL. */
export const Dialog = () => (
  <div style={desktop}>
    {behind}
    <Sheet
      presentation="dialog"
      title="Install from Git URL"
      width={440}
      actions={
        <>
          <Button variant="text">Cancel</Button>
          <Button disabled>Install</Button>
        </>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        <TextField label="Git URL or owner/repo" placeholder="owner/repo" />
        <Banner
          tone="warning"
          icon="gpp_maybe"
          title="Unreviewed code."
          detail="This plugin is not from the Hermes catalog. It runs on your server with full access."
        />
      </div>
    </Sheet>
  </div>
);

/** Apple: the sheet is the same Material sheet; the controls inside follow the platform. */
export const Apple = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      {behind}
      <Sheet>
        <div className="h-title-lg">Install airtable</div>
        <div className="h-body-md" style={{ marginTop: 4 }}>
          Read and write Airtable bases.
        </div>
        <div style={{ display: "flex", gap: 6, margin: "12px 0" }}>
          <Tag variant="tinted">Remote</Tag>
          <Tag variant="tinted">API key</Tag>
        </div>
        <SwitchRow title="Turn on after installing" checked />
        <Button fullWidth>Install on "work"</Button>
      </Sheet>
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={phone}>
      {behind}
      <Sheet dragHandle padding={20}>
        <div className="h-title-lg">gmail-triage</div>
        <div className="h-body-sm h-muted">v0.4.2 · git</div>
        <div style={{ marginTop: 8 }}>
          <SwitchRow
            title="Enabled"
            subtitle="Applies to new chats"
            checked={false}
          />
        </div>
      </Sheet>
    </div>
  </HermesProvider>
);
