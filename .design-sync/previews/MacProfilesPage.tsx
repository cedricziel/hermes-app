import { HermesProvider, MacProfilesPage } from "@hermes-app/ui";

const mac = {
  width: 800,
  height: 480,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const noop = () => {};

const profiles = [
  {
    name: "default",
    model: "claude-opus-4",
    skillCount: 58,
    path: "~/.hermes",
  },
  {
    name: "work",
    displayName: "Work assistant",
    description: "Day job: tickets, reviews and the on-call rota",
    skillCount: 12,
    path: "~/.hermes/profiles/work",
  },
  {
    name: "research",
    displayName: "Research",
    description: "Reads papers, keeps notes and writes summaries",
    skillCount: 31,
    path: "~/.hermes/profiles/research",
  },
];

/** The chat's own profile selected: every section has its count, Plugins included. */
export const Selected = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <MacProfilesPage
        profiles={profiles}
        selected="work"
        host="hermes.example.com"
        counts={{
          skills: 12,
          messaging: 2,
          plugins: 3,
          mcp: 4,
          helperModels: 4,
        }}
        onSelect={noop}
        onOpen={noop}
        onNewProfile={noop}
      />
    </div>
  </HermesProvider>
);

/** Another profile than the chat's (#445): Messaging counts that profile's own platforms; `plugins` is left out of `counts`, as the dashboard's plugin hub answers only for the chat's profile, so the row shows no count. */
export const OtherProfile = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <MacProfilesPage
        profiles={profiles}
        selected="work"
        host="hermes.example.com"
        counts={{
          skills: 12,
          messaging: 1,
          mcp: 4,
          helperModels: 4,
        }}
      />
    </div>
  </HermesProvider>
);

/** Counts still loading are left out. */
export const CountsLoading = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <MacProfilesPage
        profiles={profiles}
        selected="research"
        counts={{ skills: 31 }}
      />
    </div>
  </HermesProvider>
);

export const Failed = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={{ ...mac, height: 320 }}>
      <MacProfilesPage failed onRetry={noop} />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    typeRamp="default"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={mac}>
      <MacProfilesPage
        profiles={profiles}
        selected="default"
        host="hermes.example.com"
        counts={{
          skills: 58,
          messaging: 1,
          plugins: 2,
          mcp: 0,
          helperModels: 4,
        }}
      />
    </div>
  </HermesProvider>
);
