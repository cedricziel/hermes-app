import { ChatHeader, HermesProvider } from "@hermes-app/ui";

const wide = { width: 720 };

export const Thread = () => (
  <div style={wide}>
    <ChatHeader title="Summarize last night's run logs" />
  </div>
);

export const NoThread = () => (
  <div style={wide}>
    <ChatHeader />
  </div>
);

export const MenuOpen = () => (
  <div style={{ ...wide, height: 380 }}>
    <ChatHeader title="Backup failure" pinned defaultMenuOpen />
  </div>
);

export const LocalThread = () => (
  <div style={wide}>
    <ChatHeader title="Summarise the weekly report" remote={false} />
  </div>
);

export const Phone = () => (
  <div style={{ width: 390, border: "1px solid var(--h-border)" }}>
    <ChatHeader layout="phone" title="Summarize last night's run logs" />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={wide}>
      <ChatHeader title="Draft release notes for v0.9" />
    </div>
  </HermesProvider>
);
