import { HermesProvider, ProfilesScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 480 } as const;
const noop = () => {};

const profiles = [
  { name: "default", model: "claude-opus-4", skillCount: 58 },
  {
    name: "work",
    displayName: "Work assistant",
    description: "Day job",
    model: "openai/gpt-5.1",
    skillCount: 12,
  },
  {
    name: "research",
    displayName: "Research",
    description: "Reads papers, keeps notes and writes summaries",
    model: "hermes-4",
    skillCount: 31,
  },
];

export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <ProfilesScreen
        profiles={profiles}
        active="default"
        onBack={noop}
        onChangeModel={noop}
      />
    </div>
  </HermesProvider>
);

export const MaterialPhone = () => (
  <div style={phone}>
    <ProfilesScreen
      profiles={profiles}
      active="default"
      shownInChat="work"
      onBack={noop}
      onChangeModel={noop}
    />
  </div>
);

export const AppleMac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <ProfilesScreen
        layout="desktop"
        profiles={profiles}
        active="work"
        onBack={noop}
        onChangeModel={noop}
      />
    </div>
  </HermesProvider>
);

export const Loading = () => (
  <div style={phone}>
    <ProfilesScreen state="loading" onBack={noop} />
  </div>
);

export const Failed = () => (
  <div style={phone}>
    <ProfilesScreen state="failed" onBack={noop} />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    style={{ width: "fit-content", borderRadius: 14 }}
  >
    <div style={phone}>
      <ProfilesScreen
        profiles={profiles}
        active="default"
        onBack={noop}
        onChangeModel={noop}
      />
    </div>
  </HermesProvider>
);
