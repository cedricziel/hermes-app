import { HermesProvider, ThreadSidebar } from "@hermes-app/ui";
import type { ThreadItem } from "@hermes-app/ui";

const threads: ThreadItem[] = [
  { id: "backup", title: "Backup failure", pinned: true },
  {
    id: "nightly",
    title: "Why did the nightly backup of the analytics database fail?",
  },
  { id: "release", title: "Release notes" },
  { id: "untitled", title: "Untitled chat" },
];

const frame = { width: 280, height: 560, border: "1px solid var(--h-border)" };

export const Threads = () => (
  <div style={frame}>
    <ThreadSidebar threads={threads} selectedId="nightly" />
  </div>
);

export const MenuOpen = () => (
  <div style={{ ...frame, marginRight: 80 }}>
    <ThreadSidebar
      threads={threads}
      selectedId="backup"
      defaultMenuThreadId="nightly"
    />
  </div>
);

export const MoreAndAccount = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <div style={frame}>
      <ThreadSidebar
        threads={threads.slice(0, 2)}
        selectedId="backup"
        defaultMoreOpen
        account="Ada Lovelace"
      />
    </div>
    <div style={frame}>
      <ThreadSidebar
        threads={threads}
        account="Ada Lovelace"
        serverUrl="https://hermes.example.net"
        authRequired
        defaultAccountMenuOpen
      />
    </div>
  </div>
);

export const EmptyAndPaging = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <div style={frame}>
      <ThreadSidebar threads={[]} moreEntries={[]} />
    </div>
    <div style={frame}>
      <ThreadSidebar
        threads={[
          ...threads,
          { id: "local", title: "Summarise the weekly report", remote: false },
        ]}
        selectedId="release"
        hasMore
        loadingMore
      />
    </div>
  </div>
);

/** Apple touch (left): 44px rows with a 44px "…" target (the app also swipes and long-presses). Mac (right): 52px strip under the traffic lights, compact rows. */
export const AppleTouchAndMac = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 24 }}>
    <div style={frame}>
      <ThreadSidebar
        layout="phone"
        threads={threads}
        selectedId="nightly"
        account="Ada Lovelace"
      />
    </div>
    <div style={{ ...frame, position: "relative" }}>
      <ThreadSidebar
        threads={threads}
        selectedId="nightly"
        account="Ada Lovelace"
      />
    </div>
  </HermesProvider>
);

/** The row menu on Apple: iOS pull-down (left, from the "…") and the compact Mac menu (right, "…" or right-click). */
export const AppleMenus = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 24 }}>
    <div style={{ ...frame, marginRight: 40 }}>
      <ThreadSidebar
        layout="phone"
        threads={threads}
        selectedId="backup"
        defaultMenuThreadId="nightly"
      />
    </div>
    <div style={{ ...frame, marginRight: 80 }}>
      <ThreadSidebar
        threads={threads}
        selectedId="backup"
        defaultMenuThreadId="nightly"
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...frame, border: "1px solid var(--h-border)" }}>
      <ThreadSidebar threads={threads} selectedId="nightly" />
    </div>
  </HermesProvider>
);
