import { ActionSheet, HermesProvider } from "@hermes-app/ui";

const phone = {
  position: "relative",
  width: 390,
  height: 400,
  borderRadius: 14,
  overflow: "hidden",
} as const;

const Behind = () => (
  <div style={{ padding: 16 }} className="h-body-lg">
    Chats
  </div>
);

/** A long press on a chat: Rename, Pin, Archive and Delete over the scrim. */
export const Thread = () => (
  <HermesProvider platform="apple" style={phone}>
    <Behind />
    <ActionSheet
      title="Fix the flaky login test"
      actions={[
        { label: "Rename" },
        { label: "Pin" },
        { label: "Archive" },
        { label: "Delete", destructive: true },
      ]}
    />
  </HermesProvider>
);

/** A scheduled job: Run now, Pause, Delete. */
export const Schedule = () => (
  <HermesProvider platform="apple" style={phone}>
    <Behind />
    <ActionSheet
      title="Morning brief"
      actions={[
        { label: "Run now" },
        { label: "Pause" },
        { label: "Delete", destructive: true },
      ]}
    />
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider platform="apple" theme="dark" style={phone}>
    <Behind />
    <ActionSheet
      title="grafana"
      actions={[{ label: "Turn off" }, { label: "Remove", destructive: true }]}
    />
  </HermesProvider>
);

/** `presentation="inline"`: the sheet alone, to place yourself. */
export const Inline = () => (
  <div style={{ width: 390 }}>
    <ActionSheet
      presentation="inline"
      title="hermes-plugin-weather"
      actions={[{ label: "Disable" }, { label: "Remove", destructive: true }]}
    />
  </div>
);
