import { HermesProvider, KanbanBoardsScreen } from "@hermes-app/ui";
import type { KanbanBoardItem } from "@hermes-app/ui";

const boards: KanbanBoardItem[] = [
  { slug: "default", name: "Default", total: 4 },
  { slug: "ops", name: "Ops", total: 1 },
  { slug: "q3-launch", name: "Q3 Launch", total: 12 },
];

const phone = {
  width: 390,
  height: 560,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 420 } as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const noop = () => {};

/** iPhone: "Kanban" beside the back chevron, the title over "3 boards", import and "+" in the bar; "Current" on the open board; a row's "…" pull-down open. */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={phone}>
    <KanbanBoardsScreen
      boards={boards}
      current="default"
      defaultMenuBoard="ops"
      onBack={noop}
    />
  </HermesProvider>
);

/** Android: the 56px bar with the title at the start, a row's "⋮" popup open (Rename, Export…, Archive, Delete). */
export const MaterialPhone = () => (
  <HermesProvider platform="material" style={phone}>
    <KanbanBoardsScreen
      boards={boards}
      current="default"
      defaultMenuBoard="ops"
      onBack={noop}
    />
  </HermesProvider>
);

/** A Mac window: the 52px toolbar with back, import and "+", 13px rows in the centred 600px column. */
export const Desktop = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <KanbanBoardsScreen
      device="mac"
      boards={boards}
      current="default"
      onBack={noop}
    />
  </HermesProvider>
);

/** One board only: its menu has no Archive or Delete. Dark, on iPhone and Android. */
export const SingleBoardDark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        theme="dark"
        platform={platform}
        style={{ ...phone, height: 360 }}
      >
        <KanbanBoardsScreen
          boards={[{ slug: "default", name: "Default", total: 4 }]}
          current="default"
          defaultMenuBoard="default"
          onBack={noop}
        />
      </HermesProvider>
    ))}
  </div>
);
