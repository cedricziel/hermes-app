import { Card, HermesProvider, SwitchRow } from "@hermes-app/ui";

const pane = { width: 420 } as const;

/** Plugin detail: two settings in a padded pane. */
export const Material = () => (
  <div style={pane}>
    <SwitchRow title="Enabled" subtitle="Applies to new chats" checked />
    <SwitchRow
      title="Hide from dashboard sidebar"
      subtitle="Only affects the web dashboard"
      checked={false}
    />
    <SwitchRow title="Turn on after installing" checked disabled />
  </div>
);

/** MCP server detail: the Enabled row in a card, inset 16px. */
export const InCard = () => (
  <div style={pane}>
    <Card padding={0}>
      <SwitchRow
        title="Enabled"
        subtitle="Used from the next chat"
        checked
        inset={16}
      />
    </Card>
  </div>
);

/** A settings list row with a leading icon and a subtitle that wraps. */
export const WithIcon = () => (
  <div style={pane}>
    <SwitchRow
      icon="send"
      title="Telegram"
      subtitle="@hermes_work_bot · answers in every chat it is added to, and in direct messages from paired users"
      checked
      inset={16}
    />
  </div>
);

/** Apple: the same tile with the 51x31 toggle. */
export const Apple = () => (
  <HermesProvider platform="apple">
    <div style={pane}>
      <SwitchRow title="Enabled" subtitle="Applies to new chats" checked />
      <SwitchRow
        title="Hide from dashboard sidebar"
        subtitle="Only affects the web dashboard"
        checked={false}
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <Card padding={0}>
        <SwitchRow
          title="Enabled"
          subtitle="Not used from the next chat"
          checked={false}
          inset={16}
        />
      </Card>
      <SwitchRow title="Enable after install" checked />
    </div>
  </HermesProvider>
);
