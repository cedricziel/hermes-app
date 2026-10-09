import { HermesProvider, SkillsScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const noop = () => {};

const groups = [
  {
    category: "apple",
    skills: [
      {
        name: "apple-notes",
        description: "Read Apple Notes",
        source: "bundled" as const,
        enabled: true,
        usage: 14,
      },
    ],
  },
  {
    category: "devops",
    skills: [
      {
        name: "compose",
        description: "Manage Compose stacks",
        source: "hub" as const,
        enabled: false,
      },
    ],
  },
  {
    category: "github",
    skills: [
      {
        name: "pr-review",
        description: "Review a pull request",
        source: "agent" as const,
        enabled: true,
      },
    ],
  },
];

const hub = {
  sources: [
    { id: "official", label: "Official (Nous)" },
    { id: "github", label: "GitHub" },
  ],
  featured: [
    {
      name: "web-scraper",
      description: "Scrape pages into markdown.",
      trust: "community" as const,
      tags: ["web"],
    },
    {
      name: "compose",
      description: "Manage Compose stacks.",
      trust: "community" as const,
    },
  ],
  official: [
    {
      name: "web-research",
      description: "Search the web and cite sources.",
      trust: "builtin" as const,
      tags: ["search"],
    },
  ],
  installed: ["compose"],
};
/** iPhone: "Chat" back, the title over the profile (a menu of profiles), "+", segmented tabs, the search field with its filter button, one group per category and "Check for updates". */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={phone}>
    <SkillsScreen
      profile="default"
      profiles={["work"]}
      groups={groups}
      hub={hub}
      canCheckUpdates
      onNewSkill={noop}
      onBack={noop}
    />
  </HermesProvider>
);

/** Material phone: the pill tabs and search, category groups and the refresh row. */
export const MaterialPhone = () => (
  <HermesProvider style={phone}>
    <SkillsScreen
      profile="default"
      profiles={["work"]}
      groups={groups}
      hub={hub}
      canCheckUpdates
      onNewSkill={noop}
      onBack={noop}
    />
  </HermesProvider>
);

/** Discover on iPhone with a hub job running in the background: the job strip, Featured and Official, "Installed" on a skill the profile has. */
export const DiscoverWithJob = () => (
  <HermesProvider platform="apple" style={phone}>
    <SkillsScreen
      tab="discover"
      profile="default"
      hub={hub}
      job={{ title: "Installing web-scraper" }}
      onBack={noop}
    />
  </HermesProvider>
);

/** Mac: the hub search in the toolbar, its Results group and a source that timed out. */
export const AppleMacSearch = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <SkillsScreen
      layout="desktop"
      tab="discover"
      profile="work"
      groups={groups}
      hub={{
        ...hub,
        query: "web",
        results: [hub.featured[0], hub.official[0]],
        timedOut: 1,
      }}
      onBack={noop}
    />
  </HermesProvider>
);

/** Material, no hub: a search and filter that match nothing, with the filter menu open. */
export const NoMatchesWithoutHub = () => (
  <HermesProvider style={phone}>
    <SkillsScreen
      profile="scratch"
      query="kubernetes"
      filter="agent"
      filterMenuOpen
      groups={[]}
      onNewSkill={noop}
      onBack={noop}
    />
  </HermesProvider>
);

export const Failed = () => (
  <HermesProvider style={phone}>
    <SkillsScreen state="failed" profile="default" hub={hub} onBack={noop} />
  </HermesProvider>
);

export const Loading = () => (
  <HermesProvider platform="apple" style={phone}>
    <SkillsScreen state="loading" hub={hub} onBack={noop} />
  </HermesProvider>
);

/** Mac, dark: "default · 3 skills ⌄" in the toolbar with tabs, search, filter and "+"; the groups in the 600px column and the "Hub skills" row's Check for Updates button. */
export const Dark = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    theme="dark"
    style={desktop}
  >
    <SkillsScreen
      layout="desktop"
      profile="default"
      profiles={["work"]}
      groups={groups}
      hub={hub}
      canCheckUpdates
      onNewSkill={noop}
      onBack={noop}
    />
  </HermesProvider>
);
