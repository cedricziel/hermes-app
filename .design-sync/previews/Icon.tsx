import { HermesProvider, Icon } from "@hermes-app/ui";

const row = {
  display: "flex",
  gap: 16,
  alignItems: "center",
  flexWrap: "wrap",
} as const;

export const Outlined = () => (
  <div style={row}>
    <Icon name="chat_bubble" />
    <Icon name="view_kanban" />
    <Icon name="schedule" />
    <Icon name="extension" />
    <Icon name="dns" />
    <Icon name="settings" />
    <Icon name="person" />
  </div>
);

export const Filled = () => (
  <div style={row}>
    <Icon name="check_circle" filled color="var(--h-success)" />
    <Icon name="error" filled color="var(--h-error)" />
    <Icon name="warning" filled color="var(--h-warning)" />
    <Icon name="push_pin" filled />
  </div>
);

export const Sizes = () => (
  <div style={row}>
    <Icon name="auto_awesome" size={16} />
    <Icon name="auto_awesome" size={20} />
    <Icon name="auto_awesome" size={24} />
    <Icon name="auto_awesome" size={40} />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={row}>
      <Icon name="chat_bubble" />
      <Icon name="view_kanban" />
      <Icon name="check_circle" filled color="var(--h-success)" />
    </div>
  </HermesProvider>
);
