import { AppShell, HermesProvider, KanbanBoardsScreen } from "@hermes-app/ui";
import type { KanbanBoardItem } from "@hermes-app/ui";

const boards: KanbanBoardItem[] = [
  { slug: "default", name: "Default", total: 4 },
  { slug: "ops", name: "Ops", total: 1 },
  { slug: "platform-migration", name: "Platform migration", total: 12 },
];

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

const desktop = {
  width: 800,
  height: 560,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

/** iPhone: chevron back with "Kanban", the current board checked, the floating "New board" button. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <KanbanBoardsScreen boards={boards} current="default" />
    </div>
  </HermesProvider>
);

/** Android: a row's menu open (Rename, Export…, Archive, Delete). */
export const MaterialPhone = () => (
  <div style={phone}>
    <KanbanBoardsScreen
      boards={boards}
      current="default"
      defaultMenuBoard="ops"
    />
  </div>
);

/** Desktop: the list at full width beside the shell's sidebar. */
export const Desktop = () => (
  <div style={desktop}>
    <AppShell layout="desktop" current="kanban" account="Ada Lovelace">
      <KanbanBoardsScreen boards={boards} current="ops" layout="desktop" />
    </AppShell>
  </div>
);

/** One board only: its menu has no Archive or Delete. Dark. */
export const SingleBoardDark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content" }}>
    <div style={{ ...phone, height: 420 }}>
      <KanbanBoardsScreen
        boards={[{ slug: "default", name: "Default", total: 4 }]}
        current="default"
        defaultMenuBoard="default"
      />
    </div>
  </HermesProvider>
);
