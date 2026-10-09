import { HermesProvider, PluginsScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const desktop = { ...phone, width: 800, height: 560 } as const;

const plugins = [
  {
    name: "netbox",
    version: "1.2.0",
    source: "git",
    description: "Query NetBox for devices and prefixes.",
    status: "enabled" as const,
    canUpdate: true,
    removable: true,
  },
  {
    name: "notes-sync",
    version: "1.2.0",
    source: "user",
    description: "Keep a folder of notes in step with memory.",
    status: "disabled" as const,
    removable: true,
  },
  {
    name: "calendar",
    version: "1.2.0",
    source: "git",
    description: "Read and create calendar events.",
    status: "inactive" as const,
    authRequired: true,
    authCommand: "hermes auth calendar",
    removable: true,
  },
  {
    name: "terminal",
    version: "1.2.0",
    source: "bundled",
    description: "Run shell commands.",
    status: "enabled" as const,
    bundled: true,
  },
];

const catalog = [
  {
    name: "browser-tools",
    maintainer: "Nous Research",
    official: true,
    description: "Drive a headless browser.",
    commit: "a3f9c21",
    tools: ["browser_open", "browser_click"],
    docsUrl: "https://example.com/browser-tools",
  },
  {
    name: "notes-sync",
    maintainer: "A community author",
    description: "Keep notes in step with memory.",
    commit: "a3f9c21",
    installed: true,
    updateAvailable: true,
  },
  {
    name: "rss-reader",
    maintainer: "A community author",
    description: "Read feeds and summarise them.",
    commit: "a3f9c21",
  },
];

const memory = [
  {
    name: "holographic",
    description: "Remembers things with holographic.",
    status: "ready" as const,
  },
  {
    name: "vector-store",
    description: "Remembers things with vector-store.",
    status: "unavailable" as const,
    needs: { env: ["VECTOR_STORE_URL"], python: ["vector-store-client"] },
  },
];

const engines = [
  { name: "compressor", description: "Summarises old turns." },
  { name: "sliding-window", description: "Keeps the last turns." },
];

/** iPhone: "Chat" back, the title over the profile, "+", the segmented tabs and the installed plugins in one inset group. */
export const ApplePhoneInstalled = () => (
  <HermesProvider platform="apple" style={phone}>
    <PluginsScreen layout="phone" profile="work" plugins={plugins} />
  </HermesProvider>
);

/** Material phone: a plugin's grouped detail in a bottom sheet. */
export const MaterialPhoneDetailSheet = () => (
  <HermesProvider style={phone}>
    <PluginsScreen
      layout="phone"
      profile="work"
      plugins={plugins}
      selected="calendar"
      detailOpen
    />
  </HermesProvider>
);

/** Mac: the catalog with the search in the toolbar and an entry's detail beside the list. */
export const DesktopCatalog = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <PluginsScreen
      layout="desktop"
      tab="catalog"
      profile="work"
      plugins={plugins}
      catalog={catalog}
      selected="browser-tools"
      installing={["rss-reader"]}
    />
  </HermesProvider>
);

/** Install from Git URL, opened from the bar's "+": the unreviewed-code warning. */
export const GitUrlDialog = () => (
  <HermesProvider style={desktop}>
    <PluginsScreen
      layout="desktop"
      tab="catalog"
      profile="work"
      catalog={catalog}
      gitInstall={{ url: "acme/hermes-plugin-jira", trust: true }}
    />
  </HermesProvider>
);

/** Providers on iPhone and Material: choice rows (a blue check, or a leading radio), an unavailable provider with its open "What it needs", and the Save bar. */
export const AppleProviders = () => (
  <div style={{ display: "flex", gap: 16 }}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider key={platform} platform={platform} style={phone}>
        <PluginsScreen
          layout="phone"
          tab="providers"
          profile="work"
          memoryProviders={memory}
          memoryChoice="holographic"
          needsOpen={["vector-store"]}
          contextEngines={engines}
          contextChoice="compressor"
          providersDirty
        />
      </HermesProvider>
    ))}
  </div>
);

export const LoadingAndFailed = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <HermesProvider style={{ ...phone, width: 300, height: 400 }}>
      <PluginsScreen layout="phone" profile="work" installedState="loading" />
    </HermesProvider>
    <HermesProvider
      platform="apple"
      style={{ ...phone, width: 300, height: 400 }}
    >
      <PluginsScreen
        layout="phone"
        profile="work"
        tab="catalog"
        catalogState="failed"
      />
    </HermesProvider>
  </div>
);

/** Mac, dark: the installed list with counts in the subtitle and the selected plugin's detail. */
export const DarkDesktop = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    theme="dark"
    style={desktop}
  >
    <PluginsScreen
      layout="desktop"
      profile="work"
      plugins={plugins}
      selected="notes-sync"
    />
  </HermesProvider>
);
