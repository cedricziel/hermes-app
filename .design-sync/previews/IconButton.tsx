import { HermesProvider, IconButton } from "@hermes-app/ui";

const row = { display: "flex", gap: 12, alignItems: "center" } as const;

export const Standard = () => (
  <div style={row}>
    <IconButton icon="more_horiz" label="More" />
    <IconButton icon="info" label="Chat details" />
    <IconButton icon="refresh" label="Refresh" />
    <IconButton icon="add" label="Add attachment" tone="muted" />
  </div>
);

export const Send = () => (
  <div style={row}>
    <IconButton icon="arrow_upward" label="Send" variant="filled" />
    <IconButton icon="arrow_upward" label="Send" variant="filled" disabled />
  </div>
);

export const OutlinedAndCompact = () => (
  <div style={row}>
    <IconButton icon="filter_list" label="Filter" variant="outlined" />
    <IconButton
      icon="more_horiz"
      label="Thread actions"
      size={32}
      tone="muted"
    />
    <IconButton icon="close" label="Close" size={32} />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={row}>
      <IconButton icon="more_horiz" label="More" />
      <IconButton icon="arrow_upward" label="Send" variant="filled" />
      <IconButton icon="arrow_upward" label="Send" variant="filled" disabled />
    </div>
  </HermesProvider>
);
