import {
  BotsScreen,
  HermesProvider,
  type BotGroupRoom,
  type BotItem,
} from "@hermes-app/ui";

const bots: BotItem[] = [
  {
    name: "writer",
    title: "Editor",
    summary: "Clear writing and careful reviews",
    model: "claude-sonnet-4",
  },
  {
    name: "research",
    title: "Researcher",
    summary: "Sources and synthesis",
    model: "gpt-5",
  },
  {
    name: "analyst",
    title: "Analyst",
    preview: "Revenue grew 12% quarter over quarter",
  },
];
const groups: BotGroupRoom[] = [
  {
    id: "launch",
    name: "Launch plan",
    members: ["Writer", "Research", "Analyst"],
    working: true,
  },
  {
    id: "weekly",
    name: "Weekly review",
    members: ["Writer", "Research"],
    needsAttention: true,
  },
];
const roster = {
  bots,
  availableProfiles: [{ name: "plain" }],
  groups,
};

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const row = { display: "flex", gap: 16, alignItems: "flex-start" } as const;

/** iPhone: Refresh and "+" in the bar, "Search bots" under it, the Bots, Add an existing profile and Groups groups with their footers. */
export const IPhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <BotsScreen {...roster} />
    </div>
  </HermesProvider>
);

/** Mac: the toolbar with "3 bots", the search field, Refresh and "+"; compact rows in the 600px column. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <BotsScreen {...roster} layout="desktop" />
    </div>
  </HermesProvider>
);

/** Material, light and dark: the 56px bar, the pill search field, outlined Add and the Material groups. */
export const Material = () => (
  <div style={row}>
    <HermesProvider>
      <div style={phone}>
        <BotsScreen {...roster} adding={["plain"]} />
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={phone}>
        <BotsScreen {...roster} />
      </div>
    </HermesProvider>
  </div>
);

/** Create group over the roster: iPhone with two bots picked (trailing checks), Material dark with checkboxes and nothing picked yet. */
export const CreateGroup = () => (
  <div style={row}>
    <HermesProvider platform="apple">
      <div style={phone}>
        <BotsScreen
          {...roster}
          createGroup={{
            members: bots,
            name: "Pricing",
            selected: ["writer", "analyst"],
          }}
        />
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={phone}>
        <BotsScreen {...roster} createGroup={{ members: bots }} />
      </div>
    </HermesProvider>
  </div>
);

/** States: no bots yet (Groups loading, Create group disabled) on iPhone dark, and Bot Mode not available on Material. */
export const States = () => (
  <div style={row}>
    <HermesProvider platform="apple" theme="dark">
      <div style={phone}>
        <BotsScreen
          availableProfiles={[{ name: "plain" }, { name: "work" }]}
          groups={[]}
          groupsState="loading"
        />
      </div>
    </HermesProvider>
    <HermesProvider>
      <div style={phone}>
        <BotsScreen state="unsupported" />
      </div>
    </HermesProvider>
  </div>
);
