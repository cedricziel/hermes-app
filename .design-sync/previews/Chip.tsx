import { Chip, HermesProvider } from "@hermes-app/ui";

const row = {
  display: "flex",
  gap: 8,
  flexWrap: "wrap",
  alignItems: "center",
} as const;

export const Filters = () => (
  <div style={row}>
    <Chip icon="filter_list" label="All assignees" />
    <Chip icon="filter_list" label="All tenants" />
    <Chip label="Archived" />
  </div>
);

export const Selected = () => (
  <div style={row}>
    <Chip label="Enabled" selected />
    <Chip label="Disabled" />
    <Chip label="Needs setup" />
  </div>
);

export const Attachments = () => (
  <div style={row}>
    <Chip icon="image" label="screenshot-2026-10-03.png" onRemove={() => {}} />
    <Chip icon="draft" label="backup-agent.toml" onRemove={() => {}} />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={row}>
      <Chip icon="filter_list" label="All assignees" />
      <Chip label="Enabled" selected />
      <Chip icon="draft" label="agent.toml" onRemove={() => {}} />
    </div>
  </HermesProvider>
);
