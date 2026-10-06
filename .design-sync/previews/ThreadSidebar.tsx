import { HermesProvider, ShellNavigation, ThreadSidebar } from "@hermes-app/ui";
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

/** The Mac source list sorts chats by `updatedAt`, counted back from `now`. */
const macThreads: ThreadItem[] = [
  { ...threads[0], updatedAt: "2026-09-29T10:00:00" },
  { ...threads[1], updatedAt: "2026-10-04T08:30:00" },
  { ...threads[2], updatedAt: "2026-10-01T15:00:00" },
  {
    id: "certs",
    title: "Rotate the staging certificates",
    updatedAt: "2026-09-14T09:00:00",
  },
  {
    id: "pkce",
    title: "Explain the PKCE flow to a new hire",
    updatedAt: "2026-07-02T09:00:00",
  },
  { ...threads[3], updatedAt: "2026-10-04T11:00:00", remote: false },
];
const now = "2026-10-04T12:00:00";

/** Mac source list: sections Pinned, Today, Previous 7 days, Previous 30 days and Older; "Older" folded (left); a row under the pointer shows Archive and More, and the right-click menu leads with "Open in New Window" (right). */
export const AppleMacSourceList = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    style={{ display: "flex", gap: 24 }}
  >
    <div style={{ ...frame, height: 600 }}>
      <ThreadSidebar
        threads={macThreads}
        now={now}
        selectedId="nightly"
        defaultFoldedSections={["older"]}
        hoveredThreadId="release"
        account="Ada Lovelace"
        navigation={
          <ShellNavigation
            destinations={["chat", "kanban", "schedules"]}
            current="chat"
          />
        }
      />
    </div>
    <div style={{ ...frame, marginRight: 140 }}>
      <ThreadSidebar
        threads={macThreads}
        now={now}
        selectedId="nightly"
        hoveredThreadId="release"
        defaultMenuThreadId="release"
        canOpenInNewWindow
        account="Ada Lovelace"
      />
    </div>
  </HermesProvider>
);

/** Apple touch (left): 44px rows without a "…" button; a chat is swiped or long-pressed instead. Mac (right): 52px strip under the traffic lights, the source list. */
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

/** Menus on Apple: the account menu as an iOS pull-down on touch (left), a chat's compact Mac menu from its "…" or a right-click (right). */
export const AppleMenus = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 24 }}>
    <div style={{ ...frame, marginRight: 40 }}>
      <ThreadSidebar
        layout="phone"
        threads={threads}
        selectedId="backup"
        account="Ada Lovelace"
        serverUrl="https://hermes.example.com"
        authRequired
        defaultAccountMenuOpen
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

/** Apple touch swipes: from the trailing edge Delete in red (left), from the leading edge Pin in orange (right). */
export const AppleSwipe = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 24 }}>
    <div style={frame}>
      <ThreadSidebar
        layout="phone"
        threads={threads}
        selectedId="backup"
        swipedThreadId="nightly"
      />
    </div>
    <div style={frame}>
      <ThreadSidebar
        layout="phone"
        threads={threads}
        selectedId="backup"
        swipedThreadId="release"
        swipeSide="leading"
      />
    </div>
  </HermesProvider>
);

/** Apple touch long press: the action sheet with Rename, Pin, Archive and Delete over the sidebar. */
export const AppleActionSheet = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 24 }}>
    <div style={{ ...frame, width: 320 }}>
      <ThreadSidebar
        layout="phone"
        threads={threads}
        selectedId="backup"
        actionSheetThreadId="nightly"
      />
    </div>
    <HermesProvider theme="dark">
      <div style={{ ...frame, width: 320 }}>
        <ThreadSidebar
          layout="phone"
          threads={threads}
          selectedId="backup"
          swipedThreadId="backup"
          swipeSide="leading"
        />
      </div>
    </HermesProvider>
  </HermesProvider>
);
