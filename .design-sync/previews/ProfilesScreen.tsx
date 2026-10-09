import { HermesProvider, ProfilesScreen } from "@hermes-app/ui";

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

const profiles = [
  {
    name: "default",
    path: "/home/hermes/.hermes",
    model: "hermes-4",
    skillCount: 58,
  },
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
    skillCount: 31,
  },
];

/** iPhone: "3 profiles" under the title, "+" in the bar, the active profile checked; changing a model is in the long-press sheet, so no tune buttons. */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={phone}>
    <ProfilesScreen
      profiles={profiles}
      active="default"
      onBack={noop}
      onNewProfile={noop}
      onChangeModel={noop}
    />
  </HermesProvider>
);

/** Android: "Active" and the tune buttons; the chat shows another profile than the CLI default, so the group's footer says so. */
export const MaterialPhone = () => (
  <HermesProvider platform="material" style={phone}>
    <ProfilesScreen
      profiles={profiles}
      active="default"
      shownInChat="work"
      onBack={noop}
      onNewProfile={noop}
      onChangeModel={noop}
    />
  </HermesProvider>
);

/** A pushed page in a Mac window: 52px toolbar with back and "+", 13px rows with the check and tune buttons in the centred column. */
export const AppleMac = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <ProfilesScreen
      device="mac"
      profiles={profiles}
      active="work"
      onBack={noop}
      onChangeModel={noop}
    />
  </HermesProvider>
);

/** iPhone: changing a profile's default model is in the row's long-press sheet. */
export const AppleLongPress = () => (
  <HermesProvider platform="apple" style={phone}>
    <ProfilesScreen
      profiles={profiles}
      active="default"
      onBack={noop}
      onChangeModel={noop}
      actionSheetProfile="work"
    />
  </HermesProvider>
);

/** Loading and a failed load with Retry. */
export const LoadingFailed = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={{ ...phone, height: 360 }}>
      <ProfilesScreen state="loading" onBack={noop} />
    </HermesProvider>
    <HermesProvider platform="material" style={{ ...phone, height: 360 }}>
      <ProfilesScreen state="failed" onBack={noop} />
    </HermesProvider>
  </div>
);

export const Dark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        theme="dark"
        platform={platform}
        style={phone}
      >
        <ProfilesScreen
          profiles={profiles}
          active="default"
          onBack={noop}
          onChangeModel={noop}
        />
      </HermesProvider>
    ))}
  </div>
);
