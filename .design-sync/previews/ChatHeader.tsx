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

const phoneFrame = { width: 390, border: "1px solid var(--h-border)" };

/** Material (left) and Apple (right) phone bars: 64px left-aligned title vs the 44px bar with a centred title and hairline. */
export const PlatformPhone = () => (
  <div style={{ display: "flex", gap: 20 }}>
    <div style={phoneFrame}>
      <ChatHeader layout="phone" title="Summarize last night's run logs" />
    </div>
    <HermesProvider platform="apple">
      <div style={phoneFrame}>
        <ChatHeader layout="phone" title="Summarize last night's run logs" />
      </div>
    </HermesProvider>
  </div>
);

/** Material (top, 77px with a rule) and Apple on a Mac (bottom, the 52px MacToolbar, no rule) desktop bars. */
export const PlatformDesktop = () => (
  <div style={{ ...wide, display: "flex", flexDirection: "column", gap: 20 }}>
    <div style={{ border: "1px solid var(--h-border)" }}>
      <ChatHeader title="Backup failure" />
    </div>
    <HermesProvider platform="apple">
      <div style={{ border: "1px solid var(--h-border)" }}>
        <ChatHeader title="Backup failure" />
      </div>
    </HermesProvider>
  </div>
);

export const ApplePhoneMenuOpen = () => (
  <HermesProvider platform="apple">
    <div style={{ ...phoneFrame, height: 340 }}>
      <ChatHeader
        layout="phone"
        title="Backup failure"
        pinned
        defaultMenuOpen
      />
    </div>
  </HermesProvider>
);

/** Mac: the chat's toolbar (title over "profile · model", New Chat, Copy Transcript, Connection Details) with the search field in a wide window, a search button in a medium one, a "…" for the two middle buttons in a compact one, and the wide field while a search is open. */
export const AppleMacToolbar = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    style={{ display: "flex", flexDirection: "column", gap: 12 }}
  >
    {(["wide", "medium", "compact"] as const).map((size) => (
      <div key={size} style={{ ...wide, border: "1px solid var(--h-border)" }}>
        <ChatHeader
          title="Backup failure"
          subtitle="default · claude-opus-4"
          windowSize={size}
          onCopyTranscript={() => {}}
        />
      </div>
    ))}
    <div style={{ ...wide, border: "1px solid var(--h-border)" }}>
      <ChatHeader
        title="Backup failure"
        subtitle="default · claude-opus-4"
        windowSize="medium"
        searchActive
        searchQuery="nas-02"
        onCopyTranscript={() => {}}
      />
    </div>
  </HermesProvider>
);
