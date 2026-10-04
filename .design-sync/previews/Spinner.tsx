import { Button, HermesProvider, Spinner } from "@hermes-app/ui";

const row = { display: "flex", gap: 20, alignItems: "center" } as const;
const stage = { padding: 16, borderRadius: 14 } as const;

const Set = ({ note }: { note: string }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
    <div style={row}>
      <Spinner size={12} strokeWidth={2} color="var(--h-primary)" />
      <Spinner size={16} strokeWidth={2} color="var(--h-muted)" />
      <Spinner />
      <Spinner size={40} strokeWidth={4} color="var(--h-fg)" />
      <span className="h-body-md h-muted">{note}</span>
    </div>
    <div style={row}>
      <Button disabled>
        <Spinner
          size={16}
          strokeWidth={2}
          color="var(--h-muted)"
          label="Installing"
        />
      </Button>
      <span
        className="h-body-sm h-muted"
        style={{ display: "inline-flex", gap: 8, alignItems: "center" }}
      >
        <Spinner size={12} strokeWidth={2} color="currentColor" />
        4s · Thinking…
      </span>
    </div>
  </div>
);

/** A three-quarter ring: 12px (tool call), 16px (row, button), 20px (default) and 40px (a screen loading). */
export const Material = () => (
  <HermesProvider style={stage}>
    <Set note="Connecting to your server…" />
  </HermesProvider>
);

/** The activity indicator: eight spokes fading round, the same sizes. */
export const Apple = () => (
  <HermesProvider platform="apple" style={stage}>
    <Set note="Connecting to your server…" />
  </HermesProvider>
);

export const MaterialDark = () => (
  <HermesProvider theme="dark" style={stage}>
    <Set note="Installing plugin…" />
  </HermesProvider>
);

export const AppleDark = () => (
  <HermesProvider platform="apple" theme="dark" style={stage}>
    <Set note="Installing plugin…" />
  </HermesProvider>
);
