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
    version: "1.0.0",
    source: "git",
    description:
      "Query and update NetBox from the agent: look up devices, prefixes, VLANs and cables.",
    status: "enabled" as const,
    authRequired: true,
    authCommand: "hermes auth netbox",
    canUpdate: true,
    removable: true,
  },
  {
    name: "gmail-triage",
    version: "0.4.2",
    source: "git",
    description: "Sort, label and draft replies in Gmail.",
    status: "disabled" as const,
    removable: true,
  },
  {
    name: "web-tools",
    version: "2.1.0",
    source: "bundled",
    description: "Fetch pages and search the web.",
    status: "enabled" as const,
    bundled: true,
  },
];

const catalog = [
  {
    name: "hermes-plugin-github",
    maintainer: "Nous Research",
    official: true,
    description: "Issues, pull requests and reviews from the agent.",
    commit: "a3f9c21",
    tools: ["github_issue", "github_pr"],
    docsUrl: "https://github.com/NousResearch/hermes-plugin-github",
  },
  {
    name: "hermes-plugin-weather",
    maintainer: "someone",
    description: "Forecasts and severe weather alerts for the places you name.",
    commit: "77d01be",
  },
  {
    name: "netbox",
    maintainer: "acme",
    description: "Query and update NetBox from the agent.",
    commit: "e4c2a90",
    installed: true,
    updateAvailable: true,
  },
];

const memory = [
  {
    name: "mem0",
    description: "Long-term memory with automatic fact extraction and search.",
    status: "ready" as const,
  },
  {
    name: "honcho",
    description: "Theory-of-mind user modelling from Plastic Labs.",
    status: "needsSetup" as const,
    needs: {
      env: ["HONCHO_API_KEY"],
      python: ["honcho-ai"],
    },
  },
];

const engines = [
  {
    name: "compressor",
    description: "Summarises older turns when the context fills up.",
  },
  {
    name: "lcm",
    description: "Lossless context management: keeps every turn retrievable.",
  },
];

export const ApplePhoneInstalled = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <PluginsScreen layout="phone" plugins={plugins} />
    </div>
  </HermesProvider>
);

/** Material phone: a plugin's detail in a bottom sheet. */
export const MaterialPhoneDetailSheet = () => (
  <div style={phone}>
    <PluginsScreen
      layout="phone"
      plugins={plugins}
      selected="netbox"
      detailOpen
    />
  </div>
);

/** Desktop: the catalog with an entry's detail beside it. */
export const DesktopCatalog = () => (
  <div style={desktop}>
    <PluginsScreen
      layout="desktop"
      tab="catalog"
      catalog={catalog}
      selected="hermes-plugin-github"
      installing={["hermes-plugin-weather"]}
    />
  </div>
);

/** Install from Git URL: the unreviewed-code warning. */
export const GitUrlDialog = () => (
  <div style={desktop}>
    <PluginsScreen
      layout="desktop"
      tab="catalog"
      catalog={catalog}
      gitInstall={{ url: "acme/hermes-plugin-jira", trust: true }}
    />
  </div>
);

/** Apple phone: the Providers tab, one provider needing setup on the server. */
export const AppleProviders = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <PluginsScreen
        layout="phone"
        tab="providers"
        memoryProviders={memory}
        memoryChoice="mem0"
        needsOpen={["honcho"]}
        contextEngines={engines}
        contextChoice="compressor"
        providersDirty
      />
    </div>
  </HermesProvider>
);

export const LoadingAndFailed = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <div style={{ ...phone, width: 300, height: 400 }}>
      <PluginsScreen layout="phone" installedState="loading" />
    </div>
    <div style={{ ...phone, width: 300, height: 400 }}>
      <PluginsScreen layout="phone" tab="catalog" catalogState="failed" />
    </div>
  </div>
);

export const DarkDesktop = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...desktop, width: 768, height: 520 }}>
      <PluginsScreen layout="desktop" plugins={plugins} selected="netbox" />
    </div>
  </HermesProvider>
);
