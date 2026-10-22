import { AgentNoticeCard, HermesProvider } from "@hermes-app/ui";

const col = {
  width: 420,
  display: "flex",
  flexDirection: "column",
  gap: 0,
} as const;

/** Collapsed notices: a warning (error-colored icon), a plain startup notice (muted) and a success one (primary), each with its dismiss button. */
export const Levels = () => (
  <div style={col}>
    <AgentNoticeCard
      level="warn"
      text="Credits are running low. Review your account before continuing."
      onDismiss={() => {}}
    />
    <AgentNoticeCard
      text="Preparing your agent. This is taking longer than expected."
      onDismiss={() => {}}
    />
    <AgentNoticeCard
      level="success"
      text="Memory provider reconnected"
      onDismiss={() => {}}
    />
  </div>
);

/** Opened: the whole text under the header, between two hairlines. An unknown level draws the muted info icon. */
export const Expanded = () => (
  <div style={col}>
    <AgentNoticeCard
      level="warn"
      defaultOpen
      text="Credits are running low. Review your account before continuing."
      onDismiss={() => {}}
    />
    <AgentNoticeCard
      level="future"
      defaultOpen
      text="Capabilities refreshed"
      onDismiss={() => {}}
    />
  </div>
);

/** Without onDismiss the close button is gone; a long notice is cut to one line when collapsed. */
export const NoDismiss = () => (
  <div style={col}>
    <AgentNoticeCard text="This notice cannot be dismissed, and its text runs on past the width of the panel so the header cuts it." />
  </div>
);

/** Material (top) and iOS (bottom): the info glyph comes from each icon set. */
export const PlatformCompare = () => (
  <div style={{ ...col, gap: 16 }}>
    <AgentNoticeCard
      level="warn"
      text="Credits are running low."
      onDismiss={() => {}}
    />
    <HermesProvider platform="apple">
      <AgentNoticeCard
        level="warn"
        text="Credits are running low."
        onDismiss={() => {}}
      />
    </HermesProvider>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark">
    <div style={{ ...col, padding: 8 }}>
      <AgentNoticeCard
        level="warn"
        text="Credits are running low. Review your account before continuing."
        onDismiss={() => {}}
      />
      <AgentNoticeCard
        level="success"
        defaultOpen
        text="Memory provider reconnected"
        onDismiss={() => {}}
      />
    </div>
  </HermesProvider>
);
